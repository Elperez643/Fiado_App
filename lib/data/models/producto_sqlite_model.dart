import '../../models/producto.dart';

class ProductoSqliteModel {
  final int? id;
  final int? negocioId;
  final String? remoteId;
  final String nombre;
  final String? categoria;
  final String? descripcion;
  final int cantidad;
  final double costoUnitario;
  final double precioCompra;
  final double precioVenta;
  final double porcentajeGanancia;
  final int stockMinimo;
  final String? codigoReferencia;
  final bool activo;
  final String syncStatus;
  final int syncVersion;
  final DateTime? deletedAt;
  final DateTime? lastSyncedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String legacyId;
  final String ubicacion;
  final String tipoMedida;
  final String nivelDemanda;
  final bool esClave;
  final DateTime? ultimaVerificacion;
  final bool disponibilidadConfirmada;
  final bool disponibilidadCorregida;
  final bool requiereVerificacionAdministrador;
  final int rotacionSemanaAnterior;

  const ProductoSqliteModel({
    this.id,
    this.negocioId,
    this.remoteId,
    required this.nombre,
    this.categoria,
    this.descripcion,
    required this.cantidad,
    double? costoUnitario,
    this.precioCompra = 0,
    this.precioVenta = 0,
    this.porcentajeGanancia = 0,
    this.stockMinimo = 0,
    this.codigoReferencia,
    this.activo = true,
    this.syncStatus = 'pending',
    this.syncVersion = 0,
    this.deletedAt,
    this.lastSyncedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.legacyId,
    required this.ubicacion,
    required this.tipoMedida,
    required this.nivelDemanda,
    required this.esClave,
    this.ultimaVerificacion,
    required this.disponibilidadConfirmada,
    required this.disponibilidadCorregida,
    required this.requiereVerificacionAdministrador,
    required this.rotacionSemanaAnterior,
  }) : costoUnitario = costoUnitario ?? precioCompra;

  factory ProductoSqliteModel.fromLegacy(Producto producto, {int? negocioId}) {
    final now = DateTime.now();
    return ProductoSqliteModel(
      negocioId: negocioId,
      nombre: producto.nombre,
      categoria: producto.categoria ?? producto.ubicacion,
      descripcion: producto.descripcion,
      cantidad: producto.cantidad,
      costoUnitario: producto.costoUnitario,
      precioCompra: producto.costoUnitario,
      precioVenta: producto.precioVenta,
      porcentajeGanancia: producto.porcentajeGanancia,
      stockMinimo: producto.stockMinimo == 0
          ? (producto.esClave ? 10 : 5)
          : producto.stockMinimo,
      codigoReferencia: producto.codigoReferencia?.trim().isEmpty ?? true
          ? null
          : producto.codigoReferencia!.trim(),
      createdAt: now,
      updatedAt: now,
      legacyId: producto.id,
      ubicacion: producto.ubicacion,
      tipoMedida: producto.tipoMedida,
      nivelDemanda: producto.nivelDemanda,
      esClave: producto.esClave,
      ultimaVerificacion: producto.ultimaVerificacion,
      disponibilidadConfirmada: producto.disponibilidadConfirmada,
      disponibilidadCorregida: producto.disponibilidadCorregida,
      requiereVerificacionAdministrador:
          producto.requiereVerificacionAdministrador,
      rotacionSemanaAnterior: producto.rotacionSemanaAnterior,
    );
  }

