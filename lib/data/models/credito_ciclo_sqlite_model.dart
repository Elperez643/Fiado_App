class CreditoCicloEstado {
  static const activo = 'activo';
  static const vencido30 = 'vencido_30';
  static const mora45 = 'mora_45';
  static const bloqueado60 = 'bloqueado_60';
  static const saldado = 'saldado';

  static const pendientes = [activo, vencido30, mora45, bloqueado60];
}

class CreditoCicloSqliteModel {
  final int? id;
  final String? remoteId;
  final int negocioId;
  final int clienteId;
  final DateTime fechaInicio;
  final DateTime fechaLimite30;
  final DateTime fechaLimite45;
  final DateTime fechaBloqueo60;
  final String estado;
  final double montoTotal;
  final double montoPagado;
  final double saldoPendiente;
  final bool bloqueado;
  final DateTime? fechaSaldado;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String syncStatus;
  final String? clienteNombre;
  final String? clienteTelefono;
  final String? negocioNombre;

  const CreditoCicloSqliteModel({
    this.id,
    this.remoteId,
    required this.negocioId,
    required this.clienteId,
    required this.fechaInicio,
    required this.fechaLimite30,
    required this.fechaLimite45,
    required this.fechaBloqueo60,
    this.estado = CreditoCicloEstado.activo,
    this.montoTotal = 0,
    this.montoPagado = 0,
    this.saldoPendiente = 0,
    this.bloqueado = false,
    this.fechaSaldado,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = 'pending',
    this.clienteNombre,
    this.clienteTelefono,
    this.negocioNombre,
  });

  factory CreditoCicloSqliteModel.nuevo({
    required int negocioId,
    required int clienteId,
    required DateTime fechaInicio,
  }) {
    final now = DateTime.now();
    return CreditoCicloSqliteModel(
      negocioId: negocioId,
      clienteId: clienteId,
      fechaInicio: fechaInicio,
      fechaLimite30: fechaInicio.add(const Duration(days: 30)),
      fechaLimite45: fechaInicio.add(const Duration(days: 45)),
      fechaBloqueo60: fechaInicio.add(const Duration(days: 60)),
      createdAt: now,
      updatedAt: now,
    );
  }

  factory CreditoCicloSqliteModel.fromMap(Map<String, Object?> map) {
    return CreditoCicloSqliteModel(
      id: map['id'] as int?,
      remoteId: map['remote_id'] as String?,
      negocioId: (map['negocio_id'] as num).toInt(),
      clienteId: (map['cliente_id'] as num).toInt(),
      fechaInicio: DateTime.parse(map['fecha_inicio'] as String),
      fechaLimite30: DateTime.parse(map['fecha_limite_30'] as String),
      fechaLimite45: DateTime.parse(map['fecha_limite_45'] as String),
      fechaBloqueo60: DateTime.parse(map['fecha_bloqueo_60'] as String),
      estado: map['estado'] as String? ?? CreditoCicloEstado.activo,
      montoTotal: (map['monto_total'] as num? ?? 0).toDouble(),
      montoPagado: (map['monto_pagado'] as num? ?? 0).toDouble(),
      saldoPendiente: (map['saldo_pendiente'] as num? ?? 0).toDouble(),
      bloqueado: ((map['bloqueado'] as num?)?.toInt() ?? 0) == 1,
      fechaSaldado: map['fecha_saldado'] == null
          ? null
          : DateTime.parse(map['fecha_saldado'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      syncStatus: map['sync_status'] as String? ?? 'pending',
      clienteNombre: map['cliente_nombre'] as String?,
      clienteTelefono: map['cliente_telefono'] as String?,
      negocioNombre: map['negocio_nombre'] as String?,
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    return {
      if (includeId) 'id': id,
      'remote_id': remoteId,
      'negocio_id': negocioId,
      'cliente_id': clienteId,
      'fecha_inicio': fechaInicio.toIso8601String(),
      'fecha_limite_30': fechaLimite30.toIso8601String(),
      'fecha_limite_45': fechaLimite45.toIso8601String(),
      'fecha_bloqueo_60': fechaBloqueo60.toIso8601String(),
      'estado': estado,
      'monto_total': montoTotal,
      'monto_pagado': montoPagado,
      'saldo_pendiente': saldoPendiente,
      'bloqueado': bloqueado ? 1 : 0,
      'fecha_saldado': fechaSaldado?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus,
    };
  }
}
