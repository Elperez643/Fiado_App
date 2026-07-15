import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../core/database/database_schema.dart';
import '../../core/sync/sync_status.dart';
import '../models/producto_imagen_sqlite_model.dart';
import 'sync_queue_repository.dart';

class ProductoImagenRepository {
  static const int maxImagenesPorProducto = 3;
  static const int maxSizeBytes = 300 * 1024;
  static const Set<String> formatosPermitidos = {
    'image/png',
    'image/jpeg',
    'image/jpg',
  };

  final DatabaseHelper databaseHelper;
  final SyncQueueRepository syncQueueRepository;

  ProductoImagenRepository({
    DatabaseHelper? databaseHelper,
    SyncQueueRepository? syncQueueRepository,
  }) : databaseHelper = databaseHelper ?? DatabaseHelper.instance,
       syncQueueRepository = syncQueueRepository ?? SyncQueueRepository();

  Future<ProductoImagenSqliteModel> agregarImagenProducto({
    required int negocioId,
    required int productoId,
    required String localPath,
    int orden = 0,
    String? mimeType,
    int sizeBytes = 0,
    int? width,
    int? height,
  }) async {
    await validarProductoPerteneceANegocio(
      negocioId: negocioId,
      productoId: productoId,
    );
    await validarLimiteImagenes(
      negocioId: negocioId,
      productoId: productoId,
      nuevasImagenes: 1,
    );
    validarPesoMaximo(sizeBytes);
    validarFormatoPermitido(mimeType, localPath: localPath);

    final db = await databaseHelper.database;
    final now = DateTime.now();
    final productUuid = await _productUuidForId(
      negocioId: negocioId,
      productoId: productoId,
    );
    final image = ProductoImagenSqliteModel(
      negocioId: negocioId,
      productoId: productoId,
      uuid: _newUuid('image'),
      productUuid: productUuid,
      localPath: localPath,
      orden: orden,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      width: width,
      height: height,
      createdAt: now,
      updatedAt: now,
    );
    final id = await db.insert(
      DatabaseSchema.productoImagenesTable,
      image.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    final saved = image.copyWith(id: id);
    await syncQueueRepository.enqueueCreate(
      entityType: DatabaseSchema.productoImagenesTable,
      entityId: id,
      payload: saved.toMap(includeId: true),
    );
    return saved;
  }

  Future<List<ProductoImagenSqliteModel>> obtenerImagenesPorProducto(
    int productoId, {
    required int negocioId,
  }) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.productoImagenesTable,
      where: 'negocio_id = ? AND producto_id = ? AND sync_status != ?',
      whereArgs: [negocioId, productoId, SyncStatus.deleted],
      orderBy: 'orden ASC, id ASC',
    );
    return rows.map(ProductoImagenSqliteModel.fromMap).toList();
  }

  Future<Map<int, ProductoImagenSqliteModel>> obtenerPrimeraImagenPorProductos(
    List<int> productoIds, {
    required int negocioId,
  }) async {
    final ids = productoIds.toSet().toList(growable: false);
    if (ids.isEmpty) return const <int, ProductoImagenSqliteModel>{};

    final db = await databaseHelper.database;
    final placeholders = List.filled(ids.length, '?').join(', ');
    final rows = await db.rawQuery(
      '''
SELECT pi.*
FROM ${DatabaseSchema.productoImagenesTable} pi
INNER JOIN (
  SELECT producto_id, MIN(orden) AS min_orden, MIN(id) AS min_id
  FROM ${DatabaseSchema.productoImagenesTable}
  WHERE negocio_id = ?
    AND producto_id IN ($placeholders)
    AND sync_status != ?
  GROUP BY producto_id
) first_pi
  ON first_pi.producto_id = pi.producto_id
 AND first_pi.min_orden = pi.orden
WHERE pi.negocio_id = ?
  AND pi.producto_id IN ($placeholders)
  AND pi.sync_status != ?
ORDER BY pi.producto_id ASC, pi.orden ASC, pi.id ASC
''',
      [
        negocioId,
        ...ids,
        SyncStatus.deleted,
        negocioId,
        ...ids,
        SyncStatus.deleted,
      ],
    );

    final result = <int, ProductoImagenSqliteModel>{};
    for (final row in rows) {
      final image = ProductoImagenSqliteModel.fromMap(row);
      result.putIfAbsent(image.productoId, () => image);
    }
    return result;
  }

  Future<List<ProductoImagenSqliteModel>> obtenerImagenesPorProductUuids(
    List<String> productUuids, {
    required int negocioId,
  }) async {
    final uuids = productUuids
        .map((uuid) => uuid.trim())
        .where((uuid) => uuid.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (uuids.isEmpty) return const <ProductoImagenSqliteModel>[];

    final db = await databaseHelper.database;
    final placeholders = List.filled(uuids.length, '?').join(', ');
    final rows = await db.query(
      DatabaseSchema.productoImagenesTable,
      where:
          'negocio_id = ? AND product_uuid IN ($placeholders) AND sync_status != ?',
      whereArgs: [negocioId, ...uuids, SyncStatus.deleted],
      orderBy: 'product_uuid ASC, orden ASC, id ASC',
    );
    return rows.map(ProductoImagenSqliteModel.fromMap).toList(growable: false);
  }

  Future<void> eliminarImagen(int imagenId, {required int negocioId}) async {
    final db = await databaseHelper.database;
    await db.update(
      DatabaseSchema.productoImagenesTable,
      {
        'sync_status': SyncStatus.deleted,
        'deleted_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND negocio_id = ?',
      whereArgs: [imagenId, negocioId],
    );
    final rows = await db.query(
      DatabaseSchema.productoImagenesTable,
      where: 'id = ? AND negocio_id = ?',
      whereArgs: [imagenId, negocioId],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      await syncQueueRepository.enqueueDelete(
        entityType: DatabaseSchema.productoImagenesTable,
        entityId: imagenId,
        payload: rows.first,
      );
    }
  }

  Future<void> reemplazarImagenesProducto({
    required int negocioId,
    required int productoId,
    required List<ProductoImagenSqliteModel> imagenes,
  }) async {
    if (imagenes.length > maxImagenesPorProducto) {
      throw StateError('Solo puedes agregar hasta 3 imagenes por articulo.');
    }
    for (final image in imagenes) {
      validarPesoMaximo(image.sizeBytes);
      validarFormatoPermitido(image.mimeType, localPath: image.localPath);
    }

    await validarProductoPerteneceANegocio(
      negocioId: negocioId,
      productoId: productoId,
    );
    final actuales = await obtenerImagenesPorProducto(
      productoId,
      negocioId: negocioId,
    );
    for (final image in actuales) {
      if (image.id != null) {
        await eliminarImagen(image.id!, negocioId: negocioId);
      }
    }

    for (var i = 0; i < imagenes.length; i++) {
      final image = imagenes[i];
      await agregarImagenProducto(
        negocioId: negocioId,
        productoId: productoId,
        localPath: image.localPath,
        orden: i,
        mimeType: image.mimeType,
        sizeBytes: image.sizeBytes,
        width: image.width,
        height: image.height,
      );
    }
  }

  Future<void> validarLimiteImagenes({
    required int negocioId,
    required int productoId,
    int nuevasImagenes = 0,
  }) async {
    final actuales = await obtenerImagenesPorProducto(
      productoId,
      negocioId: negocioId,
    );
    if (actuales.length + nuevasImagenes > maxImagenesPorProducto) {
      throw StateError('Solo puedes agregar hasta 3 imagenes por articulo.');
    }
  }

  Future<void> validarProductoPerteneceANegocio({
    required int negocioId,
    required int productoId,
  }) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.productosTable,
      columns: ['id'],
      where: 'id = ? AND negocio_id = ? AND activo = 1',
      whereArgs: [productoId, negocioId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('El producto no pertenece al negocio activo.');
    }
  }

  Future<String?> _productUuidForId({
    required int negocioId,
    required int productoId,
  }) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.productosTable,
      columns: ['legacy_id'],
      where: 'id = ? AND negocio_id = ?',
      whereArgs: [productoId, negocioId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['legacy_id']?.toString();
  }

  void validarPesoMaximo(int sizeBytes) {
    if (sizeBytes > maxSizeBytes) {
      throw StateError('Cada imagen optimizada debe pesar maximo 300 KB.');
    }
  }

  void validarFormatoPermitido(String? mimeType, {String? localPath}) {
    final normalized = mimeType?.toLowerCase().trim();
    if (normalized != null &&
        normalized.isNotEmpty &&
        formatosPermitidos.contains(normalized)) {
      return;
    }

    final path = localPath?.toLowerCase() ?? '';
    if (path.endsWith('.png') ||
        path.endsWith('.jpg') ||
        path.endsWith('.jpeg')) {
      return;
    }

    throw StateError('Formato no permitido. Usa PNG o JPG.');
  }
}

String _newUuid(String prefix) {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return '$prefix-${bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';
}
