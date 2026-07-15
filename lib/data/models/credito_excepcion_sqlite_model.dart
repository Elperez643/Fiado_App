class CreditoExcepcionSqliteModel {
  final int? id;
  final String? remoteId;
  final int cicloId;
  final int negocioId;
  final int clienteId;
  final int usuarioId;
  final String? motivo;
  final double montoFiado;
  final int? movimientoId;
  final DateTime fecha;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastSyncedAt;
  final String syncStatus;

  const CreditoExcepcionSqliteModel({
    this.id,
    this.remoteId,
    required this.cicloId,
    required this.negocioId,
    required this.clienteId,
    required this.usuarioId,
    this.motivo,
    required this.montoFiado,
    this.movimientoId,
    required this.fecha,
    required this.createdAt,
    required this.updatedAt,
    this.lastSyncedAt,
    this.syncStatus = 'pending',
  });

  factory CreditoExcepcionSqliteModel.fromMap(Map<String, Object?> map) {
    return CreditoExcepcionSqliteModel(
      id: map['id'] as int?,
      remoteId: map['remote_id'] as String?,
      cicloId: (map['ciclo_id'] as num).toInt(),
      negocioId: (map['negocio_id'] as num).toInt(),
      clienteId: (map['cliente_id'] as num).toInt(),
      usuarioId: (map['usuario_id'] as num).toInt(),
      motivo: map['motivo'] as String?,
      montoFiado: (map['monto_fiado'] as num).toDouble(),
      movimientoId: (map['movimiento_id'] as num?)?.toInt(),
      fecha: DateTime.parse(map['fecha'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      lastSyncedAt: map['last_synced_at'] == null
          ? null
          : DateTime.parse(map['last_synced_at'] as String),
      syncStatus: map['sync_status'] as String? ?? 'pending',
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    return {
      if (includeId) 'id': id,
      'remote_id': remoteId,
      'ciclo_id': cicloId,
      'negocio_id': negocioId,
      'cliente_id': clienteId,
      'usuario_id': usuarioId,
      'motivo': motivo,
      'monto_fiado': montoFiado,
      'movimiento_id': movimientoId,
      'fecha': fecha.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_synced_at': lastSyncedAt?.toIso8601String(),
      'sync_status': syncStatus,
    };
  }
}
