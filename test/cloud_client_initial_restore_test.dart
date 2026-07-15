import 'dart:convert';

import 'package:fiado_app/core/api/api_environment.dart';
import 'package:fiado_app/core/database/database_schema.dart';
import 'package:fiado_app/core/database/local_database.dart';
import 'package:fiado_app/core/security/secure_token_storage.dart';
import 'package:fiado_app/data/repositories/auth_repository.dart';
import 'package:fiado_app/data/repositories/subscription_repository.dart';
import 'package:fiado_app/data/repositories/sync_queue_repository.dart';
import 'package:fiado_app/data/services/api_client.dart';
import 'package:fiado_app/data/services/cloud_client_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

late Database db;
late LocalDatabase localDatabase;
late AuthRepository authRepository;

class _MemoryLocalDatabase implements LocalDatabase {
  final Database db;

  const _MemoryLocalDatabase(this.db);

  @override
  Future<Database> get database async => db;

  @override
  Future<void> close() => db.close();

  @override
  Future<void> initialize() async {}

  @override
  Future<T> transaction<T>(Future<T> Function() action) => action();
}

class _FakeSecureTokenStorage extends SecureTokenStorage {
  const _FakeSecureTokenStorage();

  @override
  Future<String?> readCloudToken() async => null;

  @override
  Future<DateTime?> readCloudTokenExpiresAt() async => null;

  @override
  Future<String?> readManualBackendToken({
    required Future<SharedPreferences> sharedPreferences,
  }) async => null;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      ApiEnvironmentConfig.manualBaseUrlKey: 'http://fiado.test/api',
    });
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute(DatabaseSchema.createUsuariosTable);
    await db.execute(DatabaseSchema.createSesionesTable);
    await db.execute(DatabaseSchema.createSubscriptionsTable);
    await db.execute(DatabaseSchema.createClientesTable);
    localDatabase = _MemoryLocalDatabase(db);
    authRepository = AuthRepository(
      databaseHelper: localDatabase,
      subscriptionRepository: SubscriptionRepository(
        databaseHelper: localDatabase,
      ),
      syncQueueRepository: SyncQueueRepository(databaseHelper: localDatabase),
    );
    await authRepository.registrarUsuarioNegocio(
      'Negocio Cloud',
      'Admin',
      '8097770000',
      'secret',
    );
    await authRepository.login('8097770000', 'secret');
    await authRepository.guardarJwtTokenActual('session-jwt');
  });

  tearDown(() async {
    await db.close();
  });

  test('initial client pull stores backend clients locally', () async {
    final service = _clientSyncService((request) async {
      expect(request.url.path, '/api/clients/sync/pull');
      expect(request.headers['authorization'], 'Bearer session-jwt');
      return http.Response(
        jsonEncode({
          'serverTime': '2026-06-22T13:00:00Z',
          'clients': [
            {
              'id': 'remote-client-1',
              'name': 'Cliente Cloud',
              'phone': '8095550001',
              'address': 'Calle 1',
              'debt': 125.50,
              'isActive': true,
              'createdAt': '2026-06-20T10:00:00Z',
              'updatedAt': '2026-06-22T12:00:00Z',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final result = await service.pullClients();
    final clients = await db.query(DatabaseSchema.clientesTable);

    expect(result.received, 1);
    expect(clients, hasLength(1));
    expect(clients.single['remote_id'], 'remote-client-1');
    expect(clients.single['nombre'], 'Cliente Cloud');
    expect(clients.single['telefono'], '8095550001');
    expect(clients.single['sync_status'], 'synced');
  });

  test('initial client pull is idempotent and does not duplicate', () async {
    var call = 0;
    final service = _clientSyncService((request) async {
      call++;
      return http.Response(
        jsonEncode({
          'serverTime': '2026-06-22T13:0$call:00Z',
          'clients': [
            {
              'id': 'remote-client-1',
              'name': call == 1 ? 'Cliente Cloud' : 'Cliente Cloud Editado',
              'phone': '8095550001',
              'debt': call == 1 ? 125.50 : 200,
              'isActive': true,
              'createdAt': '2026-06-20T10:00:00Z',
              'updatedAt': '2026-06-22T12:0$call:00Z',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await service.pullClients();
    await service.pullClients();
    final clients = await db.query(DatabaseSchema.clientesTable);

    expect(clients, hasLength(1));
    expect(clients.single['nombre'], 'Cliente Cloud Editado');
    expect(clients.single['deuda'], 200.0);
  });
}

CloudClientSyncService _clientSyncService(
  Future<http.Response> Function(http.Request request) handler,
) {
  final httpClient = MockClient((request) => handler(request));
  final sharedPreferences = SharedPreferences.getInstance();
  final apiClient = ApiClient(
    httpClient: httpClient,
    authRepository: authRepository,
    sharedPreferences: sharedPreferences,
    secureTokenStorage: const _FakeSecureTokenStorage(),
  );
  return CloudClientSyncService(
    apiClient: apiClient,
    authRepository: authRepository,
    syncQueueRepository: SyncQueueRepository(databaseHelper: localDatabase),
    databaseHelper: localDatabase,
    sharedPreferences: sharedPreferences,
  );
}
