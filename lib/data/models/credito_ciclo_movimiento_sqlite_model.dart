class CreditoCicloMovimientoSqliteModel {
  final int? id;
  final int cicloId;
  final int movimientoId;
  final String tipo;
  final double monto;
  final DateTime fecha;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CreditoCicloMovimientoSqliteModel({
    this.id,
    required this.cicloId,
    required this.movimientoId,
    required this.tipo,
    required this.monto,
    required this.fecha,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CreditoCicloMovimientoSqliteModel.fromMap(Map<String, Object?> map) {
    return CreditoCicloMovimientoSqliteModel(
      id: map['id'] as int?,
      cicloId: (map['ciclo_id'] as num).toInt(),
      movimientoId: (map['movimiento_id'] as num).toInt(),
      tipo: map['tipo'] as String,
      monto: (map['monto'] as num).toDouble(),
      fecha: DateTime.parse(map['fecha'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    return {
      if (includeId) 'id': id,
      'ciclo_id': cicloId,
      'movimiento_id': movimientoId,
      'tipo': tipo,
      'monto': monto,
      'fecha': fecha.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
