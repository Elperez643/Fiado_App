import 'dart:convert';

import 'package:fiado_app/core/api/api_environment.dart';
import 'package:fiado_app/core/database/database_schema.dart';
import 'package:fiado_app/core/database/local_database.dart';
import 'package:fiado_app/core/security/secure_token_storage.dart';
import 'package:fiado_app/core/sync/sync_status.dart';
import 'package:fiado_app/data/repositories/auth_repository.dart';
import 'package:fiado_app/data/repositories/subscription_repository.dart';
import 'package:fiado_app/data/repositories/sync_queue_repository.dart';
import 'package:fiado_app/data/services/api_client.dart';
import 'package:fiado_app/data/services/cloud_credit_cycle_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

late Database db;
late LocalDatabase localDatabase;
late AuthRepository authRepository;
late SyncQueueRepository syncQueueRepository;

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
    await db.execute(DatabaseSchema.createSyncQueueTable);
    await db.execute(DatabaseSchema.createMovimientosTable);
    await db.execute(DatabaseSchema.createCreditoCiclosTable);
    await db.execute(DatabaseSchema.createCreditoRecordatoriosTable);
    await db.execute(DatabaseSchema.createCreditoExcepcionesTable);
    localDatabase = _MemoryLocalDatabase(db);
    syncQueueRepository = SyncQueueRepository(databaseHelper: localDatabase);
    authRepository = AuthRepository(
      databaseHelper: localDatabase,
      subscriptionRepository: SubscriptionRepository(
        databaseHelper: localDatabase,
      ),
      syncQueueRepository: syncQueueRepository,
    );
    final user = await authRepository.registrarUsuarioNegocio(
      'Negocio QA',
      'Admin',
      '8097000000',
      'secret',
    );
    await authRepository.login('8097000000', 'secret');
    await authRepository.guardarJwtTokenActual('session-jwt');
    await db.insert(DatabaseSchema.clientesTable, {
      'id': 10,
      'negocio_id': user.id,
      'uuid': 'client-credit-cycle-10',
      'remote_id': 'remote-client-10',
      'nombre': 'Cliente Ciclo',
      'telefono': '8097000010',
      'deuda': 100,
      'is_active': 1,
      'created_at': '2026-06-20T10:00:00Z',
      'updated_at': '2026-06-20T10:00:00Z',
      'sync_status': SyncStatus.synced,
    });
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'credit cycle update without remote id resolves as backend upsert',
    () async {
      await _insertPendingCycle();
      final service = _creditCycleService((request) async {
        expect(request.url.path, '/api/credit-cycles/sync/push');
        final decoded = jsonDecode(request.body) as Map<String, dynamic>;
        final item = (decoded['creditCycles'] as List).single;
        expect(item['operation'], 'update');
        expect(item['serverId'], isNull);
        expect((item['payload'] as Map)['clientId'], 'remote-client-10');
        return http.Response(
          jsonEncode({
            'serverTime': '2026-06-22T13:00:00Z',
            'results': [
              {
                'localId': 20,
                'serverId': '11111111-1111-1111-1111-111111111111',
                'status': 'updated',
                'serverUpdatedAt': '2026-06-22T13:00:00Z',
              },
            ],
          }),
          200,
        );
      });

      final result = await service.pushPendingCreditCycles();
      final cycle = (await db.query(DatabaseSchema.creditoCiclosTable)).single;
      final summary = await syncQueueRepository.obtenerResumen();

      expect(result.errors, 0);
      expect(result.sent, 1);
      expect(cycle['remote_id'], '11111111-1111-1111-1111-111111111111');
      expect(cycle['sync_status'], SyncStatus.synced);
      expect(summary.pendingCount + summary.failedCount, 0);
    },
  );

  test('real credit cycle backend error remains failed', () async {
    await _insertPendingCycle();
    final service = _creditCycleService((request) async {
      return http.Response(
        jsonEncode({
          'serverTime': '2026-06-22T13:00:00Z',
          'results': [
            {
              'localId': 20,
              'serverId': null,
              'status': 'failed',
              'error': 'Cliente no encontrado para este negocio.',
            },
          ],
        }),
        200,
      );
    });

    final result = await service.pushPendingCreditCycles();
    final queue = (await db.query(DatabaseSchema.syncQueueTable)).single;
    final summary = await syncQueueRepository.obtenerResumen();

    expect(result.errors, 1);
    expect(queue['status'], SyncStatus.failed);
    expect(queue['last_error'], 'Cliente no encontrado para este negocio.');
    expect(summary.failedCount, 1);
  });

  test('credit reminder pending resolves after batch push success', () async {
    await _insertSyncedCycle();
    await _insertPendingReminder();
    final service = _creditCycleService((request) async {
      final decoded = jsonDecode(request.body) as Map<String, dynamic>;
      expect(decoded['creditCycles'], isEmpty);
      final item = (decoded['creditReminders'] as List).single;
      expect((item['payload'] as Map)['creditCycleId'], 'remote-cycle-20');
      expect((item['payload'] as Map)['clientId'], 'remote-client-10');
      return http.Response(
        jsonEncode({
          'serverTime': '2026-06-22T13:00:00Z',
          'results': [],
          'creditReminderResults': [
            {
              'localId': 30,
              'serverId': '22222222-2222-2222-2222-222222222222',
              'status': 'created',
              'serverUpdatedAt': '2026-06-22T13:00:00Z',
            },
          ],
          'creditExceptionResults': [],
        }),
        200,
      );
    });

    final result = await service.pushPendingCreditCycles();
    final reminder = (await db.query(
      DatabaseSchema.creditoRecordatoriosTable,
    )).single;
    final summary = await syncQueueRepository.obtenerResumen();

    expect(result.errors, 0);
    expect(result.sent, 1);
    expect(reminder['remote_id'], '22222222-2222-2222-2222-222222222222');
    expect(reminder['sync_status'], SyncStatus.synced);
    expect(summary.pendingCount + summary.failedCount, 0);
  });

  test('credit exception pending resolves after batch push success', () async {
    await _insertSyncedCycle();
    await _insertPendingException();
    final service = _creditCycleService((request) async {
      final decoded = jsonDecode(request.body) as Map<String, dynamic>;
      expect(decoded['creditCycles'], isEmpty);
      final item = (decoded['creditExceptions'] as List).single;
      expect((item['payload'] as Map)['creditCycleId'], 'remote-cycle-20');
      expect((item['payload'] as Map)['clientId'], 'remote-client-10');
      return http.Response(
        jsonEncode({
          'serverTime': '2026-06-22T13:00:00Z',
          'results': [],
          'creditReminderResults': [],
          'creditExceptionResults': [
            {
              'localId': 40,
              'serverId': '33333333-3333-3333-3333-333333333333',
              'status': 'created',
              'serverUpdatedAt': '2026-06-22T13:00:00Z',
            },
          ],
        }),
        200,
      );
    });

    final result = await service.pushPendingCreditCycles();
    final exception = (await db.query(
      DatabaseSchema.creditoExcepcionesTable,
    )).single;
    final summary = await syncQueueRepository.obtenerResumen();

    expect(result.errors, 0);
    expect(result.sent, 1);
    expect(exception['remote_id'], '33333333-3333-3333-3333-333333333333');
    expect(exception['sync_status'], SyncStatus.synced);
    expect(summary.pendingCount + summary.failedCount, 0);
  });

  test('pull credit reminders and exceptions is idempotent', () async {
    await _insertSyncedCycle();
    var calls = 0;
    final service = _creditCycleService((request) async {
      calls++;
      expect(request.url.path, '/api/credit-cycles/sync/pull');
      return http.Response(
        jsonEncode({
          'serverTime': '2026-06-22T13:00:00Z',
          'creditCycles': [],
          'creditReminders': [
            {
              'id': '22222222-2222-2222-2222-222222222222',
              'localId': 30,
              'creditCycleId': 'remote-cycle-20',
              'clientId': 'remote-client-10',
              'type': 'aviso_30',
              'message': 'Recordatorio',
              'channel': 'interno',
              'status': 'pendiente',
              'generatedAt': '2026-06-22T10:00:00Z',
              'sentAt': null,
              'createdAt': '2026-06-22T10:00:00Z',
              'updatedAt': '2026-06-22T10:00:00Z',
            },
          ],
          'creditExceptions': [
            {
              'id': '33333333-3333-3333-3333-333333333333',
              'localId': 40,
              'remoteId': null,
              'creditCycleId': 'remote-cycle-20',
              'clientId': 'remote-client-10',
              'userId': null,
              'reason': 'Autorizado',
              'amount': 25,
              'movementId': null,
              'date': '2026-06-22T10:00:00Z',
              'createdAt': '2026-06-22T10:00:00Z',
              'updatedAt': '2026-06-22T10:00:00Z',
            },
          ],
        }),
        200,
      );
    });

    await service.pullCreditCycles();
    await service.pullCreditCycles();

    expect(calls, 2);
    expect(
      await db.query(DatabaseSchema.creditoRecordatoriosTable),
      hasLength(1),
    );
    expect(
      await db.query(DatabaseSchema.creditoExcepcionesTable),
      hasLength(1),
    );
  });
}

