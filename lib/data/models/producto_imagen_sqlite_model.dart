class ProductoImagenSqliteModel {
  final int? id;
  final int? negocioId;
  final int productoId;
  final String? uuid;
  final String? productUuid;
  final String? remoteId;
  final String localPath;
  final String? remoteUrl;
  final String? storageKey;
  final int orden;
  final String? mimeType;
  final int sizeBytes;
  final int? width;
  final int? height;
  final String? contentHash;
  final bool contentAvailable;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final DateTime? lastSyncedAt;
  final String syncStatus;

  const ProductoImagenSqliteModel({
    this.id,
    this.negocioId,
    required this.productoId,
    this.uuid,
    this.productUuid,
    this.remoteId,
    required this.localPath,
    this.remoteUrl,
    this.storageKey,
    this.orden = 0,
    this.mimeType,
    this.sizeBytes = 0,
    this.width,
    this.height,
    this.contentHash,
    this.contentAvailable = true,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.lastSyncedAt,
    this.syncStatus = 'pending',
  });

  factory ProductoImagenSqliteModel.fromMap(Map<String, Object?> map) {
    return ProductoImagenSqliteModel(
      id: (map['id'] as num?)?.toInt(),
      negocioId: (map['negocio_id'] as num?)?.toInt(),
      productoId: (map['producto_id'] as num).toInt(),
      uuid: map['uuid'] as String?,
      productUuid: map['product_uuid'] as String?,
      remoteId: map['remote_id'] as String?,
      localPath: map['local_path'] as String,
      remoteUrl: map['remote_url'] as String?,
      storageKey: map['storage_key'] as String?,
      orden: (map['orden'] as num? ?? 0).toInt(),
      mimeType: map['mime_type'] as String?,
      sizeBytes: (map['size_bytes'] as num? ?? 0).toInt(),
      width: (map['width'] as num?)?.toInt(),
      height: (map['height'] as num?)?.toInt(),
      contentHash: map['content_hash'] as String?,
      contentAvailable: (map['content_available'] as num? ?? 1).toInt() == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      deletedAt: map['deleted_at'] == null
          ? null
          : DateTime.parse(map['deleted_at'] as String),
      lastSyncedAt: map['last_synced_at'] == null
          ? null
          : DateTime.parse(map['last_synced_at'] as String),
      syncStatus: map['sync_status'] as String? ?? 'pending',
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    return {
      if (includeId) 'id': id,
      'negocio_id': negocioId,
      'producto_id': productoId,
      'uuid': uuid,
      'product_uuid': productUuid,
      'remote_id': remoteId,
      'local_path': localPath,
      'remote_url': remoteUrl,
      'storage_key': storageKey,
      'orden': orden,
      'mime_type': mimeType,
      'size_bytes': sizeBytes,
      'width': width,
      'height': height,
      'content_hash': contentHash,
      'content_available': contentAvailable ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'last_synced_at': lastSyncedAt?.toIso8601String(),
      'sync_status': syncStatus,
    };
  }

  ProductoImagenSqliteModel copyWith({
    int? id,
    int? negocioId,
    int? productoId,
    String? uuid,
    String? productUuid,
    String? remoteId,
    String? localPath,
    String? remoteUrl,
    String? storageKey,
    int? orden,
    String? mimeType,
    int? sizeBytes,
    int? width,
    int? height,
    String? contentHash,
    bool? contentAvailable,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    DateTime? lastSyncedAt,
    String? syncStatus,
  }) {
    return ProductoImagenSqliteModel(
      id: id ?? this.id,
      negocioId: negocioId ?? this.negocioId,
      productoId: productoId ?? this.productoId,
      uuid: uuid ?? this.uuid,
      productUuid: productUuid ?? this.productUuid,
      remoteId: remoteId ?? this.remoteId,
      localPath: localPath ?? this.localPath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      storageKey: storageKey ?? this.storageKey,
      orden: orden ?? this.orden,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      width: width ?? this.width,
      height: height ?? this.height,
      contentHash: contentHash ?? this.contentHash,
      contentAvailable: contentAvailable ?? this.contentAvailable,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
