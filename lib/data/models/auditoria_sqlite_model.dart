class AuditoriaSqliteModel {
  static const String tipoDiaria = 'diaria';
  static const String tipoSemanal = 'semanal';
  static const String estadoPendiente = 'pendiente';
  static const String estadoEnProceso = 'en_proceso';
  static const String estadoFinalizada = 'finalizada';

  final int? id;
  final String? remoteId;
  final int negocioId;
  final int? colaboradorId;
  final String tipo;
  final DateTime fecha;
  final String estado;
  final int totalProductos;
  final int productosValidados;
  final String? observaciones;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String syncStatus;

  const AuditoriaSqliteModel({
    this.id,
    this.remoteId,
    required this.negocioId,
    this.colaboradorId,
    required this.tipo,
    required this.fecha,
    this.estado = estadoPendiente,
    this.totalProductos = 0,
    this.productosValidados = 0,
    this.observaciones,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = 'pending',
  });

  factory AuditoriaSqliteModel.fromMap(Map<String, Object?> map) {
    return AuditoriaSqliteModel(
      id: map['id'] as int?,
      remoteId: map['remote_id'] as String?,
      negocioId: (map['negocio_id'] as num).toInt(),
      colaboradorId: (map['colaborador_id'] as num?)?.toInt(),
      tipo: map['tipo'] as String,
      fecha: DateTime.parse(map['fecha'] as String),
      estado: map['estado'] as String? ?? estadoPendiente,
      totalProductos: (map['total_productos'] as num? ?? 0).toInt(),
      productosValidados: (map['productos_validados'] as num? ?? 0).toInt(),
      observaciones: map['observaciones'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      syncStatus: map['sync_status'] as String? ?? 'pending',
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    return {
      if (includeId) 'id': id,
      'remote_id': remoteId,
      'negocio_id': negocioId,
      'colaborador_id': colaboradorId,
      'tipo': tipo,
      'fecha': fecha.toIso8601String(),
      'estado': estado,
      'total_productos': totalProductos,
      'productos_validados': productosValidados,
      'observaciones': observaciones,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus,
    };
  }

  AuditoriaSqliteModel copyWith({
    int? id,
    String? remoteId,
    int? negocioId,
    int? colaboradorId,
    String? tipo,
    DateTime? fecha,
    String? estado,
    int? totalProductos,
    int? productosValidados,
    String? observaciones,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? syncStatus,
  }) {
    return AuditoriaSqliteModel(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      negocioId: negocioId ?? this.negocioId,
      colaboradorId: colaboradorId ?? this.colaboradorId,
      tipo: tipo ?? this.tipo,
      fecha: fecha ?? this.fecha,
      estado: estado ?? this.estado,
      totalProductos: totalProductos ?? this.totalProductos,
      productosValidados: productosValidados ?? this.productosValidados,
      observaciones: observaciones ?? this.observaciones,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
