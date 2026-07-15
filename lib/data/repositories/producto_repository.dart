import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

import '../../core/database/database_helper.dart';
import '../../core/database/local_database.dart';
import '../../core/database/database_schema.dart';
import '../../core/sync/sync_status.dart';
import '../models/billable_product.dart';
import '../../models/producto.dart';
import '../models/producto_imagen_sqlite_model.dart';
import '../models/producto_sqlite_model.dart';
import '../models/sync_outbox_item.dart';
import 'billable_product_query.dart';
import 'inventory_product_metrics_repository.dart';
import 'producto_imagen_repository.dart';
import 'sync_outbox_repository.dart';
import 'sync_queue_repository.dart';

class ProductoDuplicadoException implements Exception {
  final String message;

  const ProductoDuplicadoException([
    this.message =
        'Ya existe un articulo con ese nombre o codigo de referencia en este negocio.',
  ]);

  @override
  String toString() => message;
}

class ProductoRepository {
  final LocalDatabase databaseHelper;
  final SyncQueueRepository syncQueueRepository;
  final SyncOutboxRepository syncOutboxRepository;
  final ProductoImagenRepository productoImagenRepository;
  final InventoryProductMetricsRepository inventoryMetricsRepository;

  ProductoRepository({
    LocalDatabase? databaseHelper,
    SyncQueueRepository? syncQueueRepository,
    SyncOutboxRepository? syncOutboxRepository,
    ProductoImagenRepository? productoImagenRepository,
    InventoryProductMetricsRepository? inventoryMetricsRepository,
  }) : databaseHelper = databaseHelper ?? DatabaseHelper.instance,
       syncQueueRepository = syncQueueRepository ?? SyncQueueRepository(),
       syncOutboxRepository =
           syncOutboxRepository ??
           SyncOutboxRepository(databaseHelper: databaseHelper),
       productoImagenRepository =
           productoImagenRepository ?? ProductoImagenRepository(),
       inventoryMetricsRepository =
           inventoryMetricsRepository ?? InventoryProductMetricsRepository();

