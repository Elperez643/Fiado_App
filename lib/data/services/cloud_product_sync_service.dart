import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../core/database/database_schema.dart';
import '../../core/sync/sync_status.dart';
import '../models/sync_queue_item_model.dart';
import '../models/usuario_sqlite_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/inventory_product_metrics_repository.dart';
import '../repositories/sync_queue_repository.dart';
import 'api_client.dart';
import 'sync_endpoint_registry.dart';

class ProductCloudSyncResult {
  final int productsSent;
  final int productsReceived;
  final int imagesSent;
  final int imagesReceived;
  final int errors;
  final String? message;

  const ProductCloudSyncResult({
    required this.productsSent,
    required this.productsReceived,
    required this.imagesSent,
    required this.imagesReceived,
    required this.errors,
    this.message,
  });

  ProductCloudSyncResult combine(ProductCloudSyncResult other) {
    return ProductCloudSyncResult(
      productsSent: productsSent + other.productsSent,
      productsReceived: productsReceived + other.productsReceived,
      imagesSent: imagesSent + other.imagesSent,
      imagesReceived: imagesReceived + other.imagesReceived,
      errors: errors + other.errors,
      message: other.message ?? message,
    );
  }
}

class CloudProductSyncService {
  static const _lastProductSyncPrefix = 'fiado_products_last_sync_';
  static const _lastImageSyncPrefix = 'fiado_product_images_last_sync_';
  static const _cloudBusinessIdKey = 'fiado_cloud_business_id';

  final ApiClient apiClient;
  final AuthRepository authRepository;
  final SyncQueueRepository syncQueueRepository;
  final InventoryProductMetricsRepository inventoryMetricsRepository;
  final DatabaseHelper databaseHelper;
  final Future<SharedPreferences> sharedPreferences;

  const CloudProductSyncService({
    required this.apiClient,
    required this.authRepository,
    required this.syncQueueRepository,
    required this.inventoryMetricsRepository,
    required this.databaseHelper,
    required this.sharedPreferences,
  });

  Future<ProductCloudSyncResult> syncProductsAndImages() async {
    final products = await syncProducts();
    final images = await syncProductImages();
    return products.combine(images);
  }

  Future<ProductCloudSyncResult> syncProducts() async {
    final push = await pushPendingProducts();
    final pull = await pullProducts();
    return push.combine(pull);
  }

  Future<ProductCloudSyncResult> syncProductImages() async {
    final push = await pushPendingProductImages();
    final pull = await pullProductImages();
    return push.combine(pull);
  }

