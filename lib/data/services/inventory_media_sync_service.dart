import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../core/database/database_schema.dart';
import '../../core/database/local_database.dart';
import '../../core/sync/sync_status.dart';
import '../repositories/sync_outbox_repository.dart';
import 'api_client.dart';
import 'sync_endpoint_registry.dart';

class InventoryMediaSyncService {
  final LocalDatabase databaseHelper;
  final SyncOutboxRepository syncOutboxRepository;
  final ApiClient apiClient;

  InventoryMediaSyncService({
    LocalDatabase? databaseHelper,
    SyncOutboxRepository? syncOutboxRepository,
    required this.apiClient,
  }) : databaseHelper = databaseHelper ?? DatabaseHelper.instance,
       syncOutboxRepository =
           syncOutboxRepository ??
           SyncOutboxRepository(databaseHelper: databaseHelper);

  Future<int> pushPendingMetadata({int limit = 25}) async {
    final stopwatch = Stopwatch()..start();
    final pending = (await syncOutboxRepository.pending(
      module: 'inventory_images',
      limit: limit,
    )).take(limit).toList(growable: false);
    if (pending.isEmpty) return 0;

    await syncOutboxRepository.markSyncing(pending);
    final response = await apiClient.post(
      SyncEndpointRegistry.inventoryImages.pushPath,
      body: {'images': pending.map((item) => item.payloadAsMap()).toList()},
    );
    final rejected = (response['rejected'] as num? ?? 0).toInt();
    if (rejected > 0) {
      final error = response['errors']?.toString() ?? 'metadata rechazada';
      await syncOutboxRepository.markFailed(pending, error);
      throw StateError(error);
    }
    await syncOutboxRepository.markSynced(pending);
    if (kDebugMode) {
      debugPrint(
        '[InventoryMediaSync] pushMetadata count=${pending.length} elapsedMs=${stopwatch.elapsedMilliseconds}',
      );
    }
    return pending.length;
  }