  Future<int> crearProducto(
    Producto producto, {
    required int negocioId,
    List<ProductoImagenSqliteModel> imagenes = const [],
  }) async {
    await validarProductoUnico(
      negocioId: negocioId,
      nombre: producto.nombre,
      codigoReferencia: producto.codigoReferencia,
    );
    if (imagenes.length > ProductoImagenRepository.maxImagenesPorProducto) {
      throw StateError('Solo puedes agregar hasta 3 imagenes por articulo.');
    }
    for (final image in imagenes) {
      productoImagenRepository.validarPesoMaximo(image.sizeBytes);
      productoImagenRepository.validarFormatoPermitido(
        image.mimeType,
        localPath: image.localPath,
      );
    }

    final db = await databaseHelper.database;
    final model = ProductoSqliteModel.fromLegacy(
      producto,
      negocioId: negocioId,
    );
    final existingId = await obtenerIdSqlitePorLegacyId(
      producto.id,
      negocioId: negocioId,
    );
    final int id;
    if (existingId == null) {
      id = await db.insert(
        DatabaseSchema.productosTable,
        model.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } else {
      id = existingId;
      await db.update(
        DatabaseSchema.productosTable,
        model
            .copyWith(id: id, syncStatus: SyncStatus.updated)
            .toMap(includeId: true),
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    final payloadModel = existingId == null
        ? model
        : model.copyWith(id: id, syncStatus: SyncStatus.updated);
    final payload = {...payloadModel.toMap(), 'id': id};
    if (existingId == null) {
      await syncQueueRepository.enqueueCreate(
        entityType: DatabaseSchema.productosTable,
        entityId: id,
        payload: payload,
      );
    } else {
      await syncQueueRepository.enqueueUpdate(
        entityType: DatabaseSchema.productosTable,
        entityId: id,
        payload: payload,
      );
    }
    await _enqueueInventoryOutbox(
      payload,
      existingId == null ? 'create' : 'update',
    );
    if (imagenes.isNotEmpty) {
      await productoImagenRepository.reemplazarImagenesProducto(
        negocioId: negocioId,
        productoId: id,
        imagenes: imagenes,
      );
    }
    await inventoryMetricsRepository.markProductDirty(
      negocioId: negocioId,
      productoId: id,
    );
    return id;
  }

  Future<void> actualizarProducto(
    Producto producto, {
    required int negocioId,
  }) async {
    final db = await databaseHelper.database;
    await validarProductoUnico(
      negocioId: negocioId,
      nombre: producto.nombre,
      codigoReferencia: producto.codigoReferencia,
      excluirLegacyId: producto.id,
    );
    final model = ProductoSqliteModel.fromLegacy(
      producto,
      negocioId: negocioId,
    ).copyWith(updatedAt: DateTime.now(), syncStatus: SyncStatus.updated);

    final updated = await db.update(
      DatabaseSchema.productosTable,
      model.toMap(),
      where: 'negocio_id = ? AND legacy_id = ?',
      whereArgs: [negocioId, producto.id],
    );

    if (updated == 0) {
      await crearProducto(producto, negocioId: negocioId);
      return;
    }
    final id = await obtenerIdSqlitePorLegacyId(
      producto.id,
      negocioId: negocioId,
    );
    if (id != null) {
      await syncQueueRepository.enqueueUpdate(
        entityType: DatabaseSchema.productosTable,
        entityId: id,
        payload: {...model.toMap(), 'id': id},
      );
      final rows = await db.query(
        DatabaseSchema.productosTable,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        await _enqueueInventoryOutbox(rows.first, 'update');
      }
      await inventoryMetricsRepository.markProductDirty(
        negocioId: negocioId,
        productoId: id,
      );
    }
  }

  Future<Producto?> obtenerProductoPorLegacyId(
    String legacyId, {
    required int negocioId,
  }) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.productosTable,
      where: 'negocio_id = ? AND legacy_id = ? AND activo = ?',
      whereArgs: [negocioId, legacyId, 1],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return ProductoSqliteModel.fromMap(rows.first).toLegacyModel();
  }

  Future<Producto?> obtenerProductoPorCodigoReferencia(
    String codigoReferencia, {
    required int negocioId,
  }) async {
    final normalizedCode = codigoReferencia.trim();
    if (normalizedCode.isEmpty) return null;

    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.productosTable,
      where:
          'negocio_id = ? AND activo = 1 AND LOWER(codigo_referencia) = LOWER(?)',
      whereArgs: [negocioId, normalizedCode],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ProductoSqliteModel.fromMap(rows.first).toLegacyModel();
  }

  Future<Map<String, int>> obtenerIdsSqlitePorLegacyIds(
    List<String> legacyIds, {
    required int negocioId,
  }) async {
    final ids = legacyIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) return const <String, int>{};

    final db = await databaseHelper.database;
    final placeholders = List.filled(ids.length, '?').join(', ');
    final rows = await db.query(
      DatabaseSchema.productosTable,
      columns: ['id', 'legacy_id'],
      where: 'negocio_id = ? AND activo = 1 AND legacy_id IN ($placeholders)',
      whereArgs: [negocioId, ...ids],
    );

    return {
      for (final row in rows)
        if (row['legacy_id'] != null && row['id'] != null)
          row['legacy_id'] as String: (row['id'] as num).toInt(),
    };
  }

  Future<int?> obtenerIdSqlitePorLegacyId(
    String legacyId, {
    required int negocioId,
  }) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.productosTable,
      columns: ['id'],
      where: 'negocio_id = ? AND legacy_id = ? AND activo = ?',
      whereArgs: [negocioId, legacyId, 1],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as int?;
  }

  Future<void> validarProductoUnico({
    required int negocioId,
    required String nombre,
    String? codigoReferencia,
    String? excluirLegacyId,
  }) async {
    final normalizedName = nombre.trim();
    if (normalizedName.isEmpty) {
      throw StateError('El nombre del articulo es obligatorio.');
    }

    final db = await databaseHelper.database;
    final whereParts = <String>['negocio_id = ?', 'activo = 1'];
    final whereArgs = <Object?>[negocioId];

    if (excluirLegacyId != null && excluirLegacyId.trim().isNotEmpty) {
      whereParts.add('legacy_id != ?');
      whereArgs.add(excluirLegacyId);
    }

    final normalizedCode = codigoReferencia?.trim();
    if (normalizedCode != null && normalizedCode.isNotEmpty) {
      whereParts.add(
        '(LOWER(nombre) = LOWER(?) OR LOWER(codigo_referencia) = LOWER(?))',
      );
      whereArgs.addAll([normalizedName, normalizedCode]);
    } else {
      whereParts.add('LOWER(nombre) = LOWER(?)');
      whereArgs.add(normalizedName);
    }

    final rows = await db.query(
      DatabaseSchema.productosTable,
      columns: ['id'],
      where: whereParts.join(' AND '),
      whereArgs: whereArgs,
      limit: 1,
    );
    if (rows.isNotEmpty) {
      throw const ProductoDuplicadoException();
    }
  }

