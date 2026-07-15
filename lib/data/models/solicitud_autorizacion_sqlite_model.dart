class SolicitudAutorizacionSqliteModel {
  static const String estadoPendiente = 'pendiente';
  static const String estadoAprobado = 'aprobado';
  static const String estadoRechazado = 'rechazado';

  static const String tipoModificarProducto = 'modificar_producto';
  static const String tipoEliminarProducto = 'eliminar_producto';
  static const String tipoAjustarStock = 'ajustar_stock';
  static const String tipoEditarCliente = 'editar_cliente';
  static const String tipoEliminarCliente = 'eliminar_cliente';

  static const String entidadProducto = 'producto';
  static const String entidadCliente = 'cliente';

  final int? id;
  final String? remoteId;
  final int negocioId;
  final int colaboradorId;
  final String tipoSolicitud;
  final String entidad;
  final int? entidadId;
  final String? datosAntes;
  final String datosDespues;
  final String estado;
  final String? comentarioNegocio;
  final int? aprobadoPorUsuarioId;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String syncStatus;

  const SolicitudAutorizacionSqliteModel({
    this.id,
    this.remoteId,
    required this.negocioId,
    required this.colaboradorId,
    required this.tipoSolicitud,
    required this.entidad,
    this.entidadId,
    this.datosAntes,
    required this.datosDespues,
    this.estado = estadoPendiente,
    this.comentarioNegocio,
    this.aprobadoPorUsuarioId,
    this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = 'pending',
  });

  factory SolicitudAutorizacionSqliteModel.fromMap(Map<String, Object?> map) {
    return SolicitudAutorizacionSqliteModel(
      id: map['id'] as int?,
      remoteId: map['remote_id'] as String?,
      negocioId: (map['negocio_id'] as num).toInt(),
      colaboradorId: (map['colaborador_id'] as num).toInt(),
      tipoSolicitud: map['tipo_solicitud'] as String,
      entidad: map['entidad'] as String,
      entidadId: (map['entidad_id'] as num?)?.toInt(),
      datosAntes: map['datos_antes'] as String?,
      datosDespues: map['datos_despues'] as String,
      estado: map['estado'] as String? ?? estadoPendiente,
      comentarioNegocio: map['comentario_negocio'] as String?,
      aprobadoPorUsuarioId: (map['aprobado_por_usuario_id'] as num?)?.toInt(),
      resolvedAt: map['resolved_at'] == null
          ? null
          : DateTime.parse(map['resolved_at'] as String),
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
      'tipo_solicitud': tipoSolicitud,
      'entidad': entidad,
      'entidad_id': entidadId,
      'datos_antes': datosAntes,
      'datos_despues': datosDespues,
      'estado': estado,
      'comentario_negocio': comentarioNegocio,
      'aprobado_por_usuario_id': aprobadoPorUsuarioId,
      'resolved_at': resolvedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus,
    };
  }

  SolicitudAutorizacionSqliteModel copyWith({
    int? id,
    String? remoteId,
    int? negocioId,
    int? colaboradorId,
    String? tipoSolicitud,
    String? entidad,
    int? entidadId,
    String? datosAntes,
    String? datosDespues,
    String? estado,
    String? comentarioNegocio,
    int? aprobadoPorUsuarioId,
    DateTime? resolvedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? syncStatus,
  }) {
    return SolicitudAutorizacionSqliteModel(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      negocioId: negocioId ?? this.negocioId,
      colaboradorId: colaboradorId ?? this.colaboradorId,
      tipoSolicitud: tipoSolicitud ?? this.tipoSolicitud,
      entidad: entidad ?? this.entidad,
      entidadId: entidadId ?? this.entidadId,
      datosAntes: datosAntes ?? this.datosAntes,
      datosDespues: datosDespues ?? this.datosDespues,
      estado: estado ?? this.estado,
      comentarioNegocio: comentarioNegocio ?? this.comentarioNegocio,
      aprobadoPorUsuarioId: aprobadoPorUsuarioId ?? this.aprobadoPorUsuarioId,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
