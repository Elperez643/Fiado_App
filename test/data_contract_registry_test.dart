import 'package:fiado_app/core/database/database_schema.dart';
import 'package:fiado_app/core/database/database_helper.dart';
import 'package:fiado_app/core/database/local_database.dart';
import 'package:fiado_app/data/contracts/data_contract_registry.dart';
import 'package:fiado_app/data/contracts/data_contract_validator.dart';
import 'package:fiado_app/data/models/sync_outbox_item.dart';
import 'package:fiado_app/data/repositories/sync_outbox_repository.dart';
import 'package:fiado_app/data/repositories/sync_queue_repository.dart';
import 'package:fiado_app/data/services/sync_endpoint_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _TestDatabase implements LocalDatabase {
  final Database db;

  const _TestDatabase(this.db);

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
  late Database db;
  late _TestDatabase database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    for (final statement in DatabaseSchema.createTableStatements) {
      await db.execute(statement);
    }
    database = _TestDatabase(db);
  });

  tearDown(() async => db.close());

  test('todas las tablas SQLite tienen contrato y existen', () async {
    DataContractRegistry.validateDefinitions();
    await DataContractValidator.validateDatabase(db);

    expect(
      DataContractRegistry.contracts.map((contract) => contract.table).toSet(),
      DatabaseSchema.allTables,
    );
  });

  test('todo handler legacy tiene endpoint push pull y entidades', () {
    for (final definition in LegacySyncEndpointRegistry.definitions.values) {
      expect(definition.entityTypes, isNotEmpty);
      expect(definition.pushPath, endsWith('/push'));
      expect(definition.pullPath, endsWith('/pull'));
      for (final entityType in definition.entityTypes) {
        expect(
          LegacySyncEndpointRegistry.forEntityType(entityType),
          same(definition),
        );
      }
    }
  });

  test('sync_queue rechaza entidad desconocida antes de guardar', () async {
    final repository = SyncQueueRepository(databaseHelper: database);

    expect(
      () => repository.enqueueCreate(
        entityType: 'payment_receipts_unknown',
        entityId: 1,
        payload: const {'id': 1},
      ),
      throwsA(isA<StateError>()),
    );
    expect(await db.query(DatabaseSchema.syncQueueTable), isEmpty);
  });

  test('startup detecta modulo desconocido sin borrar payload', () async {
    await db.insert(DatabaseSchema.syncOutboxTable, {
      'uuid': 'unknown-event',
      'business_id': '7',
      'module': 'campaign_images',
      'entity_type': 'campaign_image',
      'entity_uuid': 'campaign-image-1',
      'operation': 'create',
      'payload_json': '{"uuid":"campaign-image-1"}',
      'status': SyncOutboxItem.statusPending,
      'attempt_count': 0,
      'created_at': '2026-07-01T00:00:00.000Z',
      'updated_at': '2026-07-01T00:00:00.000Z',
    });

    expect(
      () => DataContractValidator.validateDatabase(db),
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          contains('campaign_images'),
        ),
      ),
    );
    expect(await db.query(DatabaseSchema.syncOutboxTable), hasLength(1));
  });

  test('outbox rechaza campos no soportados por contrato principal', () async {
    final repository = SyncOutboxRepository(databaseHelper: database);
    final item = SyncOutboxItem.pending(
      businessId: '7',
      module: 'clients',
      entityType: 'client',
      entityUuid: 'client-contract',
      operation: 'create',
      payload: const {
        'uuid': 'client-contract',
        'nombre': 'Cliente',
        'campoInventado': true,
      },
    );

    expect(() => repository.enqueue(item), throwsArgumentError);
    expect(await db.query(DatabaseSchema.syncOutboxTable), isEmpty);
  });

  test('entidades sin nube estan justificadas explicitamente', () {
    final intentional = DataContractRegistry.contracts.where(
      (contract) =>
          contract.disposition == DataContractDisposition.localOnly ||
          contract.disposition == DataContractDisposition.serverManagedCache ||
          contract.disposition == DataContractDisposition.legacyInactive,
    );

    expect(intentional, isNotEmpty);
    for (final contract in intentional) {
      expect(contract.justification.trim(), isNotEmpty);
      expect(contract.outboxModule, isNull);
      expect(contract.legacyHandler, isNull);
    }
  });

  test('downgrade SQLite falla sin borrar datos', () async {
    await db.insert(DatabaseSchema.pagosTable, {
      'cliente_nombre': 'Dato protegido',
      'monto': 10.0,
      'fecha': '2026-07-01T00:00:00.000Z',
      'created_at': '2026-07-01T00:00:00.000Z',
    });

    await expectLater(
      DatabaseHelper.rejectDestructiveDowngrade(db, 29, 28),
      throwsA(isA<StateError>()),
    );
    expect(await db.query(DatabaseSchema.pagosTable), hasLength(1));
  });
}
