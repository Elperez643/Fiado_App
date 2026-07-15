import 'dart:convert';
import 'dart:io';

import 'package:fiado_app/core/database/database_schema.dart';
import 'package:fiado_app/core/database/local_database.dart';
import 'package:fiado_app/core/sync/sync_status.dart';
import 'package:fiado_app/data/models/new_sync_status.dart';
import 'package:fiado_app/data/models/sync_outbox_item.dart';
import 'package:fiado_app/data/repositories/auth_repository.dart';
import 'package:fiado_app/data/repositories/inventory_product_metrics_repository.dart';
import 'package:fiado_app/data/repositories/producto_repository.dart';
import 'package:fiado_app/data/repositories/sync_outbox_repository.dart';
import 'package:fiado_app/data/repositories/sync_queue_repository.dart';
import 'package:fiado_app/data/repositories/sync_state_repository.dart';
import 'package:fiado_app/data/services/api_client.dart';
import 'package:fiado_app/data/services/inventory_backfill_service.dart';
import 'package:fiado_app/data/services/inventory_image_sync_diagnostics.dart';
import 'package:fiado_app/data/services/inventory_media_sync_service.dart';
import 'package:fiado_app/data/services/inventory_sync_adapter.dart';
import 'package:fiado_app/data/services/sync_device_identity_service.dart';
import 'package:fiado_app/data/services/sync_engine.dart';
import 'package:fiado_app/models/producto.dart';
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

class _NoopInventoryMetricsRepository
    extends InventoryProductMetricsRepository {
  @override
  Future<void> markProductDirty({
    required int negocioId,
    required int productoId,
  }) async {}
}

class _InventoryApiClient extends ApiClient {
  final List<Map<String, Object?>> remoteChanges;
  final List<Map<String, Object?>> remoteImages;
  final Map<String, Map<String, Object?>> remoteImageContent;
  final List<Map<String, Object?>> pushed = [];
  final List<Map<String, Object?>> pushedImageMetadata = [];
  final List<Map<String, Object?>> pushedImageContent = [];
  final List<String> requestedPaths = [];

  _InventoryApiClient({
    required super.authRepository,
    required super.sharedPreferences,
    this.remoteChanges = const [],
    this.remoteImages = const [],
    this.remoteImageContent = const {},
  }) : super(httpClient: http.Client());

  @override
  Future<bool> hasUsableToken() async => true;

