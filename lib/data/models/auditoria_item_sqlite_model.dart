class AuditoriaItemSqliteModel {
  static const String estadoPendiente = 'pendiente';
  static const String estadoCorrecto = 'correcto';
  static const String estadoDiferencia = 'diferencia';

  final int? id;
  final int auditoriaId;
  final int productoId;
  final int stockSistema;
  final int? stockFisico;
  final String estadoValidacion;
  final String? observacion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String syncStatus;

  const AuditoriaItemSqliteModel({
    this.id,
    required this.auditoriaId,
    required this.productoId,
    required this.stockSistema,
    this.stockFisico,
    this.estadoValidacion = estadoPendiente,
    this.observacion,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = 'pending',
  });

  factory AuditoriaItemSqliteModel.fromMap(Map<String, Object?> map) {
    return AuditoriaItemSqliteModel(
      id: map['id'] as int?,
      auditoriaId: (map['auditoria_id'] as num).toInt(),
      productoId: (map['producto_id'] as num).toInt(),
      stockSistema: (map['stock_sistema'] as num).toInt(),
      stockFisico: (map['stock_fisico'] as num?)?.toInt(),
      estadoValidacion: map['estado_validacion'] as String? ?? estadoPendiente,
      observacion: map['observacion'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      syncStatus: map['sync_status'] as String? ?? 'pending',
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    return {
      if (includeId) 'id': id,
      'auditoria_id': auditoriaId,
      'producto_id': productoId,
      'stock_sistema': stockSistema,
      'stock_fisico': stockFisico,
      'estado_validacion': estadoValidacion,
      'observacion': observacion,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus,
    };
  }

  AuditoriaItemSqliteModel copyWith({
    int? id,
    int? auditoriaId,
    int? productoId,
    int? stockSistema,
    int? stockFisico,
    String? estadoValidacion,
    String? observacion,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? syncStatus,
  }) {
    return AuditoriaItemSqliteModel(
      id: id ?? this.id,
      auditoriaId: auditoriaId ?? this.auditoriaId,
      productoId: productoId ?? this.productoId,
      stockSistema: stockSistema ?? this.stockSistema,
      stockFisico: stockFisico ?? this.stockFisico,
      estadoValidacion: estadoValidacion ?? this.estadoValidacion,
      observacion: observacion ?? this.observacion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
