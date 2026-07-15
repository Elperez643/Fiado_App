class PagoSqliteModel {
  final int? id;
  final String clienteNombre;
  final String? clienteTelefono;
  final double monto;
  final DateTime fecha;
  final int? movimientoId;
  final DateTime createdAt;
  final String syncStatus;
  final String? remoteId;

  const PagoSqliteModel({
    this.id,
    required this.clienteNombre,
    this.clienteTelefono,
    required this.monto,
    required this.fecha,
    this.movimientoId,
    required this.createdAt,
    this.syncStatus = 'pending',
    this.remoteId,
  });

  factory PagoSqliteModel.fromMap(Map<String, Object?> map) {
    return PagoSqliteModel(
      id: map['id'] as int?,
      clienteNombre: map['cliente_nombre'] as String,
      clienteTelefono: map['cliente_telefono'] as String?,
      monto: (map['monto'] as num).toDouble(),
      fecha: DateTime.parse(map['fecha'] as String),
      movimientoId: map['movimiento_id'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      syncStatus: map['sync_status'] as String? ?? 'pending',
      remoteId: map['remote_id'] as String?,
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    return {
      if (includeId) 'id': id,
      'cliente_nombre': clienteNombre,
      'cliente_telefono': clienteTelefono,
      'monto': monto,
      'fecha': fecha.toIso8601String(),
      'movimiento_id': movimientoId,
      'created_at': createdAt.toIso8601String(),
      'sync_status': syncStatus,
      'remote_id': remoteId,
    };
  }
}
