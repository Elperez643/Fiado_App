import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../core/database/database_schema.dart';
import '../../core/database/local_database.dart';
import '../../core/sync/sync_status.dart';
import '../models/sync_outbox_item.dart';
import '../repositories/sync_outbox_repository.dart';

class InventoryBackfillService {
  static const markerKey = 'inventory_backfill_v2_prices_images';
  static const markerCompleted = 'completed';

  final LocalDatabase databaseHelper;
  final SyncOutboxRepository syncOutboxRepository;
  final Future<SharedPreferences> sharedPreferences;

  InventoryBackfillService({
    LocalDatabase? databaseHelper,
    SyncOutboxRepository? syncOutboxRepository,
    required this.sharedPreferences,
  }) : databaseHelper = databaseHelper ?? DatabaseHelper.instance,
       syncOutboxRepository =
           syncOutboxRepository ??
           SyncOutboxRepository(databaseHelper: databaseHelper);

  Future<InventoryBackfillResult> runForBusiness({
    required int negocioId,
    bool force = false,
  }) async {
    final prefs = await sharedPreferences;
    if (!force &&
        prefs.getString(_markerForBusiness(negocioId)) == markerCompleted) {
      return const InventoryBackfillResult();
    }

    final db = await databaseHelper.database;
    await _ensureLegacyProductUuids(db, negocioId);
    final products = await db.query(
      DatabaseSchema.productosTable,
      where: 'negocio_id = ?',
      whereArgs: [negocioId],
      orderBy: 'updated_at ASC, id ASC',
    );
    var productsEnqueued = 0;
    for (final product in products) {
      final uuid = product['legacy_id']?.toString();
      if (uuid == null || uuid.trim().isEmpty) continue;
      if (await _hasPendingOutbox(db, module: 'inventory', entityUuid: uuid)) {
        continue;
      }
      await syncOutboxRepository.enqueue(
        SyncOutboxItem.pending(
          businessId: '$negocioId',
          module: 'inventory',
          entityType: 'product',
          entityUuid: uuid,
          operation: _isDeleted(product) ? 'delete' : 'update',
          payload: _productPayload(product, uuid: uuid, negocioId: negocioId),
        ),
      );
      productsEnqueued++;
    }

    final imageResult = await backfillImagesForBusiness(negocioId: negocioId);
    await prefs.setString(_markerForBusiness(negocioId), markerCompleted);
    if (kDebugMode) {
      debugPrint(
        '[InventoryBackfill] productsFound=${products.length} enqueued=$productsEnqueued',
      );
    }
    return InventoryBackfillResult(
      productsFound: products.length,
      productsEnqueued: productsEnqueued,
      imagesFound: imageResult.imagesFound,
      imagesEnqueued: imageResult.imagesEnqueued,
    );
  }

  Future<InventoryBackfillResult> backfillImagesForBusiness({
    required int negocioId,
    int limit = 200,
  }) async {
    final db = await databaseHelper.database;
    final rows = await db.rawQuery(
      '''
SELECT pi.*, p.legacy_id AS resolved_product_uuid
FROM ${DatabaseSchema.productoImagenesTable} pi
INNER JOIN ${DatabaseSchema.productosTable} p
  ON p.id = pi.producto_id
WHERE pi.negocio_id = ?
ORDER BY pi.updated_at ASC, pi.id ASC
LIMIT ?
''',
      [negocioId, limit],
    );

    var imagesEnqueued = 0;
    for (final row in rows) {
      final imageUuid = _nonEmpty(row['uuid']) ?? _newUuid('image');
      final productUuid =
          _nonEmpty(row['product_uuid']) ??
          _nonEmpty(row['resolved_product_uuid']);
      if (productUuid == null) continue;
      final contentHash =
          _nonEmpty(row['content_hash']) ??
          await _contentHashIfAvailable(row['local_path']?.toString());
      final updateValues = <String, Object?>{
        'uuid': imageUuid,
        'product_uuid': productUuid,
        'content_available': _localFileExists(row['local_path']?.toString())
            ? 1
            : (row['content_available'] as num? ?? 0).toInt(),
        'updated_at':
            _nonEmpty(row['updated_at']) ?? DateTime.now().toIso8601String(),
      };
      if (contentHash != null) {
        updateValues['content_hash'] = contentHash;
      }
      await db.update(
        DatabaseSchema.productoImagenesTable,
        updateValues,
        where: 'id = ?',
        whereArgs: [row['id']],
      );

      if (await _hasPendingOutbox(
        db,
        module: 'inventory_images',
        entityUuid: imageUuid,
      )) {
        continue;
      }
      await syncOutboxRepository.enqueue(
        SyncOutboxItem.pending(
          businessId: '$negocioId',
          module: 'inventory_images',
          entityType: 'product_image',
          entityUuid: imageUuid,
          operation: _isDeleted(row) ? 'delete' : 'upsert_metadata',
          payload: _imageMetadataPayload(
            row,
            imageUuid: imageUuid,
            productUuid: productUuid,
            contentHash: contentHash,
            includeContent: false,
          ),
        ),
      );
      imagesEnqueued++;
    }
    if (kDebugMode) {
      debugPrint(
        '[InventoryImageBackfill] imagesFound=${rows.length} enqueued=$imagesEnqueued',
      );
    }
    return InventoryBackfillResult(
      imagesFound: rows.length,
      imagesEnqueued: imagesEnqueued,
    );
  }