  Future<int> downloadForProductUuids({
    required int negocioId,
    required List<String> productUuids,
    int metadataLimit = 25,
    int contentLimit = 10,
  }) async {
    final uuids = productUuids
        .map((uuid) => uuid.trim())
        .where((uuid) => uuid.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (uuids.isEmpty) return 0;

    final metadata = await apiClient.post(
      SyncEndpointRegistry.inventoryImages.pullPath,
      body: {'productUuids': uuids, 'limit': metadataLimit, 'content': false},
    );
    final images = (metadata['images'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    if (kDebugMode) {
      debugPrint(
        '[InventoryMediaSync] pullMetadata productCount=${uuids.length} imageCount=${images.length}',
      );
    }

    var applied = 0;
    final missingContent = <String>[];
    for (final image in images) {
      final imageUuid = image['uuid']?.toString();
      final productUuid = image['productUuid']?.toString();
      if (imageUuid == null || productUuid == null) continue;
      final hasContent = await _upsertImageMetadata(
        negocioId: negocioId,
        image: image,
      );
      applied++;
      if (!hasContent) missingContent.add(imageUuid);
    }

    for (final imageUuid in missingContent.take(contentLimit)) {
      await downloadContent(imageUuid: imageUuid, negocioId: negocioId);
    }
    return applied;
  }

  Future<int> pushContentForProductUuids({
    required int negocioId,
    required List<String> productUuids,
    int limit = 10,
  }) async {
    final uuids = productUuids
        .map((uuid) => uuid.trim())
        .where((uuid) => uuid.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (uuids.isEmpty) return 0;
    final db = await databaseHelper.database;
    final placeholders = List.filled(uuids.length, '?').join(', ');
    final rows = await db.query(
      DatabaseSchema.productoImagenesTable,
      where:
          'negocio_id = ? AND product_uuid IN ($placeholders) AND content_available = 1 AND sync_status != ?',
      whereArgs: [negocioId, ...uuids, SyncStatus.deleted],
      orderBy: 'updated_at ASC, id ASC',
      limit: limit,
    );
    var pushed = 0;
    for (final row in rows) {
      final imageUuid = row['uuid']?.toString();
      final localPath = row['local_path']?.toString();
      if (imageUuid == null ||
          imageUuid.isEmpty ||
          localPath == null ||
          localPath.isEmpty ||
          !File(localPath).existsSync()) {
        continue;
      }
      final bytes = await File(localPath).readAsBytes();
      await apiClient.post(
        SyncEndpointRegistry.inventoryImageContentPushPath,
        body: {
          'imageUuid': imageUuid,
          'productUuid': row['product_uuid'],
          'contentBase64': base64Encode(bytes),
          'contentHash': row['content_hash'],
          'mimeType': row['mime_type'],
          'sizeBytes': bytes.length,
        },
      );
      pushed++;
    }
    return pushed;
  }

  Future<bool> downloadContent({
    required String imageUuid,
    required int negocioId,
  }) async {
    final response = await apiClient.get(
      SyncEndpointRegistry.inventoryImageContentPath(imageUuid),
    );
    final contentBase64 = response['contentBase64']?.toString();
    if (contentBase64 == null || contentBase64.isEmpty) return false;
    final bytes = base64Decode(contentBase64);
    final mimeType = response['mimeType']?.toString() ?? 'image/jpeg';
    final path = await _writeImageFile(
      imageUuid: imageUuid,
      mimeType: mimeType,
      bytes: bytes,
    );
    final db = await databaseHelper.database;
    await db.update(
      DatabaseSchema.productoImagenesTable,
      {
        'local_path': path,
        'mime_type': mimeType,
        'size_bytes': bytes.length,
        'content_hash': response['contentHash'],
        'content_available': 1,
        'sync_status': SyncStatus.synced,
        'last_synced_at': DateTime.now().toIso8601String(),
      },
      where: 'negocio_id = ? AND uuid = ?',
      whereArgs: [negocioId, imageUuid],
    );
    if (kDebugMode) {
      debugPrint(
        '[InventoryMediaSync] downloadContent imageUuid=$imageUuid size=${bytes.length}',
      );
      debugPrint(
        '[InventoryMediaSync] savedLocal imageUuid=$imageUuid productUuid=${response['productUuid']}',
      );
    }
    return true;
  }

  Future<bool> _upsertImageMetadata({
    required int negocioId,
    required Map<String, dynamic> image,
  }) async {
    final db = await databaseHelper.database;
    final imageUuid = image['uuid'].toString();
    final productUuid = image['productUuid'].toString();
    final productRows = await db.query(
      DatabaseSchema.productosTable,
      columns: ['id'],
      where: 'negocio_id = ? AND legacy_id = ?',
      whereArgs: [negocioId, productUuid],
      limit: 1,
    );
    if (productRows.isEmpty) return false;
    final productId = (productRows.first['id'] as num).toInt();
    final existing = await db.query(
      DatabaseSchema.productoImagenesTable,
      where: 'negocio_id = ? AND uuid = ?',
      whereArgs: [negocioId, imageUuid],
      limit: 1,
    );
    final hasContent =
        existing.isNotEmpty &&
        (existing.first['content_available'] as num? ?? 0).toInt() == 1 &&
        (existing.first['local_path']?.toString().isNotEmpty ?? false);
    final values = {
      'negocio_id': negocioId,
      'producto_id': productId,
      'uuid': imageUuid,
      'product_uuid': productUuid,
      'remote_id': image['serverId']?.toString(),
      'local_path': existing.isEmpty ? '' : existing.first['local_path'],
      'orden': (image['sortOrder'] as num? ?? 0).toInt(),
      'mime_type': image['mimeType']?.toString(),
      'size_bytes': (image['sizeBytes'] as num? ?? 0).toInt(),
      'width': (image['width'] as num?)?.toInt(),
      'height': (image['height'] as num?)?.toInt(),
      'content_hash': image['contentHash']?.toString(),
      'content_available': hasContent ? 1 : 0,
      'created_at':
          image['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      'updated_at':
          image['updatedAt']?.toString() ?? DateTime.now().toIso8601String(),
      'deleted_at': image['deletedAt']?.toString(),
      'sync_status': image['deletedAt'] == null
          ? SyncStatus.synced
          : SyncStatus.deleted,
      'last_synced_at': DateTime.now().toIso8601String(),
    };
    if (existing.isEmpty) {
      await db.insert(
        DatabaseSchema.productoImagenesTable,
        values,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      await db.update(
        DatabaseSchema.productoImagenesTable,
        values,
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }
    return hasContent;
  }

  static Future<String> _writeImageFile({
    required String imageUuid,
    required String mimeType,
    required List<int> bytes,
  }) async {
    final extension = mimeType.toLowerCase().contains('png') ? 'png' : 'jpg';
    final root = Directory('${await getDatabasesPath()}/inventory_images');
    if (!root.existsSync()) {
      root.createSync(recursive: true);
    }
    final file = File('${root.path}/$imageUuid.$extension');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}
