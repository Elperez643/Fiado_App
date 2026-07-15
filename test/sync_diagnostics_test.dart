import 'package:fiado_app/core/config/developer_tools.dart';
import 'package:fiado_app/core/database/database_schema.dart';
import 'package:fiado_app/core/database/local_database.dart';
import 'package:fiado_app/data/models/sync_user_status.dart';
import 'package:fiado_app/data/repositories/sync_diagnostics_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _MemoryDatabase implements LocalDatabase {
  final Database db;

  const _MemoryDatabase(this.db);

  @override
  Future<Database> get database async => db;

  @override
  Future<void> close() => db.close();

  @override
  Future<void> initialize() async {}

  @override
  Future<T> transaction<T>(Future<T> Function() action) => action();
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('diagnostico incluye summaries y solo payload keys', () async {
    SharedPreferences.setMockInitialValues({
      'fiado_api_base_url': 'http://fiado.test',
      'fiado_cloud_user_id': 'user-1',
      'fiado_cloud_business_id': 'business-1',
      'fiado_cloud_role': 'negocio',
      'fiado_sync_device_id': 'device-secret-value',
      'fiado_cloud_session_version': 3,
    });
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await db.execute(DatabaseSchema.createSyncOutboxTable);
    await db.execute(DatabaseSchema.createSyncQueueTable);
    await db.execute(DatabaseSchema.createSyncStateTable);
    await db.execute(DatabaseSchema.createSesionesTable);
    await db.insert(DatabaseSchema.syncOutboxTable, {
      'uuid': 'outbox-1',
      'business_id': 'business-1',
      'module': 'inventory',
      'entity_type': 'product',
      'entity_uuid': 'product-1',
      'operation': 'update',
      'payload_json':
          '{"name":"SECRET_PRODUCT","contentBase64":"BASE64_SECRET"}',
      'status': 'pending',
      'attempt_count': 2,
      'last_error': null,
      'created_at': '2026-07-01T10:00:00.000Z',
      'updated_at': '2026-07-01T10:01:00.000Z',
    });
    await db.insert(DatabaseSchema.syncQueueTable, {
      'entity_type': 'movimientos',
      'entity_id': 7,
      'operation': 'create',
      'payload': '{"amount":900,"password":"PASSWORD_SECRET"}',
      'status': 'failed',
      'attempts': 4,
      'last_error': 'Bearer VERY_SECRET_TOKEN backend rejected',
      'created_at': '2026-07-01T10:00:00.000Z',
      'updated_at': '2026-07-01T10:02:00.000Z',
    });
    final repository = SyncDiagnosticsRepository(
      databaseHelper: _MemoryDatabase(db),
      sharedPreferences: SharedPreferences.getInstance(),
      tokenPresentResolver: () async => true,
    );

    final report = await repository.load(
      bannerStatus: const SyncUserStatus(
        isOnline: true,
        isCloudAuthenticated: true,
        isSyncing: false,
        pendingCount: 2,
        lastSyncSucceeded: false,
        lastErrorMessage: 'No se pudo actualizar',
      ),
    );
    final copied = report.toPlainText();

    expect(report.outbox.total, 1);
    expect(report.outbox.pending, 1);
    expect(report.legacyQueue.total, 1);
    expect(report.legacyQueue.failed, 1);
    expect(copied, contains('[sync_outbox]'));
    expect(copied, contains('[sync_queue legacyEnabled=false]'));
    expect(copied, contains('payloadKeys=contentBase64,name'));
    expect(copied, contains('payloadKeys=amount,password'));
    expect(copied, contains('tokenPresent=true'));
    expect(copied, isNot(contains('SECRET_PRODUCT')));
    expect(copied, isNot(contains('BASE64_SECRET')));
    expect(copied, isNot(contains('PASSWORD_SECRET')));
    expect(copied, isNot(contains('VERY_SECRET_TOKEN')));
    expect(copied, isNot(contains('device-secret-value')));
  });

  test('pantalla diagnostica requiere debug o developer tools', () {
    expect(
      isSyncDiagnosticsEnabled(debugMode: false, developerTools: false),
      isFalse,
    );
    expect(
      isSyncDiagnosticsEnabled(debugMode: true, developerTools: false),
      isTrue,
    );
    expect(
      isSyncDiagnosticsEnabled(debugMode: false, developerTools: true),
      isTrue,
    );
  });
}