  Map<String, Object?> imageMetadataPayload(
    Map<String, Object?> row, {
    required String imageUuid,
    required String productUuid,
    String? contentHash,
    bool includeContent = false,
    String? contentBase64,
  }) {
    return _imageMetadataPayload(
      row,
      imageUuid: imageUuid,
      productUuid: productUuid,
      contentHash: contentHash,
      includeContent: includeContent,
      contentBase64: contentBase64,
    );
  }

  Future<void> _ensureLegacyProductUuids(Database db, int negocioId) async {
    await db.execute(
      '''
UPDATE ${DatabaseSchema.productosTable}
SET legacy_id = 'product-' || lower(hex(randomblob(16)))
WHERE negocio_id = ? AND (legacy_id IS NULL OR legacy_id = '')
''',
      [negocioId],
    );
  }

  Future<bool> _hasPendingOutbox(
    Database db, {
    required String module,
    required String entityUuid,
  }) async {
    final rows = await db.query(
      DatabaseSchema.syncOutboxTable,
      columns: ['id'],
      where: 'module = ? AND entity_uuid = ? AND status IN (?, ?, ?)',
      whereArgs: [
        module,
        entityUuid,
        SyncOutboxItem.statusPending,
        SyncOutboxItem.statusSyncing,
        SyncOutboxItem.statusFailed,
      ],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Map<String, Object?> _productPayload(
    Map<String, Object?> row, {
    required String uuid,
    required int negocioId,
  }) {
    return {
      'uuid': uuid,
      'businessId': '$negocioId',
      'nombre': row['nombre'],
      'precioVenta': row['precio_venta'],
      'costoUnitario': row['costo_unitario'] ?? row['precio_compra'],
      'precioCompra': row['precio_compra'] ?? row['costo_unitario'],
      'cantidad': row['cantidad'],
      'stock': row['cantidad'],
      'codigoReferencia': row['codigo_referencia'],
      'activo': (row['activo'] as num? ?? 1).toInt() == 1,
      'updatedAt':
          _nonEmpty(row['updated_at']) ?? DateTime.now().toIso8601String(),
      'deletedAt': row['deleted_at'],
      'syncVersion': row['sync_version'] ?? 0,
    };
  }

  Map<String, Object?> _imageMetadataPayload(
    Map<String, Object?> row, {
    required String imageUuid,
    required String productUuid,
    String? contentHash,
    bool includeContent = false,
    String? contentBase64,
  }) {
    return {
      'uuid': imageUuid,
      'productUuid': productUuid,
      'businessId': row['negocio_id']?.toString(),
      'fileName': _fileName(row['local_path']?.toString()),
      'mimeType': row['mime_type'],
      'sizeBytes': row['size_bytes'] ?? 0,
      'contentHash': contentHash,
      'width': row['width'],
      'height': row['height'],
      'isCover': (row['orden'] as num? ?? 0).toInt() == 0,
      'sortOrder': row['orden'] ?? 0,
      'updatedAt':
          _nonEmpty(row['updated_at']) ?? DateTime.now().toIso8601String(),
      'deletedAt': row['deleted_at'],
      if (includeContent && contentBase64 != null)
        'contentBase64': contentBase64,
    };
  }

  static bool _isDeleted(Map<String, Object?> row) {
    return row['deleted_at'] != null ||
        row['sync_status']?.toString() == SyncStatus.deleted;
  }

  static String? _nonEmpty(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static String? _fileName(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    return path.split(RegExp(r'[\\/]')).last;
  }

  static bool _localFileExists(String? path) {
    return path != null && path.trim().isNotEmpty && File(path).existsSync();
  }

  static Future<String?> _contentHashIfAvailable(String? path) async {
    if (!_localFileExists(path)) return null;
    final bytes = await File(path!).readAsBytes();
    var hash = 0x811c9dc5;
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return '${bytes.length}-${hash.toRadixString(16).padLeft(8, '0')}';
  }

  static String _newUuid(String prefix) {
    final now = DateTime.now().microsecondsSinceEpoch;
    return '$prefix-$now';
  }

  static String _markerForBusiness(int negocioId) => '${markerKey}_$negocioId';
}

class InventoryBackfillResult {
  final int productsFound;
  final int productsEnqueued;
  final int imagesFound;
  final int imagesEnqueued;

  const InventoryBackfillResult({
    this.productsFound = 0,
    this.productsEnqueued = 0,
    this.imagesFound = 0,
    this.imagesEnqueued = 0,
  });
}