  Future<ProductCloudSyncResult> pushPendingProducts() async {
    final negocioId = await _resolveNegocioId();
    final pending = await _pendingItems(DatabaseSchema.productosTable);
    if (pending.isEmpty) return _empty();

    for (final item in pending) {
      await syncQueueRepository.incrementarIntento(item.id!);
    }

    final products = pending.map((item) {
      final payload = item.payloadAsMap();
      return {
        'localId': item.entityId,
        'serverId': _stringOrNull(payload['remote_id']),
        'name': payload['nombre'] ?? '',
        'codeReference': _stringOrNull(payload['codigo_referencia']),
        'category': _stringOrNull(payload['categoria']),
        'location': _stringOrNull(payload['ubicacion']),
        'description': _stringOrNull(payload['descripcion']),
        'quantity': _intValue(payload['cantidad']),
        'purchasePrice': _doubleValue(
          payload['costo_unitario'] ?? payload['precio_compra'],
        ),
        'salePrice': _doubleValue(payload['precio_venta']),
        'profitMarginPercent': _doubleValue(payload['porcentaje_ganancia']),
        'minimumStock': _intValue(payload['stock_minimo']),
        'operation': item.operation,
        'updatedAt':
            payload['updated_at'] ??
            payload['updatedAt'] ??
            item.updatedAt.toIso8601String(),
      };
    }).toList();

    final response = await apiClient.post(
      LegacySyncEndpointRegistry.forHandler('products').pushPath,
      body: {'products': products},
    );
    final results = (response['results'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();

    var sent = 0;
    var errors = 0;
    for (final result in results) {
      final localId = (result['localId'] as num).toInt();
      final queueItem = pending.firstWhere((item) => item.entityId == localId);
      final status = result['status'] as String? ?? 'failed';
      final error = result['error'] as String?;
      if (error == null && status != 'failed') {
        await _markProductSynced(
          negocioId: negocioId,
          localId: localId,
          serverId: result['serverId'] as String?,
          serverUpdatedAt: result['serverUpdatedAt'] as String?,
        );
        await syncQueueRepository.marcarComoProcesado(queueItem.id!);
        sent++;
      } else {
        await syncQueueRepository.marcarComoFallido(
          queueItem.id!,
          error ?? 'El backend no pudo sincronizar el producto.',
        );
        errors++;
      }
    }

    return ProductCloudSyncResult(
      productsSent: sent,
      productsReceived: 0,
      imagesSent: 0,
      imagesReceived: 0,
      errors: errors,
    );
  }

  Future<ProductCloudSyncResult> pullProducts() async {
    final negocioId = await _resolveNegocioId();
    final prefs = await sharedPreferences;
    final lastSyncAt = prefs.getString('$_lastProductSyncPrefix$negocioId');

    final response = await apiClient.post(
      LegacySyncEndpointRegistry.forHandler('products').pullPath,
      body: {'lastSyncAt': lastSyncAt},
    );
    final products = (response['products'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final expectedBusinessId = prefs.getString(_cloudBusinessIdKey);

    var received = 0;
    for (final product in products) {
      _assertPulledBusiness(
        expectedBusinessId: expectedBusinessId,
        actualBusinessId: product['businessId'],
        entity: 'producto',
      );
      await _upsertPulledProduct(negocioId, product);
      received++;
    }

    final serverTime = response['serverTime'] as String?;
    if (serverTime != null) {
      await prefs.setString('$_lastProductSyncPrefix$negocioId', serverTime);
    }

    return ProductCloudSyncResult(
      productsSent: 0,
      productsReceived: received,
      imagesSent: 0,
      imagesReceived: 0,
      errors: 0,
    );
  }

  Future<ProductCloudSyncResult> pushPendingProductImages() async {
    final negocioId = await _resolveNegocioId();
    final pending = await _pendingItems(DatabaseSchema.productoImagenesTable);
    if (pending.isEmpty) return _empty();

    for (final item in pending) {
      await syncQueueRepository.incrementarIntento(item.id!);
    }

    final db = await databaseHelper.database;
    final images = <Map<String, Object?>>[];
    final skipped = <SyncQueueItemModel>[];
    for (final item in pending) {
      final payload = item.payloadAsMap();
      final productLocalId = _intValue(payload['producto_id']);
      final productRows = await db.query(
        DatabaseSchema.productosTable,
        columns: ['remote_id'],
        where: 'id = ? AND negocio_id = ?',
        whereArgs: [productLocalId, negocioId],
        limit: 1,
      );
      final productServerId = productRows.isEmpty
          ? null
          : productRows.first['remote_id'] as String?;
      if (productServerId == null && item.operation != 'delete') {
        skipped.add(item);
        continue;
      }
      images.add({
        'localId': item.entityId,
        'serverId': _stringOrNull(payload['remote_id']),
        'productLocalId': productLocalId,
        'productServerId': productServerId,
        'localPath': payload['local_path'] ?? '',
        'remoteUrl': _stringOrNull(payload['remote_url']),
        'storageKey': _stringOrNull(payload['storage_key']),
        'order': _intValue(payload['orden']),
        'mimeType': _stringOrNull(payload['mime_type']),
        'sizeBytes': _intValue(payload['size_bytes']),
        'width': payload['width'],
        'height': payload['height'],
        'operation': item.operation,
        'updatedAt':
            payload['updated_at'] ??
            payload['updatedAt'] ??
            item.updatedAt.toIso8601String(),
      });
    }

    for (final item in skipped) {
      await syncQueueRepository.marcarComoFallido(
        item.id!,
        'Sincroniza primero el producto asociado a esta imagen.',
      );
    }
    if (images.isEmpty) {
      return ProductCloudSyncResult(
        productsSent: 0,
        productsReceived: 0,
        imagesSent: 0,
        imagesReceived: 0,
        errors: skipped.length,
      );
    }

    final response = await apiClient.post(
      LegacySyncEndpointRegistry.forHandler('product_images').pushPath,
      body: {'images': images},
    );
    final results = (response['results'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();

    var sent = 0;
    var errors = skipped.length;
    for (final result in results) {
      final localId = (result['localId'] as num).toInt();
      final queueItem = pending.firstWhere((item) => item.entityId == localId);
      final status = result['status'] as String? ?? 'failed';
      final error = result['error'] as String?;
      if (error == null && status != 'failed') {
        await _markImageSynced(
          negocioId: negocioId,
          localId: localId,
          serverId: result['serverId'] as String?,
          serverUpdatedAt: result['serverUpdatedAt'] as String?,
        );
        await syncQueueRepository.marcarComoProcesado(queueItem.id!);
        sent++;
      } else {
        await syncQueueRepository.marcarComoFallido(
          queueItem.id!,
          error ?? 'El backend no pudo sincronizar la imagen.',
        );
        errors++;
      }
    }

    return ProductCloudSyncResult(
      productsSent: 0,
      productsReceived: 0,
      imagesSent: sent,
      imagesReceived: 0,
      errors: errors,
    );
  }

  Future<ProductCloudSyncResult> pullProductImages() async {
    final negocioId = await _resolveNegocioId();
    final prefs = await sharedPreferences;
    final lastSyncAt = prefs.getString('$_lastImageSyncPrefix$negocioId');

    final response = await apiClient.post(
      LegacySyncEndpointRegistry.forHandler('product_images').pullPath,
      body: {'lastSyncAt': lastSyncAt},
    );
    final images = (response['images'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final expectedBusinessId = prefs.getString(_cloudBusinessIdKey);

    var received = 0;
    for (final image in images) {
      _assertPulledBusiness(
        expectedBusinessId: expectedBusinessId,
        actualBusinessId: image['businessId'],
        entity: 'imagen de producto',
      );
      if (await _upsertPulledImage(negocioId, image)) {
        received++;
      }
    }

    final serverTime = response['serverTime'] as String?;
    if (serverTime != null) {
      await prefs.setString('$_lastImageSyncPrefix$negocioId', serverTime);
    }

    return ProductCloudSyncResult(
      productsSent: 0,
      productsReceived: 0,
      imagesSent: 0,
      imagesReceived: received,
      errors: 0,
    );
  }

  Future<List<SyncQueueItemModel>> _pendingItems(String table) async {
    final pending = await syncQueueRepository.obtenerPendientes(limit: 500);
    return pending
        .where((item) => item.entityType.toLowerCase() == table)
        .toList();
  }

  Future<int> _resolveNegocioId() async {
    final user = await authRepository.obtenerUsuarioActual();
    if (user == null) throw StateError('No hay una sesion local activa.');
    if (user.tipoUsuario == UsuarioSqliteModel.tipoPersonal) {
      throw StateError(
        'El usuario Personal no sincroniza productos de negocio.',
      );
    }
    final negocioId = user.tipoUsuario == UsuarioSqliteModel.tipoNegocio
        ? user.id
        : user.negocioId;
    if (negocioId == null) {
      throw StateError('El usuario actual no tiene negocio asociado.');
    }
    return negocioId;
  }

  Future<void> _markProductSynced({
    required int negocioId,
    required int localId,
    required String? serverId,
    required String? serverUpdatedAt,
  }) async {
    final db = await databaseHelper.database;
    await db.update(
      DatabaseSchema.productosTable,
      {
        'remote_id': serverId,
        'sync_status': SyncStatus.synced,
        'last_synced_at': DateTime.now().toIso8601String(),
        'updated_at': serverUpdatedAt,
      },
      where: 'id = ? AND negocio_id = ?',
      whereArgs: [localId, negocioId],
    );
  }

  Future<void> _markImageSynced({
    required int negocioId,
    required int localId,
    required String? serverId,
    required String? serverUpdatedAt,
  }) async {
    final db = await databaseHelper.database;
    await db.update(
      DatabaseSchema.productoImagenesTable,
      {
        'remote_id': serverId,
        'sync_status': SyncStatus.synced,
        'last_synced_at': DateTime.now().toIso8601String(),
        'updated_at': serverUpdatedAt,
      },
      where: 'id = ? AND negocio_id = ?',
      whereArgs: [localId, negocioId],
    );
  }

  Future<void> _upsertPulledProduct(
    int negocioId,
    Map<String, dynamic> product,
  ) async {
    final db = await databaseHelper.database;
    final serverId = product['id'] as String;
    final name = product['name'] as String? ?? '';
    final code = _stringOrNull(product['codeReference']);
    final now = DateTime.now().toIso8601String();
    final isActive = (product['isActive'] as bool? ?? true) ? 1 : 0;
    final values = {
      'negocio_id': negocioId,
      'remote_id': serverId,
      'nombre': name,
      'categoria': product['category'] as String?,
      'descripcion': product['description'] as String?,
      'cantidad': _intValue(product['quantity']),
      'costo_unitario': _doubleValue(
        product['purchasePrice'] ?? product['costUnitario'],
      ),
      'precio_compra': _doubleValue(
        product['purchasePrice'] ?? product['costUnitario'],
      ),
      'precio_venta': _doubleValue(product['salePrice']),
      'porcentaje_ganancia': _doubleValue(product['profitMarginPercent']),
      'stock_minimo': _intValue(product['minimumStock']),
      'codigo_referencia': code,
      'activo': isActive,
      'deleted_at': product['deletedAt'] as String?,
      'last_synced_at': now,
      'created_at': product['createdAt'] as String? ?? now,
      'updated_at': product['updatedAt'] as String? ?? now,
      'sync_status': SyncStatus.synced,
      'legacy_id': serverId,
      'ubicacion':
          product['location'] as String? ??
          product['ubicacion'] as String? ??
          product['category'] as String? ??
          'Sin ubicacion',
      'tipo_medida': 'unidad',
      'nivel_demanda': 'media',
      'es_clave': 0,
      'disponibilidad_confirmada': 0,
      'disponibilidad_corregida': 0,
      'requiere_verificacion_administrador': 0,
      'rotacion_semana_anterior': 0,
    };

    final where = code == null
        ? 'negocio_id = ? AND (remote_id = ? OR LOWER(nombre) = LOWER(?))'
        : 'negocio_id = ? AND (remote_id = ? OR LOWER(nombre) = LOWER(?) OR LOWER(codigo_referencia) = LOWER(?))';
    final args = code == null
        ? <Object?>[negocioId, serverId, name]
        : <Object?>[negocioId, serverId, name, code];
    final existing = await db.query(
      DatabaseSchema.productosTable,
      columns: ['id'],
      where: where,
      whereArgs: args,
      limit: 1,
    );

    if (existing.isEmpty) {
      final id = await db.insert(
        DatabaseSchema.productosTable,
        values,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      await inventoryMetricsRepository.markProductDirty(
        negocioId: negocioId,
        productoId: id,
      );
    } else {
      final id = existing.first['id'] as int;
      await db.update(
        DatabaseSchema.productosTable,
        values,
        where: 'id = ?',
        whereArgs: [id],
      );
      await inventoryMetricsRepository.markProductDirty(
        negocioId: negocioId,
        productoId: id,
      );
    }
  }

  Future<bool> _upsertPulledImage(
    int negocioId,
    Map<String, dynamic> image,
  ) async {
    final db = await databaseHelper.database;
    final productRows = await db.query(
      DatabaseSchema.productosTable,
      columns: ['id'],
      where: 'negocio_id = ? AND remote_id = ?',
      whereArgs: [negocioId, image['productId'] as String],
      limit: 1,
    );
    if (productRows.isEmpty) return false;

    final serverId = image['id'] as String;
    final now = DateTime.now().toIso8601String();
    final values = {
      'negocio_id': negocioId,
      'producto_id': productRows.first['id'],
      'remote_id': serverId,
      'local_path': image['localPath'] as String? ?? '',
      'remote_url': image['remoteUrl'] as String?,
      'storage_key': image['storageKey'] as String?,
      'orden': _intValue(image['order']),
      'mime_type': image['mimeType'] as String?,
      'size_bytes': _intValue(image['sizeBytes']),
      'width': image['width'],
      'height': image['height'],
      'created_at': image['createdAt'] as String? ?? now,
      'updated_at': image['updatedAt'] as String? ?? now,
      'deleted_at': image['deletedAt'] as String?,
      'last_synced_at': now,
      'sync_status': image['deletedAt'] == null
          ? SyncStatus.synced
          : SyncStatus.deleted,
    };

    final existing = await db.query(
      DatabaseSchema.productoImagenesTable,
      columns: ['id'],
      where: 'negocio_id = ? AND remote_id = ?',
      whereArgs: [negocioId, serverId],
      limit: 1,
    );
    if (existing.isEmpty) {
      await db.insert(
        DatabaseSchema.productoImagenesTable,
        values,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } else {
      await db.update(
        DatabaseSchema.productoImagenesTable,
        values,
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }
    return true;
  }

  ProductCloudSyncResult _empty() {
    return const ProductCloudSyncResult(
      productsSent: 0,
      productsReceived: 0,
      imagesSent: 0,
      imagesReceived: 0,
      errors: 0,
    );
  }

  String? _stringOrNull(Object? value) {
    final text = value?.toString();
    return text == null || text.trim().isEmpty ? null : text.trim();
  }

  int _intValue(Object? value) {
    return (value as num?)?.toInt() ?? int.tryParse('${value ?? ''}') ?? 0;
  }

  double _doubleValue(Object? value) {
    return (value as num?)?.toDouble() ??
        double.tryParse('${value ?? ''}') ??
        0;
  }

  void _assertPulledBusiness({
    required String? expectedBusinessId,
    required Object? actualBusinessId,
    required String entity,
  }) {
    final expected = expectedBusinessId?.trim().toLowerCase();
    final actual = actualBusinessId?.toString().trim().toLowerCase();
    if (expected == null ||
        expected.isEmpty ||
        actual == null ||
        actual.isEmpty) {
      return;
    }
    if (expected != actual) {
      throw StateError(
        'Sync bloqueado: el backend devolvio $entity de otro negocio.',
      );
    }
  }
}
