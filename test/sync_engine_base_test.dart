import 'package:fiado_app/core/database/database_schema.dart';
import 'package:fiado_app/core/database/local_database.dart';
import 'package:fiado_app/core/sync/sync_feature_flags.dart';
import 'package:fiado_app/data/models/new_sync_status.dart';
import 'package:fiado_app/data/models/sync_outbox_item.dart';
import 'package:fiado_app/data/models/sync_user_status.dart';
import 'package:fiado_app/data/repositories/auth_repository.dart';
import 'package:fiado_app/data/repositories/sync_outbox_repository.dart';
import 'package:fiado_app/data/repositories/sync_queue_repository.dart';
import 'package:fiado_app/data/repositories/sync_state_repository.dart';
import 'package:fiado_app/data/services/api_client.dart';
import 'package:fiado_app/data/services/sync_device_identity_service.dart';
import 'package:fiado_app/data/services/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

class _NoopApiClient extends ApiClient {
  _NoopApiClient({
    required super.authRepository,
    required super.sharedPreferences,
  }) : super(httpClient: http.Client());

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, Object?>? body,
  }) async {
    if (path.endsWith('/push')) {
      return {
        'module': path.split('/')[2],
        'accepted': (body?['changes'] as List<dynamic>? ?? const []).length,
        'rejected': 0,
        'serverTime': '2026-06-22T10:00:00.000Z',
        'errors': <String>[],
      };
    }
    return {
      'module': path.split('/')[2],
      'changes': <Map<String, Object?>>[],
      'serverTime': '2026-06-22T10:00:00.000Z',
      'hasMore': false,
    };
  }
}

void main() {
  late Database db;
  late _MemoryLocalDatabase localDatabase;
  late SyncOutboxRepository outboxRepository;
  late SyncStateRepository stateRepository;
  late SyncEngine syncEngine;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute(DatabaseSchema.createUsuariosTable);
    await db.execute(DatabaseSchema.createSesionesTable);
    await db.execute(DatabaseSchema.createSyncQueueTable);
    await db.execute(DatabaseSchema.createSyncOutboxTable);
    await db.execute(DatabaseSchema.createSyncStateTable);
    for (final index in DatabaseSchema.initialIndexes) {
      if (index.contains('idx_sync_outbox_') ||
          index.contains('idx_sync_state_')) {
        await db.execute(index);
      }
    }
    localDatabase = _MemoryLocalDatabase(db);
    outboxRepository = SyncOutboxRepository(databaseHelper: localDatabase);
    stateRepository = SyncStateRepository(databaseHelper: localDatabase);
    final authRepository = AuthRepository(
      databaseHelper: localDatabase,
      syncQueueRepository: SyncQueueRepository(databaseHelper: localDatabase),
    );
    syncEngine = SyncEngine(
      outboxRepository: outboxRepository,
      stateRepository: stateRepository,
      deviceIdentityService: SyncDeviceIdentityService(
        sharedPreferences: SharedPreferences.getInstance(),
      ),
      apiClient: _NoopApiClient(
        authRepository: authRepository,
        sharedPreferences: SharedPreferences.getInstance(),
      ),
      authRepository: authRepository,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('DeviceId se crea una vez y se reutiliza', () async {
    final service = SyncDeviceIdentityService(
      sharedPreferences: SharedPreferences.getInstance(),
    );

    final first = await service.getOrCreateDeviceId();
    final second = await service.getOrCreateDeviceId();

    expect(first, startsWith('device-'));
    expect(second, first);
  });

  test('sync_outbox inserta evento pending correctamente', () async {
    await outboxRepository.enqueue(
      SyncOutboxItem.pending(
        businessId: 'business-1',
        module: 'clients',
        entityType: 'client',
        entityUuid: 'client-uuid',
        operation: 'create',
        payload: const {'name': 'Cliente'},
      ),
    );

    final pending = await outboxRepository.pending();

    expect(pending, hasLength(1));
    expect(pending.single.status, SyncOutboxItem.statusPending);
    expect(pending.single.businessId, 'business-1');
    expect(pending.single.entityUuid, 'client-uuid');
  });

  test('sync_state actualiza pending_count', () async {
    await stateRepository.upsert(
      businessId: 'business-1',
      module: 'clients',
      pendingCount: 0,
    );
    await stateRepository.updatePendingCount(
      businessId: 'business-1',
      module: 'clients',
      pendingCount: 3,
    );

    final state = await stateRepository.getState(
      businessId: 'business-1',
      module: 'clients',
    );

    expect(state!.pendingCount, 3);
  });

  test('SyncStatusProvider no muestra Todo actualizado con pending', () async {
    await outboxRepository.enqueue(
      SyncOutboxItem.pending(
        businessId: 'business-1',
        module: 'clients',
        entityType: 'client',
        entityUuid: 'client-uuid',
        operation: 'create',
        payload: const {'name': 'Cliente'},
      ),
    );

    final status = await syncEngine.recomputeStatus();

    expect(status.state, NewSyncUiState.savedOnThisDevice);
    expect(status.canShowAllUpdated, isFalse);
  });

  test('error historico sin pendientes no bloquea Todo actualizado', () async {
    await stateRepository.upsert(
      businessId: 'business-1',
      module: 'clients',
      lastSuccessAt: DateTime.utc(2026, 6, 22),
      lastError: 'pull failed',
      pendingCount: 0,
    );

    final status = await syncEngine.recomputeStatus();

    expect(status.state, NewSyncUiState.allUpdated);
    expect(status.canShowAllUpdated, isTrue);
  });

  test('fallo activo con pendientes muestra No se pudo actualizar', () async {
    await stateRepository.upsert(
      businessId: 'business-1',
      module: 'clients',
      lastError: 'pull failed',
      pendingCount: 1,
    );

    final status = await syncEngine.recomputeStatus();

    expect(status.state, NewSyncUiState.error);
    expect(status.lastError, 'pull failed');
  });

  test('fallo legacy inactivo bloquea UI sin borrar su payload', () async {
    await db.insert(DatabaseSchema.syncQueueTable, {
      'entity_type': 'inventory_images',
      'entity_id': 42,
      'operation': 'update',
      'payload': '{"preserved":true}',
      'status': 'failed',
      'attempts': 5,
      'last_error': 'legacy failure',
      'created_at': '2026-06-22T10:00:00.000Z',
      'updated_at': '2026-06-22T10:00:00.000Z',
    });
    await stateRepository.upsert(
      businessId: 'business-1',
      module: 'clients',
      lastSuccessAt: DateTime.utc(2026, 6, 22),
      pendingCount: 0,
    );

    final engineStatus = await syncEngine.recomputeUserStatus(
      isOnline: true,
      isCloudAuthenticated: true,
    );
    final status = applyLegacyQueueVisibility(
      engineStatus,
      legacyPendingCount: 0,
      legacyFailedCount: 1,
    );
    final rows = await db.query(DatabaseSchema.syncQueueTable);

    expect(SyncFeatureFlags.enableLegacySync, isFalse);
    expect(status.shortMessage, 'No se pudo actualizar');
    expect(rows, hasLength(1));
    expect(rows.single['payload'], '{"preserved":true}');
  });

  test(
    'legacy sync no corre automaticamente cuando enableLegacySync=false',
    () {
      expect(SyncFeatureFlags.useNewSyncEngine, isTrue);
      expect(SyncFeatureFlags.enableLegacySync, isFalse);
    },
  );
}