  @override
  Future<Uri> requestUri(String path) async {
    return Uri.parse('http://fiado.test$path');
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, Object?>? body,
  }) async {
    requestedPaths.add(path);
    if (path == '/api/sync/inventory_images/push' ||
        path == '/api/sync/inventory_images/pull') {
      throw const ApiException('Legacy inventory_images endpoint returned 400');
    }
    if (path == '/api/sync/inventory/push') {
      final changes = (body?['changes'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((item) => Map<String, Object?>.from(item))
          .toList();
      pushed.addAll(changes);
      return {
        'module': 'inventory',
        'accepted': changes.length,
        'rejected': 0,
        'serverTime': '2026-06-23T10:00:00.000Z',
        'errors': <String>[],
      };
    }
    if (path == '/api/sync/inventory/pull') {
      return {
        'module': 'inventory',
        'changes': remoteChanges,
        'serverTime': '2026-06-23T10:01:00.000Z',
        'hasMore': false,
      };
    }
    if (path == '/api/sync/inventory/images/push') {
      final images = (body?['images'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((item) => Map<String, Object?>.from(item))
          .toList();
      pushedImageMetadata.addAll(images);
      return {
        'accepted': images.length,
        'rejected': 0,
        'serverTime': '2026-06-23T10:01:00.000Z',
        'errors': <String>[],
      };
    }
    if (path == '/api/sync/inventory/images/pull') {
      return {
        'images': remoteImages,
        'serverTime': '2026-06-23T10:01:00.000Z',
        'hasMore': false,
      };
    }
    if (path == '/api/sync/inventory/images/content/push') {
      pushedImageContent.add(Map<String, Object?>.from(body ?? const {}));
      return body ?? <String, dynamic>{};
    }
    return <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> get(String path) async {
    requestedPaths.add(path);
    final prefix = '/api/sync/inventory/images/';
    final suffix = '/content';
    if (path.startsWith(prefix) && path.endsWith(suffix)) {
      final uuid = path.substring(prefix.length, path.length - suffix.length);
      return Map<String, dynamic>.from(remoteImageContent[uuid] ?? const {});
    }
    return <String, dynamic>{};
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('crear producto offline inserta sync_outbox pending', () async {
    final fixture = await _InventoryFixture.open();
    addTearDown(fixture.close);

    await fixture.repository.crearProducto(
      _product(
        'product-a',
        precioVenta: 145.75,
        costoUnitario: 88.25,
        stock: 9,
        codigoReferencia: 'SKU-A',
      ),
      negocioId: 7,
    );

    final pending = await fixture.outbox.pending(module: 'inventory');
    final payload = pending.single.payloadAsMap();
    expect(pending, hasLength(1));
    expect(pending.single.entityType, 'product');
    expect(pending.single.entityUuid, 'product-a');
    expect(pending.single.status, SyncOutboxItem.statusPending);
    expect(payload['uuid'], 'product-a');
    expect(payload['nombre'], 'Producto product-a');
    expect(payload['precioVenta'], 145.75);
    expect(payload['costoUnitario'], 88.25);
    expect(payload['precioCompra'], 88.25);
    expect(payload['cantidad'], 9);
    expect(payload['codigoReferencia'], 'SKU-A');
    expect(payload.containsKey('precio_venta'), isFalse);
    expect(payload.containsKey('costo_unitario'), isFalse);
  });

  test('push marca producto como synced', () async {
    final fixture = await _InventoryFixture.open();
    addTearDown(fixture.close);

    await fixture.repository.crearProducto(_product('product-a'), negocioId: 7);
    final result = await fixture.engine.syncNow(module: 'inventory');
    final pending = await fixture.outbox.pending(module: 'inventory');
    final rows = await fixture.db.query(DatabaseSchema.productosTable);

    expect(result.pushedCount, 1);
    expect(pending, isEmpty);
    expect(rows.single['sync_status'], SyncStatus.synced);
  });

  test('push inventory envia precioVenta costo stock y codigo', () async {
    final fixture = await _InventoryFixture.open();
    addTearDown(fixture.close);

    await fixture.repository.crearProducto(
      _product(
        'product-price',
        precioVenta: 222.40,
        costoUnitario: 110.20,
        stock: 6,
        codigoReferencia: 'SKU-PRICE',
      ),
      negocioId: 7,
    );

    await fixture.engine.syncNow(module: 'inventory');

    final pushed = fixture.apiClient.pushed.single;
    final payload = Map<String, Object?>.from(
      pushed['payload'] as Map<dynamic, dynamic>,
    );
    expect(
      fixture.apiClient.requestedPaths,
      contains('/api/sync/inventory/push'),
    );
    expect(payload['precioVenta'], 222.40);
    expect(payload['costoUnitario'], 110.20);
    expect(payload['precioCompra'], 110.20);
    expect(payload['cantidad'], 6);
    expect(payload['stock'], 6);
    expect(payload['codigoReferencia'], 'SKU-PRICE');
  });

  test('pull inserta producto remoto', () async {
    final fixture = await _InventoryFixture.open(
      remoteChanges: [
        _remoteProduct(
          uuid: 'remote-a',
          name: 'Remoto',
          precioVenta: 77.50,
          costoUnitario: 45.25,
          stock: 12,
          codigoReferencia: 'REMOTE-A',
        ),
      ],
    );
    addTearDown(fixture.close);

    await fixture.engine.pullChanges(module: 'inventory');

    final rows = await fixture.db.query(DatabaseSchema.productosTable);
    expect(rows, hasLength(1));
    expect(rows.single['legacy_id'], 'remote-a');
    expect(rows.single['nombre'], 'Remoto');
    expect(rows.single['precio_venta'], 77.50);
    expect(rows.single['costo_unitario'], 45.25);
    expect(rows.single['precio_compra'], 45.25);
    expect(rows.single['cantidad'], 12);
    expect(rows.single['codigo_referencia'], 'REMOTE-A');
  });

  test('pull actualiza producto existente por uuid', () async {
    final fixture = await _InventoryFixture.open(
      remoteChanges: [
        _remoteProduct(
          uuid: 'shared',
          name: 'Nuevo',
          precioVenta: 91.75,
          costoUnitario: 60.50,
          stock: 8,
        ),
      ],
    );
    addTearDown(fixture.close);
    await fixture.insertProduct(uuid: 'shared', name: 'Viejo');

    await fixture.engine.pullChanges(module: 'inventory');

    final rows = await fixture.db.query(DatabaseSchema.productosTable);
    expect(rows, hasLength(1));
    expect(rows.single['nombre'], 'Nuevo');
    expect(rows.single['precio_venta'], 91.75);
    expect(rows.single['costo_unitario'], 60.50);
    expect(rows.single['cantidad'], 8);
  });

  test('segundo dispositivo recibe producto completo para fiado', () async {
    final fixture = await _InventoryFixture.open(
      remoteChanges: [
        _remoteProduct(
          uuid: 'billable-remote',
          name: 'Facturable',
          precioVenta: 130.99,
          costoUnitario: 70.25,
          stock: 5,
          codigoReferencia: 'BILL-1',
        ),
      ],
    );
    addTearDown(fixture.close);

    await fixture.engine.pullChanges(module: 'inventory');

    final billable = await fixture.repository.obtenerProductosFacturables(
      negocioId: 7,
    );
    expect(billable, hasLength(1));
    expect(billable.single.legacyId, 'billable-remote');
    expect(billable.single.nombre, 'Facturable');
    expect(billable.single.precioVenta, 130.99);
    expect(billable.single.costoUnitario, 70.25);
    expect(billable.single.stock, 5);
    expect(billable.single.codigoReferencia, 'BILL-1');
  });

  test(
    'producto antiguo con precio costo se backfillea con payload canonico',
    () async {
      final fixture = await _InventoryFixture.open();
      addTearDown(fixture.close);
      await fixture.insertProduct(
        uuid: '',
        name: 'Viejo',
        precioVenta: 155.25,
        costoUnitario: 90.10,
        codigoReferencia: 'OLD-1',
      );

      final result = await fixture.backfill.runForBusiness(
        negocioId: 7,
        force: true,
      );

      final pending = await fixture.outbox.pending(module: 'inventory');
      final payload = pending.single.payloadAsMap();
      expect(result.productsEnqueued, 1);
      expect(payload['uuid']?.toString(), startsWith('product-'));
      expect(payload['precioVenta'], 155.25);
      expect(payload['costoUnitario'], 90.10);
      expect(payload['codigoReferencia'], 'OLD-1');
      expect(payload.containsKey('precio_venta'), isFalse);
    },
  );

  test(
    'imagen antigua recibe uuid productUuid y metadata sin contenido',
    () async {
      final fixture = await _InventoryFixture.open();
      addTearDown(fixture.close);
      await fixture.insertProduct(uuid: 'product-with-image', name: 'Imagen');
      final imageId = await fixture.insertImage(
        productUuid: 'product-with-image',
        localPath: 'C:/tmp/product.jpg',
      );
      await fixture.db.update(
        DatabaseSchema.productoImagenesTable,
        {'uuid': null, 'product_uuid': null},
        where: 'id = ?',
        whereArgs: [imageId],
      );

      final result = await fixture.backfill.backfillImagesForBusiness(
        negocioId: 7,
      );

      final images = await fixture.db.query(
        DatabaseSchema.productoImagenesTable,
      );
      final pending = await fixture.outbox.pending(module: 'inventory_images');
      final payload = pending.single.payloadAsMap();
      expect(result.imagesEnqueued, 1);
      expect(images.single['uuid']?.toString(), startsWith('image-'));
      expect(images.single['product_uuid'], 'product-with-image');
      expect(payload['productUuid'], 'product-with-image');
      expect(payload.containsKey('contentBase64'), isFalse);
    },
  );

  test(
    'descarga lazy obtiene contenido solo para productUuid solicitado',
    () async {
      final bytes = utf8.encode('fake-image');
      final fixture = await _InventoryFixture.open(
        remoteImages: [
          {
            'uuid': 'image-remote',
            'productUuid': 'lazy-product',
            'serverId': 'image-server',
            'fileName': 'lazy.jpg',
            'mimeType': 'image/jpeg',
            'sizeBytes': bytes.length,
            'contentHash': 'hash-lazy',
            'sortOrder': 0,
            'hasContent': true,
            'updatedAt': '2026-06-23T10:02:00.000Z',
          },
        ],
        remoteImageContent: {
          'image-remote': {
            'imageUuid': 'image-remote',
            'productUuid': 'lazy-product',
            'contentBase64': base64Encode(bytes),
            'contentHash': 'hash-lazy',
            'mimeType': 'image/jpeg',
            'sizeBytes': bytes.length,
          },
        },
      );
      addTearDown(fixture.close);
      await fixture.insertProduct(uuid: 'lazy-product', name: 'Lazy');

      final applied = await fixture.mediaSync.downloadForProductUuids(
        negocioId: 7,
        productUuids: ['lazy-product'],
        metadataLimit: 10,
        contentLimit: 1,
      );

      final images = await fixture.db.query(
        DatabaseSchema.productoImagenesTable,
      );
      expect(applied, 1);
      expect(
        fixture.apiClient.requestedPaths,
        contains('/api/sync/inventory/images/pull'),
      );
      expect(
        fixture.apiClient.requestedPaths,
        contains('/api/sync/inventory/images/image-remote/content'),
      );
      expect(images.single['product_uuid'], 'lazy-product');
      expect(images.single['content_available'], 1);
      expect(File(images.single['local_path'] as String).existsSync(), isTrue);
    },
  );

  test('push metadata de imagen no sube binarios de golpe', () async {
    final fixture = await _InventoryFixture.open();
    addTearDown(fixture.close);
    await fixture.insertProduct(uuid: 'media-product', name: 'Media');
    await fixture.insertImage(
      productUuid: 'media-product',
      localPath: 'C:/tmp/media.jpg',
    );
    await fixture.backfill.backfillImagesForBusiness(negocioId: 7);

    await fixture.mediaSync.pushPendingMetadata(limit: 25);

    expect(fixture.apiClient.pushedImageMetadata, hasLength(1));
    expect(
      fixture.apiClient.pushedImageMetadata.single.containsKey('contentBase64'),
      isFalse,
    );
  });

  test(
    'SyncEngine procesa inventory_images legacy por endpoint canonico',
    () async {
      final fixture = await _InventoryFixture.open();
      addTearDown(fixture.close);
      await fixture.insertProduct(uuid: 'legacy-media', name: 'Legacy media');
      await fixture.insertImage(
        productUuid: 'legacy-media',
        localPath: 'C:/tmp/legacy-media.jpg',
      );
      await fixture.backfill.backfillImagesForBusiness(negocioId: 7);

      final result = await fixture.engine.syncNow(module: 'inventory_images');

      expect(result.error, isNull);
      expect(result.pendingCount, 0);
      expect(
        fixture.apiClient.requestedPaths,
        contains('/api/sync/inventory/images/push'),
      );
      expect(
        fixture.apiClient.requestedPaths,
        isNot(contains('/api/sync/inventory_images/push')),
      );
      expect(
        fixture.apiClient.requestedPaths,
        isNot(contains('/api/sync/inventory/images/pull')),
      );
      expect(fixture.apiClient.pushedImageMetadata, hasLength(1));
      expect(await fixture.outbox.pending(module: 'inventory_images'), isEmpty);
      expect(
        (await fixture.engine.recomputeStatus()).state,
        NewSyncUiState.allUpdated,
      );
    },
  );

  test(
    'evento legacy fallido se reactiva una vez y no pierde payload',
    () async {
      final fixture = await _InventoryFixture.open();
      addTearDown(fixture.close);
      await fixture.insertProduct(uuid: 'failed-media', name: 'Failed media');
      await fixture.insertImage(
        productUuid: 'failed-media',
        localPath: 'C:/tmp/failed-media.jpg',
      );
      await fixture.backfill.backfillImagesForBusiness(negocioId: 7);
      await fixture.db.update(
        DatabaseSchema.syncOutboxTable,
        {
          'status': SyncOutboxItem.statusFailed,
          'attempt_count': 99,
          'last_error': 'HTTP 400 /api/sync/inventory_images/push',
        },
        where: 'module = ?',
        whereArgs: ['inventory_images'],
      );

      final pushed = await fixture.engine.pushPending(
        module: 'inventory_images',
      );

      expect(pushed, 1);
      expect(fixture.apiClient.pushedImageMetadata, hasLength(1));
      expect(
        fixture.apiClient.pushedImageMetadata.single['productUuid'],
        'failed-media',
      );
      expect(
        await fixture.outbox.lastError(module: 'inventory_images'),
        isNull,
      );
      final syncedRows = await fixture.db.query(
        DatabaseSchema.syncOutboxTable,
        where: 'module = ?',
        whereArgs: ['inventory_images'],
      );
      expect(syncedRows.single['status'], SyncOutboxItem.statusSynced);
      expect(syncedRows.single['last_error'], isNull);
      expect(syncedRows.single['attempt_count'], 0);
    },
  );

  test('imagen fallida cinco veces no entra en reintento infinito', () async {
    final fixture = await _InventoryFixture.open();
    addTearDown(fixture.close);
    await (await SharedPreferences.getInstance()).setBool(
      'inventory_images_endpoint_migration_v1',
      true,
    );
    await fixture.outbox.enqueue(
      SyncOutboxItem.pending(
        businessId: '7',
        module: 'inventory_images',
        entityType: 'product_image',
        entityUuid: 'exhausted-image',
        operation: 'upsert',
        payload: const {
          'uuid': 'exhausted-image',
          'productUuid': 'product-image',
        },
      ),
    );
    await fixture.db.update(
      DatabaseSchema.syncOutboxTable,
      {
        'status': SyncOutboxItem.statusFailed,
        'attempt_count': SyncOutboxRepository.inventoryImageMaxAttempts,
        'last_error': 'Imagen rechazada por el backend',
      },
      where: 'entity_uuid = ?',
      whereArgs: ['exhausted-image'],
    );

    expect(await fixture.outbox.pending(module: 'inventory_images'), isEmpty);
    expect(
      await fixture.outbox.lastError(module: 'inventory_images'),
      'Imagen rechazada por el backend',
    );
  });

  test('diagnostico de imagen conserva ids y redacta contenido sensible', () {
    final item = SyncOutboxItem.pending(
      businessId: '7',
      module: 'inventory_images',
      entityType: 'product_image',
      entityUuid: 'image-diagnostic',
      operation: 'upsert_metadata',
      payload: const {
        'uuid': 'image-diagnostic',
        'productUuid': 'product-diagnostic',
        'mimeType': 'image/jpeg',
        'contentHash': 'hash-diagnostic',
        'contentBase64': '12345678901234567890SECRET_REMAINDER',
        'token': 'secret-token-value',
      },
    );

    final log = InventoryImageSyncDiagnostics.pushRequestLog(
      endpoint: Uri.parse('http://fiado.test/api/sync/inventory/images/push'),
      module: 'inventory_images',
      body: {
        'images': [item.payloadAsMap()],
      },
      items: [item],
    );

    expect(log, contains('image-diagnostic'));
    expect(log, contains('product-diagnostic'));
    expect(log, contains('hash-diagnostic'));
    expect(log, contains('12345678901234567890'));
    expect(log, contains(r'"length":36'));
    expect(log, isNot(contains('SECRET_REMAINDER')));
    expect(log, isNot(contains('secret-token-value')));
    expect(log, contains('[redacted]'));
  });

  test('soft delete remoto oculta producto local', () async {
    final fixture = await _InventoryFixture.open(
      remoteChanges: [
        _remoteProduct(
          uuid: 'deleted',
          name: 'Borrado',
          deletedAt: '2026-06-23T10:03:00.000Z',
        ),
      ],
    );
    addTearDown(fixture.close);
    await fixture.insertProduct(uuid: 'deleted', name: 'Borrado');

    await fixture.engine.pullChanges(module: 'inventory');

    final visible = await fixture.repository.obtenerProductos(negocioId: 7);
    final rows = await fixture.db.query(DatabaseSchema.productosTable);
    expect(visible, isEmpty);
    expect(rows.single['deleted_at'], isNotNull);
  });

  test(
    'dos usuarios del mismo negocio conservan productos distintos',
    () async {
      final fixture = await _InventoryFixture.open(
        remoteChanges: [
          _remoteProduct(uuid: 'owner-product', name: 'A'),
          _remoteProduct(uuid: 'collab-product', name: 'B'),
        ],
      );
      addTearDown(fixture.close);

      await fixture.engine.pullChanges(module: 'inventory');

      final products = await fixture.repository.obtenerProductos(negocioId: 7);
      expect(products.map((product) => product.id).toSet(), {
        'owner-product',
        'collab-product',
      });
    },
  );

  test('colaborador ve inventario del negocio', () async {
    final fixture = await _InventoryFixture.open(tipoUsuario: 'colaborador');
    addTearDown(fixture.close);
    await fixture.insertProduct(uuid: 'shared-business-product', name: 'A');

    final products = await fixture.repository.obtenerProductos(negocioId: 7);

    expect(products.single.id, 'shared-business-product');
  });

  test(
    'estado no muestra Todo actualizado si inventory tiene pending/error',
    () async {
      final fixture = await _InventoryFixture.open();
      addTearDown(fixture.close);
      await fixture.repository.crearProducto(
        _product('product-a'),
        negocioId: 7,
      );

      final pendingStatus = await fixture.engine.recomputeStatus();
      await fixture.outbox.markFailed(
        await fixture.outbox.pending(module: 'inventory'),
        'fallo inventory',
      );
      final failedStatus = await fixture.engine.recomputeStatus();

      expect(pendingStatus.state, NewSyncUiState.savedOnThisDevice);
      expect(pendingStatus.canShowAllUpdated, isFalse);
      expect(failedStatus.state, NewSyncUiState.error);
      expect(failedStatus.canShowAllUpdated, isFalse);
    },
  );
}

class _InventoryFixture {
  final Database db;
  final ProductoRepository repository;
  final SyncOutboxRepository outbox;
  final SyncEngine engine;
  final _InventoryApiClient apiClient;
  final InventoryBackfillService backfill;
  final InventoryMediaSyncService mediaSync;

  const _InventoryFixture({
    required this.db,
    required this.repository,
    required this.outbox,
    required this.engine,
    required this.apiClient,
    required this.backfill,
    required this.mediaSync,
  });

  static Future<_InventoryFixture> open({
    List<Map<String, Object?>> remoteChanges = const [],
    List<Map<String, Object?>> remoteImages = const [],
    Map<String, Map<String, Object?>> remoteImageContent = const {},
    String tipoUsuario = 'negocio',
  }) async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await db.execute(DatabaseSchema.createUsuariosTable);
    await db.execute(DatabaseSchema.createSesionesTable);
    await db.execute(DatabaseSchema.createProductosTable);
    await db.execute(DatabaseSchema.createProductoImagenesTable);
    await db.execute(DatabaseSchema.createSyncQueueTable);
    await db.execute(DatabaseSchema.createSyncOutboxTable);
    await db.execute(DatabaseSchema.createSyncStateTable);
    final localDatabase = _MemoryLocalDatabase(db);
    final outbox = SyncOutboxRepository(databaseHelper: localDatabase);
    final syncQueue = SyncQueueRepository(databaseHelper: localDatabase);
    final repository = ProductoRepository(
      databaseHelper: localDatabase,
      syncQueueRepository: syncQueue,
      syncOutboxRepository: outbox,
      inventoryMetricsRepository: _NoopInventoryMetricsRepository(),
    );
    final auth = AuthRepository(
      databaseHelper: localDatabase,
      syncQueueRepository: syncQueue,
    );
    await _insertSession(db, tipoUsuario: tipoUsuario);
    final apiClient = _InventoryApiClient(
      authRepository: auth,
      sharedPreferences: SharedPreferences.getInstance(),
      remoteChanges: remoteChanges,
      remoteImages: remoteImages,
      remoteImageContent: remoteImageContent,
    );
    final backfill = InventoryBackfillService(
      databaseHelper: localDatabase,
      syncOutboxRepository: outbox,
      sharedPreferences: SharedPreferences.getInstance(),
    );
    final mediaSync = InventoryMediaSyncService(
      databaseHelper: localDatabase,
      syncOutboxRepository: outbox,
      apiClient: apiClient,
    );
    final engine = SyncEngine(
      outboxRepository: outbox,
      stateRepository: SyncStateRepository(databaseHelper: localDatabase),
      deviceIdentityService: SyncDeviceIdentityService(
        sharedPreferences: SharedPreferences.getInstance(),
      ),
      apiClient: apiClient,
      authRepository: auth,
      adapters: [
        InventorySyncAdapter(
          productoRepository: repository,
          authRepository: auth,
        ),
      ],
    );
    return _InventoryFixture(
      db: db,
      repository: repository,
      outbox: outbox,
      engine: engine,
      apiClient: apiClient,
      backfill: backfill,
      mediaSync: mediaSync,
    );
  }

  Future<void> insertProduct({
    required String uuid,
    required String name,
    double precioVenta = 10,
    double costoUnitario = 5,
    String? codigoReferencia,
  }) async {
    await db.insert(DatabaseSchema.productosTable, {
      'negocio_id': 7,
      'legacy_id': uuid,
      'nombre': name,
      'cantidad': 1,
      'costo_unitario': costoUnitario,
      'precio_compra': costoUnitario,
      'precio_venta': precioVenta,
      'porcentaje_ganancia': 100,
      'stock_minimo': 1,
      'codigo_referencia': codigoReferencia,
      'activo': 1,
      'sync_status': SyncStatus.synced,
      'sync_version': 0,
      'created_at': '2026-06-23T09:00:00.000Z',
      'updated_at': '2026-06-23T09:00:00.000Z',
      'ubicacion': 'A1',
      'tipo_medida': Producto.medidaUnidad,
      'nivel_demanda': Producto.demandaMedia,
      'es_clave': 0,
    });
  }

  Future<int> insertImage({
    required String productUuid,
    required String localPath,
  }) async {
    final product = await db.query(
      DatabaseSchema.productosTable,
      columns: ['id'],
      where: 'legacy_id = ?',
      whereArgs: [productUuid],
      limit: 1,
    );
    return db.insert(DatabaseSchema.productoImagenesTable, {
      'negocio_id': 7,
      'producto_id': product.single['id'],
      'uuid': 'image-$productUuid',
      'product_uuid': productUuid,
      'local_path': localPath,
      'orden': 0,
      'mime_type': 'image/jpeg',
      'size_bytes': 100,
      'content_available': 1,
      'created_at': '2026-06-23T09:00:00.000Z',
      'updated_at': '2026-06-23T09:00:00.000Z',
      'sync_status': SyncStatus.pending,
    });
  }

  Future<void> close() => db.close();
}

Future<void> _insertSession(
  Database db, {
  String tipoUsuario = 'negocio',
}) async {
  await db.insert(DatabaseSchema.usuariosTable, {
    'id': tipoUsuario == 'colaborador' ? 8 : 7,
    'remote_id': 'user-remote',
    'nombre': 'Usuario',
    'telefono': '8099999999',
    'tipo_usuario': tipoUsuario,
    'negocio_id': tipoUsuario == 'colaborador' ? 7 : null,
    'password_hash': 'hash',
    'activo': 1,
    'created_at': '2026-06-23T09:00:00.000Z',
    'updated_at': '2026-06-23T09:00:00.000Z',
    'sync_status': SyncStatus.synced,
  });
  await db.insert(DatabaseSchema.sesionesTable, {
    'usuario_id': tipoUsuario == 'colaborador' ? 8 : 7,
    'started_at': '2026-06-23T09:00:00.000Z',
    'last_active_at': '2026-06-23T09:00:00.000Z',
    'is_active': 1,
  });
}

Producto _product(
  String uuid, {
  double precioVenta = 10,
  double costoUnitario = 5,
  int stock = 3,
  String? codigoReferencia,
}) {
  return Producto(
    id: uuid,
    nombre: 'Producto $uuid',
    codigoReferencia: codigoReferencia,
    ubicacion: 'A1',
    cantidad: stock,
    costoUnitario: costoUnitario,
    precioCompra: costoUnitario,
    precioVenta: precioVenta,
    porcentajeGanancia: 100,
    stockMinimo: 1,
    esClave: false,
  );
}

Map<String, Object?> _remoteProduct({
  required String uuid,
  required String name,
  String? deletedAt,
  double precioVenta = 10,
  double costoUnitario = 5,
  int stock = 4,
  String? codigoReferencia,
}) {
  return {
    'entityType': 'product',
    'uuid': uuid,
    'serverId': '$uuid-server',
    'businessId': '7',
    'nombre': name,
    'codigoReferencia': codigoReferencia ?? '$uuid-code',
    'categoria': 'General',
    'descripcion': null,
    'ubicacion': 'A1',
    'cantidad': stock,
    'costoUnitario': costoUnitario,
    'precioCompra': costoUnitario,
    'precioVenta': precioVenta,
    'porcentajeGanancia': 100,
    'stockMinimo': 1,
    'tipoMedida': Producto.medidaUnidad,
    'nivelDemanda': Producto.demandaMedia,
    'esClave': false,
    'createdAt': '2026-06-23T10:00:00.000Z',
    'updatedAt': '2026-06-23T10:02:00.000Z',
    'deletedAt': deletedAt,
    'syncVersion': 1,
  };
}
