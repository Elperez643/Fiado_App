class ComprobanteSqliteModel {
  static const String tipoDeuda = 'deuda';
  static const String tipoPago = 'pago';

  final int? id;
  final int? negocioId;
  final String? remoteId;
  final String tipo;
  final int movimientoId;
  final String clienteNombre;
  final String? clienteTelefono;
  final String? negocioNombre;
  final String codigoComprobante;
  final DateTime fecha;
  final double subtotal;
  final double total;
  final double? saldoAnterior;
  final double? saldoNuevo;
  final int? creadoPorUsuarioId;
  final String payloadJson;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String syncStatus;

  const ComprobanteSqliteModel({
    this.id,
    this.negocioId,
    this.remoteId,
    required this.tipo,
    required this.movimientoId,
    required this.clienteNombre,
    this.clienteTelefono,
    this.negocioNombre,
    required this.codigoComprobante,
    required this.fecha,
    this.subtotal = 0,
    required this.total,
    this.saldoAnterior,
    this.saldoNuevo,
    this.creadoPorUsuarioId,
    required this.payloadJson,
    this.createdAt,
    this.updatedAt,
    this.syncStatus = 'pending',
  });

  factory ComprobanteSqliteModel.fromMap(Map<String, Object?> map) {
    return ComprobanteSqliteModel(
      id: map['id'] as int?,
      negocioId: (map['negocio_id'] as num?)?.toInt(),
      remoteId: map['remote_id'] as String?,
      tipo: map['tipo'] as String,
      movimientoId: (map['movimiento_id'] as num).toInt(),
      clienteNombre: map['cliente_nombre'] as String,
      clienteTelefono: map['cliente_telefono'] as String?,
      negocioNombre: map['negocio_nombre'] as String?,
      codigoComprobante: map['codigo_comprobante'] as String,
      fecha: DateTime.parse(map['fecha'] as String),
      subtotal: (map['subtotal'] as num? ?? 0).toDouble(),
      total: (map['total'] as num).toDouble(),
      saldoAnterior: (map['saldo_anterior'] as num?)?.toDouble(),
      saldoNuevo: (map['saldo_nuevo'] as num?)?.toDouble(),
      creadoPorUsuarioId: (map['creado_por_usuario_id'] as num?)?.toInt(),
      payloadJson: map['payload_json'] as String,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] == null
          ? null
          : DateTime.parse(map['updated_at'] as String),
      syncStatus: map['sync_status'] as String? ?? 'pending',
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    return {
      if (includeId) 'id': id,
      'negocio_id': negocioId,
      'remote_id': remoteId,
      'tipo': tipo,
      'movimiento_id': movimientoId,
      'cliente_nombre': clienteNombre,
      'cliente_telefono': clienteTelefono,
      'negocio_nombre': negocioNombre,
      'codigo_comprobante': codigoComprobante,
      'fecha': fecha.toIso8601String(),
      'subtotal': subtotal,
      'total': total,
      'saldo_anterior': saldoAnterior,
      'saldo_nuevo': saldoNuevo,
      'creado_por_usuario_id': creadoPorUsuarioId,
      'payload_json': payloadJson,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'sync_status': syncStatus,
    };
  }

  ComprobanteSqliteModel copyWith({
    int? id,
    int? negocioId,
    String? remoteId,
    String? tipo,
    int? movimientoId,
    String? clienteNombre,
    String? clienteTelefono,
    String? negocioNombre,
    String? codigoComprobante,
    DateTime? fecha,
    double? subtotal,
    double? total,
    double? saldoAnterior,
    double? saldoNuevo,
    int? creadoPorUsuarioId,
    String? payloadJson,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? syncStatus,
  }) {
    return ComprobanteSqliteModel(
      id: id ?? this.id,
      negocioId: negocioId ?? this.negocioId,
      remoteId: remoteId ?? this.remoteId,
      tipo: tipo ?? this.tipo,
      movimientoId: movimientoId ?? this.movimientoId,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      clienteTelefono: clienteTelefono ?? this.clienteTelefono,
      negocioNombre: negocioNombre ?? this.negocioNombre,
      codigoComprobante: codigoComprobante ?? this.codigoComprobante,
      fecha: fecha ?? this.fecha,
      subtotal: subtotal ?? this.subtotal,
      total: total ?? this.total,
      saldoAnterior: saldoAnterior ?? this.saldoAnterior,
      saldoNuevo: saldoNuevo ?? this.saldoNuevo,
      creadoPorUsuarioId: creadoPorUsuarioId ?? this.creadoPorUsuarioId,
      payloadJson: payloadJson ?? this.payloadJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