Future<void> _insertPendingCycle() async {
  await db.insert(DatabaseSchema.creditoCiclosTable, {
    'id': 20,
    'negocio_id': 1,
    'cliente_id': 10,
    'fecha_inicio': '2026-06-20T10:00:00Z',
    'fecha_limite_30': '2026-07-20T10:00:00Z',
    'fecha_limite_45': '2026-08-04T10:00:00Z',
    'fecha_bloqueo_60': '2026-08-19T10:00:00Z',
    'estado': 'activo',
    'monto_total': 100,
    'monto_pagado': 0,
    'saldo_pendiente': 100,
    'bloqueado': 0,
    'created_at': '2026-06-20T10:00:00Z',
    'updated_at': '2026-06-22T10:00:00Z',
    'sync_status': SyncStatus.updated,
  });
  await syncQueueRepository.enqueueUpdate(
    entityType: DatabaseSchema.creditoCiclosTable,
    entityId: 20,
    payload: (await db.query(DatabaseSchema.creditoCiclosTable)).single,
  );
}

Future<void> _insertSyncedCycle() async {
  await db.insert(DatabaseSchema.creditoCiclosTable, {
    'id': 20,
    'remote_id': 'remote-cycle-20',
    'negocio_id': 1,
    'cliente_id': 10,
    'fecha_inicio': '2026-06-20T10:00:00Z',
    'fecha_limite_30': '2026-07-20T10:00:00Z',
    'fecha_limite_45': '2026-08-04T10:00:00Z',
    'fecha_bloqueo_60': '2026-08-19T10:00:00Z',
    'estado': 'activo',
    'monto_total': 100,
    'monto_pagado': 0,
    'saldo_pendiente': 100,
    'bloqueado': 0,
    'created_at': '2026-06-20T10:00:00Z',
    'updated_at': '2026-06-22T10:00:00Z',
    'sync_status': SyncStatus.synced,
  });
}

