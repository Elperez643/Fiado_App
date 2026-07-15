import 'package:fiado_app/core/database/database_schema.dart';
import 'package:fiado_app/core/database/local_database.dart';
import 'package:fiado_app/data/models/sync_user_status.dart';
import 'package:fiado_app/data/repositories/sync_queue_repository.dart';
import 'package:fiado_app/data/repositories/whatsapp_campaign_repository.dart';
import 'package:flutter_test/flutter_test.dart';
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

void main() {
  late Database db;
  late SyncQueueRepository syncQueueRepository;
  late WhatsappCampaignRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute(DatabaseSchema.createUsuariosTable);
    await db.execute(DatabaseSchema.createProductosTable);
    await db.execute(DatabaseSchema.createSyncQueueTable);
    await db.execute(DatabaseSchema.createWhatsappCampaignPublicationsTable);
    final localDatabase = _MemoryLocalDatabase(db);
    syncQueueRepository = SyncQueueRepository(databaseHelper: localDatabase);
    repository = WhatsappCampaignRepository(
      databaseHelper: localDatabase,
      syncQueueRepository: syncQueueRepository,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('crear campana WhatsApp agrega sync_queue', () async {
    await repository.crearPendiente(
      negocioId: 1,
      mode: 'catalogo',
      productIds: const ['p1'],
      renderedImagePaths: const ['estado.png'],
      statusTexts: const ['Oferta'],
      quotaUnits: 1,
      now: DateTime(2026, 6, 22),
    );

    final summary = await syncQueueRepository.obtenerResumen();
    final queue = await syncQueueRepository.obtenerPendientes();

    expect(summary.pendingCount, 1);
    expect(
      queue.single.entityType,
      DatabaseSchema.whatsappCampaignPublicationsTable,
    );
  });

  test('campana pendiente impide Todo actualizado', () {
    const status = SyncUserStatus(
      isOnline: true,
      isCloudAuthenticated: true,
      isSyncing: false,
      pendingCount: 1,
      lastSyncSucceeded: true,
    );

    expect(status.shortMessage, 'Guardado en este dispositivo');
  });

  test('campana sincronizada permite Todo actualizado', () {
    const status = SyncUserStatus(
      isOnline: true,
      isCloudAuthenticated: true,
      isSyncing: false,
      pendingCount: 0,
      lastSyncSucceeded: true,
    );

    expect(status.shortMessage, 'Todo actualizado');
  });

  test(
    'producto agotado se retira de campana y genera update pendiente',
    () async {
      await db.insert(DatabaseSchema.productosTable, {
        'id': 1,
        'negocio_id': 9,
        'legacy_id': 'producto-ok',
        'nombre': 'Disponible',
        'cantidad': 5,
        'activo': 1,
      });
      await db.insert(DatabaseSchema.productosTable, {
        'id': 2,
        'negocio_id': 9,
        'legacy_id': 'producto-agotado',
        'nombre': 'Agotado',
        'cantidad': 0,
        'activo': 1,
      });
      await repository.crearPendiente(
        negocioId: 9,
        mode: 'catalogo',
        productIds: const ['producto-ok', 'producto-agotado'],
        renderedImagePaths: const ['estado.png'],
        statusTexts: const ['Oferta'],
        now: DateTime(2026, 6, 22),
      );

      await syncQueueRepository.marcarComoProcesado(
        (await syncQueueRepository.obtenerPendientes()).single.id!,
      );
      final changed = await repository.retirarProductosNoDisponibles(
        negocioId: 9,
      );
      final history = await repository.obtenerHistorial(negocioId: 9);
      final summary = await syncQueueRepository.obtenerResumen();

      expect(changed, 1);
      expect(history.single.productIds, const ['producto-ok']);
      expect(summary.pendingCount, 1);
    },
  );

  test('multi-negocio no mezcla campanas', () async {
    await repository.crearPendiente(
      negocioId: 1,
      mode: 'catalogo',
      productIds: const ['a'],
      renderedImagePaths: const ['a.png'],
      statusTexts: const ['A'],
      now: DateTime(2026, 6, 22),
    );
    await repository.crearPendiente(
      negocioId: 2,
      mode: 'catalogo',
      productIds: const ['b'],
      renderedImagePaths: const ['b.png'],
      statusTexts: const ['B'],
      now: DateTime(2026, 6, 22),
    );

    final businessOne = await repository.obtenerHistorial(negocioId: 1);
    final businessTwo = await repository.obtenerHistorial(negocioId: 2);

    expect(businessOne, hasLength(1));
    expect(businessOne.single.negocioId, 1);
    expect(businessTwo, hasLength(1));
    expect(businessTwo.single.negocioId, 2);
  });
}
