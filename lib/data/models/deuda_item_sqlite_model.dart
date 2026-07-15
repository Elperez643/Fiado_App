import 'dart:math';

class DeudaItemSqliteModel {
  final int? id;
  final int? negocioId;
  final int movimientoId;
  final int? productoId;
  final String nombreProducto;
  final String? codigoReferencia;
  final int cantidad;
  final double precioUnitario;
  final double subtotal;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String syncStatus;
  final String? localUuid;

  const DeudaItemSqliteModel({
    this.id,
    this.negocioId,
    required this.movimientoId,
    this.productoId,
    required this.nombreProducto,
    this.codigoReferencia,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
    this.createdAt,
    this.updatedAt,
    this.syncStatus = 'pending',
    this.localUuid,
  });

  factory DeudaItemSqliteModel.fromMap(Map<String, Object?> map) {
    return DeudaItemSqliteModel(
      id: map['id'] as int?,
      negocioId: (map['negocio_id'] as num?)?.toInt(),
      movimientoId: (map['movimiento_id'] as num).toInt(),
      productoId: (map['producto_id'] as num?)?.toInt(),
      nombreProducto: map['nombre_producto'] as String,
      codigoReferencia: map['codigo_referencia'] as String?,
      cantidad: (map['cantidad'] as num).toInt(),
      precioUnitario: (map['precio_unitario'] as num).toDouble(),
      subtotal: (map['subtotal'] as num).toDouble(),
      createdAt: map['created_at'] == null
          ? null
          : DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] == null
          ? null
          : DateTime.parse(map['updated_at'] as String),
      syncStatus: map['sync_status'] as String? ?? 'pending',
      localUuid: map['local_uuid'] as String?,
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    return {
      if (includeId) 'id': id,
      'negocio_id': negocioId,
      'movimiento_id': movimientoId,
      'producto_id': productoId,
      'nombre_producto': nombreProducto,
      'codigo_referencia': codigoReferencia,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
      'subtotal': subtotal,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'sync_status': syncStatus,
      'local_uuid': localUuid,
    };
  }

  DeudaItemSqliteModel copyWith({
    int? id,
    int? negocioId,
    int? movimientoId,
    int? productoId,
    String? nombreProducto,
    String? codigoReferencia,
    int? cantidad,
    double? precioUnitario,
    double? subtotal,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? syncStatus,
    String? localUuid,
  }) {
    return DeudaItemSqliteModel(
      id: id ?? this.id,
      negocioId: negocioId ?? this.negocioId,
      movimientoId: movimientoId ?? this.movimientoId,
      productoId: productoId ?? this.productoId,
      nombreProducto: nombreProducto ?? this.nombreProducto,
      codigoReferencia: codigoReferencia ?? this.codigoReferencia,
      cantidad: cantidad ?? this.cantidad,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      subtotal: subtotal ?? this.subtotal,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      localUuid: localUuid ?? this.localUuid,
    );
  }
}

String newDebtItemLocalUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
  return 'debt-item-${hex.join()}';
}
