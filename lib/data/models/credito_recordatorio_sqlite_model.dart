class CreditoRecordatorioTipo {
  static const aviso30 = 'aviso_30';
  static const aviso45 = 'aviso_45';
  static const bloqueo60 = 'bloqueo_60';
  static const toqueManual = 'toque_manual';
}

class CreditoRecordatorioCanal {
  static const interno = 'interno';
  static const whatsapp = 'whatsapp';
}

class CreditoRecordatorioSqliteModel {
  final int? id;
  final String? remoteId;
  final int cicloId;
  final int negocioId;
  final int clienteId;
  final String tipo;
  final String mensaje;
  final String canal;
  final String estado;
  final DateTime fechaGenerado;
  final DateTime? fechaEnviado;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastSyncedAt;
  final String syncStatus;
  final String? clienteNombre;
  final String? clienteTelefono;
  final String? negocioNombre;
  final double? saldoPendiente;
  final DateTime? fechaLimite;

  const CreditoRecordatorioSqliteModel({
    this.id,
    this.remoteId,
    required this.cicloId,
    required this.negocioId,
    required this.clienteId,
    required this.tipo,
    required this.mensaje,
    required this.canal,
    this.estado = 'pendiente',
    required this.fechaGenerado,
    this.fechaEnviado,
    required this.createdAt,
    required this.updatedAt,
    this.lastSyncedAt,
    this.syncStatus = 'pending',
    this.clienteNombre,
    this.clienteTelefono,
    this.negocioNombre,
    this.saldoPendiente,
    this.fechaLimite,
  });

  factory CreditoRecordatorioSqliteModel.fromMap(Map<String, Object?> map) {
    return CreditoRecordatorioSqliteModel(
      id: map['id'] as int?,
      remoteId: map['remote_id'] as String?,
      cicloId: (map['ciclo_id'] as num).toInt(),
      negocioId: (map['negocio_id'] as num).toInt(),
      clienteId: (map['cliente_id'] as num).toInt(),
      tipo: map['tipo'] as String,
      mensaje: map['mensaje'] as String,
      canal: map['canal'] as String,
      estado: map['estado'] as String? ?? 'pendiente',
      fechaGenerado: DateTime.parse(map['fecha_generado'] as String),
      fechaEnviado: map['fecha_enviado'] == null
          ? null
          : DateTime.parse(map['fecha_enviado'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      lastSyncedAt: map['last_synced_at'] == null
          ? null
          : DateTime.parse(map['last_synced_at'] as String),
      syncStatus: map['sync_status'] as String? ?? 'pending',
      clienteNombre: map['cliente_nombre'] as String?,
      clienteTelefono: map['cliente_telefono'] as String?,
      negocioNombre: map['negocio_nombre'] as String?,
      saldoPendiente: (map['saldo_pendiente'] as num?)?.toDouble(),
      fechaLimite: map['fecha_limite_30'] == null
          ? null
          : DateTime.parse(map['fecha_limite_30'] as String),
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    return {
      if (includeId) 'id': id,
      'remote_id': remoteId,
      'ciclo_id': cicloId,
      'negocio_id': negocioId,
      'cliente_id': clienteId,
      'tipo': tipo,
      'mensaje': mensaje,
      'canal': canal,
      'estado': estado,
      'fecha_generado': fechaGenerado.toIso8601String(),
      'fecha_enviado': fechaEnviado?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_synced_at': lastSyncedAt?.toIso8601String(),
      'sync_status': syncStatus,
    };
  }
}