  factory ProductoSqliteModel.fromMap(Map<String, Object?> map) {
    return ProductoSqliteModel(
      id: map['id'] as int?,
      negocioId: (map['negocio_id'] as num?)?.toInt(),
      remoteId: map['remote_id'] as String?,
      nombre: map['nombre'] as String,
      categoria: map['categoria'] as String?,
      descripcion: map['descripcion'] as String?,
      cantidad: (map['cantidad'] as num).toInt(),
      costoUnitario:
          (map['costo_unitario'] as num?)?.toDouble() ??
          (map['precio_compra'] as num?)?.toDouble() ??
          0,
      precioCompra:
          (map['precio_compra'] as num?)?.toDouble() ??
          (map['costo_unitario'] as num?)?.toDouble() ??
          0,
      precioVenta: (map['precio_venta'] as num?)?.toDouble() ?? 0,
      porcentajeGanancia: (map['porcentaje_ganancia'] as num?)?.toDouble() ?? 0,
      stockMinimo: (map['stock_minimo'] as num?)?.toInt() ?? 0,
      codigoReferencia: map['codigo_referencia'] as String?,
      activo: (map['activo'] as num? ?? 1).toInt() == 1,
      syncStatus: map['sync_status'] as String? ?? 'pending',
      syncVersion: (map['sync_version'] as num? ?? 0).toInt(),
      deletedAt: map['deleted_at'] == null
          ? null
          : DateTime.parse(map['deleted_at'] as String),
      lastSyncedAt: map['last_synced_at'] == null
          ? null
          : DateTime.parse(map['last_synced_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      legacyId: map['legacy_id'] as String? ?? (map['id'] as int).toString(),
      ubicacion: map['ubicacion'] as String? ?? 'Sin ubicacion',
      tipoMedida: map['tipo_medida'] as String? ?? Producto.medidaUnidad,
      nivelDemanda: map['nivel_demanda'] as String? ?? Producto.demandaMedia,
      esClave: (map['es_clave'] as num? ?? 0).toInt() == 1,
      ultimaVerificacion: map['ultima_verificacion'] == null
          ? null
          : DateTime.parse(map['ultima_verificacion'] as String),
      disponibilidadConfirmada:
          (map['disponibilidad_confirmada'] as num? ?? 0).toInt() == 1,
      disponibilidadCorregida:
          (map['disponibilidad_corregida'] as num? ?? 0).toInt() == 1,
      requiereVerificacionAdministrador:
          (map['requiere_verificacion_administrador'] as num? ?? 0).toInt() ==
          1,
      rotacionSemanaAnterior: (map['rotacion_semana_anterior'] as num? ?? 0)
          .toInt(),
    );
  }

  ProductoSqliteModel copyWith({
    int? id,
    int? negocioId,
    String? remoteId,
    String? nombre,
    String? categoria,
    String? descripcion,
    int? cantidad,
    double? costoUnitario,
    double? precioCompra,
    double? precioVenta,
    double? porcentajeGanancia,
    int? stockMinimo,
    String? codigoReferencia,
    bool? activo,
    String? syncStatus,
    int? syncVersion,
    DateTime? deletedAt,
    DateTime? lastSyncedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? legacyId,
    String? ubicacion,
    String? tipoMedida,
    String? nivelDemanda,
    bool? esClave,
    DateTime? ultimaVerificacion,
    bool? disponibilidadConfirmada,
    bool? disponibilidadCorregida,
    bool? requiereVerificacionAdministrador,
    int? rotacionSemanaAnterior,
  }) {
    return ProductoSqliteModel(
      id: id ?? this.id,
      negocioId: negocioId ?? this.negocioId,
      remoteId: remoteId ?? this.remoteId,
      nombre: nombre ?? this.nombre,
      categoria: categoria ?? this.categoria,
      descripcion: descripcion ?? this.descripcion,
      cantidad: cantidad ?? this.cantidad,
      costoUnitario: costoUnitario ?? precioCompra ?? this.costoUnitario,
      precioCompra: precioCompra ?? costoUnitario ?? this.precioCompra,
      precioVenta: precioVenta ?? this.precioVenta,
      porcentajeGanancia: porcentajeGanancia ?? this.porcentajeGanancia,
      stockMinimo: stockMinimo ?? this.stockMinimo,
      codigoReferencia: codigoReferencia ?? this.codigoReferencia,
      activo: activo ?? this.activo,
      syncStatus: syncStatus ?? this.syncStatus,
      syncVersion: syncVersion ?? this.syncVersion,
      deletedAt: deletedAt ?? this.deletedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      legacyId: legacyId ?? this.legacyId,
      ubicacion: ubicacion ?? this.ubicacion,
      tipoMedida: tipoMedida ?? this.tipoMedida,
      nivelDemanda: nivelDemanda ?? this.nivelDemanda,
      esClave: esClave ?? this.esClave,
      ultimaVerificacion: ultimaVerificacion ?? this.ultimaVerificacion,
      disponibilidadConfirmada:
          disponibilidadConfirmada ?? this.disponibilidadConfirmada,
      disponibilidadCorregida:
          disponibilidadCorregida ?? this.disponibilidadCorregida,
      requiereVerificacionAdministrador:
          requiereVerificacionAdministrador ??
          this.requiereVerificacionAdministrador,
      rotacionSemanaAnterior:
          rotacionSemanaAnterior ?? this.rotacionSemanaAnterior,
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    return {
      if (includeId) 'id': id,
      'negocio_id': negocioId,
      'remote_id': remoteId,
      'nombre': nombre,
      'categoria': categoria,
      'descripcion': descripcion,
      'cantidad': cantidad,
      'costo_unitario': costoUnitario,
      'precio_compra': precioCompra,
      'precio_venta': precioVenta,
      'porcentaje_ganancia': porcentajeGanancia,
      'stock_minimo': stockMinimo,
      'codigo_referencia': codigoReferencia,
      'activo': activo ? 1 : 0,
      'deleted_at': deletedAt?.toIso8601String(),
      'last_synced_at': lastSyncedAt?.toIso8601String(),
      'sync_status': syncStatus,
      'sync_version': syncVersion,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'legacy_id': legacyId,
      'ubicacion': ubicacion,
      'tipo_medida': tipoMedida,
      'nivel_demanda': nivelDemanda,
      'es_clave': esClave ? 1 : 0,
      'ultima_verificacion': ultimaVerificacion?.toIso8601String(),
      'disponibilidad_confirmada': disponibilidadConfirmada ? 1 : 0,
      'disponibilidad_corregida': disponibilidadCorregida ? 1 : 0,
      'requiere_verificacion_administrador': requiereVerificacionAdministrador
          ? 1
          : 0,
      'rotacion_semana_anterior': rotacionSemanaAnterior,
    };
  }

  Producto toLegacyModel() {
    return Producto(
      id: legacyId,
      nombre: nombre,
      codigoReferencia: codigoReferencia,
      categoria: categoria,
      descripcion: descripcion,
      ubicacion: ubicacion,
      cantidad: cantidad,
      costoUnitario: costoUnitario,
      precioCompra: costoUnitario,
      precioVenta: precioVenta,
      porcentajeGanancia: porcentajeGanancia,
      stockMinimo: stockMinimo,
      tipoMedida: tipoMedida,
      nivelDemanda: nivelDemanda,
      esClave: esClave,
      ultimaVerificacion: ultimaVerificacion,
      disponibilidadConfirmada: disponibilidadConfirmada,
      disponibilidadCorregida: disponibilidadCorregida,
      requiereVerificacionAdministrador: requiereVerificacionAdministrador,
      rotacionSemanaAnterior: rotacionSemanaAnterior,
    );
  }
}