Future<void> _insertPendingReminder() async {
  await db.insert(DatabaseSchema.creditoRecordatoriosTable, {
    'id': 30,
    'ciclo_id': 20,
    'negocio_id': 1,
    'cliente_id': 10,
    'tipo': 'aviso_30',
    'mensaje': 'Recordatorio',
    'canal': 'interno',
    'estado': 'pendiente',
    'fecha_generado': '2026-06-22T10:00:00Z',
    'created_at': '2026-06-22T10:00:00Z',
    'updated_at': '2026-06-22T10:00:00Z',
    'sync_status': SyncStatus.pending,
  });
  await syncQueueRepository.enqueueCreate(
    entityType: DatabaseSchema.creditoRecordatoriosTable,
    entityId: 30,
    payload: (await db.query(DatabaseSchema.creditoRecordatoriosTable)).single,
  );
}

Future<void> _insertPendingException() async {
  await db.insert(DatabaseSchema.creditoExcepcionesTable, {
    'id': 40,
    'ciclo_id': 20,
    'negocio_id': 1,
    'cliente_id': 10,
    'usuario_id': 1,
    'motivo': 'Autorizado',
    'monto_fiado': 25,
    'fecha': '2026-06-22T10:00:00Z',
    'created_at': '2026-06-22T10:00:00Z',
    'updated_at': '2026-06-22T10:00:00Z',
    'sync_status': SyncStatus.pending,
  });
  await syncQueueRepository.enqueueCreate(
    entityType: DatabaseSchema.creditoExcepcionesTable,
    entityId: 40,
    payload: (await db.query(DatabaseSchema.creditoExcepcionesTable)).single,
  );
}

CloudCreditCycleSyncService _creditCycleService(
  Future<http.Response> Function(http.Request request) handler,
) {
  final sharedPreferences = SharedPreferences.getInstance();
  final apiClient = ApiClient(
    httpClient: MockClient((request) => handler(request)),
    authRepository: authRepository,
    sharedPreferences: sharedPreferences,
    secureTokenStorage: const _FakeSecureTokenStorage(),
  );
  return CloudCreditCycleSyncService(
    apiClient: apiClient,
    authRepository: authRepository,
    syncQueueRepository: syncQueueRepository,
    databaseHelper: localDatabase,
    sharedPreferences: sharedPreferences,
  );
}