  Future<void> eliminarLogico(String legacyId, {required int negocioId}) async {
    final db = await databaseHelper.database;
    await db.update(
      DatabaseSchema.productosTable,
      {
        'activo': 0,
        'sync_status': SyncStatus.deleted,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'negocio_id = ? AND legacy_id = ?',
      whereArgs: [negocioId, legacyId],
    );
    final rows = await db.query(
      DatabaseSchema.productosTable,
      where: 'negocio_id = ? AND legacy_id = ?',
      whereArgs: [negocioId, legacyId],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      await inventoryMetricsRepository.markProductDirty(
        negocioId: negocioId,
        productoId: rows.first['id'] as int,
      );
      await syncQueueRepository.enqueueDelete(
        entityType: DatabaseSchema.productosTable,
        entityId: rows.first['id'] as int,
        payload: rows.first,
      );
      await _enqueueInventoryOutbox(rows.first, 'delete');
    }
  }

  Future<List<Producto>> obtenerProductos({
    required int negocioId,
    int limit = 50,
    int offset = 0,
    String? busqueda,
    bool soloActivos = true,
  }) async {
    final db = await databaseHelper.database;
    final normalizedSearch = busqueda?.trim();
    final whereParts = <String>[];
    final whereArgs = <Object?>[];
    whereParts.add('negocio_id = ?');
    whereArgs.add(negocioId);

    if (soloActivos) {
      whereParts.add('activo = ?');
      whereArgs.add(1);
    }

    if (normalizedSearch != null && normalizedSearch.isNotEmpty) {
      whereParts.add(
        '(nombre LIKE ? OR categoria LIKE ? OR codigo_referencia LIKE ?)',
      );
      whereArgs.addAll([
        '%$normalizedSearch%',
        '%$normalizedSearch%',
        '%$normalizedSearch%',
      ]);
    }

    final rows = await db.query(
      DatabaseSchema.productosTable,
      where: whereParts.isEmpty ? null : whereParts.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'nombre COLLATE NOCASE ASC',
      limit: limit,
      offset: offset,
    );

    return rows
        .map((row) => ProductoSqliteModel.fromMap(row).toLegacyModel())
        .toList();
  }

  Future<List<BillableProduct>> obtenerProductosFacturables({
    required int negocioId,
    bool soloConStock = true,
  }) async {
    final db = await databaseHelper.database;
    return BillableProductQuery.obtenerProductosFacturables(
      db,
      negocioId: negocioId,
      soloConStock: soloConStock,
    );
  }

  Future<void> actualizarStock({
    required int negocioId,
    required String legacyId,
    required int cantidad,
  }) async {
    final db = await databaseHelper.database;
    await db.update(
      DatabaseSchema.productosTable,
      {
        'cantidad': cantidad,
        'sync_status': SyncStatus.updated,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'negocio_id = ? AND legacy_id = ? AND activo = ?',
      whereArgs: [negocioId, legacyId, 1],
    );
    final id = await obtenerIdSqlitePorLegacyId(legacyId, negocioId: negocioId);
    if (id != null) {
      final rows = await db.query(
        DatabaseSchema.productosTable,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        await syncQueueRepository.enqueueUpdate(
          entityType: DatabaseSchema.productosTable,
          entityId: id,
          payload: rows.first,
        );
        await _enqueueInventoryOutbox(rows.first, 'update');
        await inventoryMetricsRepository.markProductDirty(
          negocioId: negocioId,
          productoId: id,
        );
      }
    }
  }

  Future<int> contarProductosActivos({required int negocioId}) async {
    final db = await databaseHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM ${DatabaseSchema.productosTable} WHERE negocio_id = ? AND activo = 1',
      [negocioId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> guardarProductos(
    List<Producto> productos, {
    required int negocioId,
  }) async {
    final dbForTransaction = await databaseHelper.database;
    await dbForTransaction.transaction((transaction) async {
      final batch = transaction.batch();

      for (final producto in productos) {
        batch.insert(
          DatabaseSchema.productosTable,
          ProductoSqliteModel.fromLegacy(
            producto,
            negocioId: negocioId,
          ).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
    });

    final db = await databaseHelper.database;
    for (final producto in productos) {
      final id = await obtenerIdSqlitePorLegacyId(
        producto.id,
        negocioId: negocioId,
      );
      if (id != null) {
        final rows = await db.query(
          DatabaseSchema.productosTable,
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (rows.isNotEmpty) {
          await syncQueueRepository.enqueueCreate(
            entityType: DatabaseSchema.productosTable,
            entityId: id,
            payload: rows.first,
          );
          await _enqueueInventoryOutbox(rows.first, 'create');
          await inventoryMetricsRepository.markProductDirty(
            negocioId: negocioId,
            productoId: id,
          );
        }
      }
    }
  }

  Future<void> markProductSyncedByUuid({
    required String uuid,
    required DateTime serverTime,
  }) async {
    final db = await databaseHelper.database;
    await db.update(
      DatabaseSchema.productosTable,
      {
        'sync_status': SyncStatus.synced,
        'last_synced_at': DateTime.now().toIso8601String(),
        'updated_at': serverTime.toIso8601String(),
      },
      where: 'legacy_id = ?',
      whereArgs: [uuid],
    );
  }

  Future<void> upsertFromSync({
    required int negocioId,
    required Map<String, Object?> payload,
  }) async {
    final db = await databaseHelper.database;
    final uuid = _text(payload, 'uuid', 'legacyId', 'legacy_id');
    if (uuid == null || uuid.isEmpty) return;
    final updatedAt =
        DateTime.tryParse(_text(payload, 'updatedAt', 'updated_at') ?? '') ??
        DateTime.now();
    final deletedAt = DateTime.tryParse(
      _text(payload, 'deletedAt', 'deleted_at') ?? '',
    );
    final rows = await db.query(
      DatabaseSchema.productosTable,
      where: 'negocio_id = ? AND legacy_id = ?',
      whereArgs: [negocioId, uuid],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final currentUpdatedAt = DateTime.tryParse(
        rows.first['updated_at']?.toString() ?? '',
      );
      if (currentUpdatedAt != null && currentUpdatedAt.isAfter(updatedAt)) {
        return;
      }
    }

    final values = <String, Object?>{
      'negocio_id': negocioId,
      'legacy_id': uuid,
      'remote_id': _text(payload, 'serverId', 'remoteId', 'remote_id'),
      'nombre': _text(payload, 'nombre', 'name') ?? 'Producto',
      'categoria': _text(payload, 'categoria', 'category'),
      'descripcion': _text(payload, 'descripcion', 'description'),
      'cantidad': _int(payload, 'cantidad', 'quantity', 'stock') ?? 0,
      'costo_unitario':
          _double(payload, 'costoUnitario', 'unitCost', 'costo_unitario') ?? 0,
      'precio_compra':
          _double(payload, 'precioCompra', 'purchasePrice', 'precio_compra') ??
          0,
      'precio_venta':
          _double(payload, 'precioVenta', 'salePrice', 'precio_venta') ?? 0,
      'porcentaje_ganancia':
          _double(
            payload,
            'porcentajeGanancia',
            'profitMarginPercent',
            'porcentaje_ganancia',
          ) ??
          0,
      'stock_minimo':
          _int(payload, 'stockMinimo', 'minimumStock', 'stock_minimo') ?? 0,
      'codigo_referencia': _text(
        payload,
        'codigoReferencia',
        'codeReference',
        'codigo_referencia',
      ),
      'activo': deletedAt == null ? 1 : 0,
      'deleted_at': deletedAt?.toIso8601String(),
      'last_synced_at': DateTime.now().toIso8601String(),
      'sync_status': SyncStatus.synced,
      'sync_version': _int(payload, 'syncVersion', 'sync_version') ?? 0,
      'created_at':
          _text(payload, 'createdAt', 'created_at') ??
          updatedAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'ubicacion': _text(payload, 'ubicacion', 'location') ?? 'Sin ubicacion',
      'tipo_medida':
          _text(payload, 'tipoMedida', 'measureType', 'tipo_medida') ??
          'unidad',
      'nivel_demanda':
          _text(payload, 'nivelDemanda', 'demandLevel', 'nivel_demanda') ??
          'media',
      'es_clave':
          (_bool(payload, 'esClave', 'isKeyProduct', 'es_clave') ?? false)
          ? 1
          : 0,
      'disponibilidad_confirmada': 0,
      'disponibilidad_corregida': 0,
      'requiere_verificacion_administrador': 0,
      'rotacion_semana_anterior': 0,
    };

    if (kDebugMode) {
      debugPrint(
        '[InventorySync] pull product uuid=$uuid nombre=${values['nombre']} '
        'precioVenta=${values['precio_venta']} costo=${values['costo_unitario']} '
        'stock=${values['cantidad']}',
      );
    }

    int? productId;
    if (rows.isEmpty) {
      productId = await db.insert(
        DatabaseSchema.productosTable,
        values,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      productId = rows.first['id'] as int?;
      await db.update(
        DatabaseSchema.productosTable,
        values,
        where: 'id = ?',
        whereArgs: [productId],
      );
    }
    if (productId != null) {
      if (kDebugMode) {
        debugPrint(
          '[InventorySync] applied product uuid=$uuid '
          'precioVenta=${values['precio_venta']} costo=${values['costo_unitario']}',
        );
      }
      await inventoryMetricsRepository.markProductDirty(
        negocioId: negocioId,
        productoId: productId,
      );
    }
  }

  Future<void> _enqueueInventoryOutbox(
    Map<String, Object?> row,
    String operation,
  ) async {
    final negocioId = row['negocio_id']?.toString();
    final uuid = row['legacy_id']?.toString();
    if (negocioId == null ||
        negocioId.trim().isEmpty ||
        uuid == null ||
        uuid.trim().isEmpty) {
      return;
    }
    debugPrint(
      '[InventorySync] enqueue entity=product operation=$operation uuid=$uuid',
    );
    final payload = _inventoryPayloadFromRow(row, uuid: uuid);
    if (kDebugMode) {
      debugPrint(
        '[InventorySync] push payload product uuid=$uuid '
        'nombre=${payload['nombre']} precioVenta=${payload['precioVenta']} '
        'costo=${payload['costoUnitario']} stock=${payload['cantidad']}',
      );
    }
    await syncOutboxRepository.enqueue(
      SyncOutboxItem.pending(
        businessId: negocioId,
        module: 'inventory',
        entityType: 'product',
        entityUuid: uuid,
        operation: operation,
        payload: payload,
      ),
    );
  }

  Map<String, Object?> _inventoryPayloadFromRow(
    Map<String, Object?> row, {
    required String uuid,
  }) {
    return {
      'uuid': uuid,
      'legacyId': uuid,
      'serverId': row['remote_id'],
      'nombre': row['nombre'],
      'codigoReferencia': row['codigo_referencia'],
      'categoria': row['categoria'],
      'descripcion': row['descripcion'],
      'ubicacion': row['ubicacion'],
      'cantidad': row['cantidad'],
      'stock': row['cantidad'],
      'costoUnitario': row['costo_unitario'] ?? row['precio_compra'],
      'precioCompra': row['precio_compra'] ?? row['costo_unitario'],
      'precioVenta': row['precio_venta'],
      'porcentajeGanancia': row['porcentaje_ganancia'],
      'stockMinimo': row['stock_minimo'],
      'tipoMedida': row['tipo_medida'],
      'nivelDemanda': row['nivel_demanda'],
      'esClave': row['es_clave'],
      'activo': row['activo'],
      'deletedAt': row['deleted_at'],
      'createdAt': row['created_at'],
      'updatedAt': row['updated_at'],
      'syncVersion': row['sync_version'],
    };
  }

  String? _text(
    Map<String, Object?> payload,
    String first, [
    String? second,
    String? third,
  ]) {
    for (final key in [first, second, third]) {
      if (key == null) continue;
      final value = payload[key];
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  int? _int(
    Map<String, Object?> payload,
    String first, [
    String? second,
    String? third,
  ]) {
    final text = _text(payload, first, second, third);
    return int.tryParse(text ?? '');
  }

  double? _double(
    Map<String, Object?> payload,
    String first, [
    String? second,
    String? third,
  ]) {
    final text = _text(payload, first, second, third);
    return double.tryParse(text ?? '');
  }

  bool? _bool(
    Map<String, Object?> payload,
    String first, [
    String? second,
    String? third,
  ]) {
    final text = _text(payload, first, second, third)?.toLowerCase();
    if (text == null) return null;
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return null;
  }
}
