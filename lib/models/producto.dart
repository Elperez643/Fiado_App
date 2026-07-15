class Producto {
  static const String medidaUnidad = 'unidad';
  static const String medidaPeso = 'peso';
  static const String demandaBaja = 'baja';
  static const String demandaMedia = 'media';
  static const String demandaAlta = 'alta';

  final String id;
  final String nombre;
  final String? codigoReferencia;
  final String? categoria;
  final String? descripcion;
  final String ubicacion;
  final int cantidad;
  final double costoUnitario;
  final double precioCompra;
  final double precioVenta;
  final double porcentajeGanancia;
  final int stockMinimo;
  final String tipoMedida;
  final String nivelDemanda;
  final bool esClave;
  final DateTime? ultimaVerificacion;
  final bool disponibilidadConfirmada;
  final bool disponibilidadCorregida;
  final bool requiereVerificacionAdministrador;
  final int rotacionSemanaAnterior;

  const Producto({
    required this.id,
    required this.nombre,
    this.codigoReferencia,
    this.categoria,
    this.descripcion,
    required this.ubicacion,
    required this.cantidad,
    double? costoUnitario,
    this.precioCompra = 0,
    this.precioVenta = 0,
    this.porcentajeGanancia = 0,
    this.stockMinimo = 0,
    this.tipoMedida = medidaUnidad,
    this.nivelDemanda = demandaMedia,
    required this.esClave,
    this.ultimaVerificacion,
    this.disponibilidadConfirmada = false,
    this.disponibilidadCorregida = false,
    this.requiereVerificacionAdministrador = false,
    this.rotacionSemanaAnterior = 0,
  }) : costoUnitario = costoUnitario ?? precioCompra;

  Producto copyWith({
    String? id,
    String? nombre,
    String? codigoReferencia,
    String? categoria,
    String? descripcion,
    String? ubicacion,
    int? cantidad,
    double? costoUnitario,
    double? precioCompra,
    double? precioVenta,
    double? porcentajeGanancia,
    int? stockMinimo,
    String? tipoMedida,
    String? nivelDemanda,
    bool? esClave,
    DateTime? ultimaVerificacion,
    bool? disponibilidadConfirmada,
    bool? disponibilidadCorregida,
    bool? requiereVerificacionAdministrador,
    int? rotacionSemanaAnterior,
  }) {
    return Producto(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      codigoReferencia: codigoReferencia ?? this.codigoReferencia,
      categoria: categoria ?? this.categoria,
      descripcion: descripcion ?? this.descripcion,
      ubicacion: ubicacion ?? this.ubicacion,
      cantidad: cantidad ?? this.cantidad,
      costoUnitario: costoUnitario ?? precioCompra ?? this.costoUnitario,
      precioCompra: precioCompra ?? costoUnitario ?? this.precioCompra,
      precioVenta: precioVenta ?? this.precioVenta,
      porcentajeGanancia: porcentajeGanancia ?? this.porcentajeGanancia,
      stockMinimo: stockMinimo ?? this.stockMinimo,
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'codigoReferencia': codigoReferencia,
      'categoria': categoria,
      'descripcion': descripcion,
      'ubicacion': ubicacion,
      'cantidad': cantidad,
      'costoUnitario': costoUnitario,
      'precioCompra': precioCompra,
      'precioVenta': precioVenta,
      'porcentajeGanancia': porcentajeGanancia,
      'stockMinimo': stockMinimo,
      'tipoMedida': tipoMedida,
      'nivelDemanda': nivelDemanda,
      'esClave': esClave,
      'ultimaVerificacion': ultimaVerificacion?.toIso8601String(),
      'disponibilidadConfirmada': disponibilidadConfirmada,
      'disponibilidadCorregida': disponibilidadCorregida,
      'requiereVerificacionAdministrador': requiereVerificacionAdministrador,
      'rotacionSemanaAnterior': rotacionSemanaAnterior,
    };
  }

  factory Producto.fromJson(Map<String, dynamic> json) {
    return Producto(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      codigoReferencia: json['codigoReferencia'] as String?,
      categoria: json['categoria'] as String?,
      descripcion: json['descripcion'] as String?,
      ubicacion: json['ubicacion'] as String? ?? 'Sin ubicacion',
      cantidad: json['cantidad'] as int,
      costoUnitario: (json['costoUnitario'] as num?)?.toDouble(),
      precioCompra: (json['precioCompra'] as num?)?.toDouble() ?? 0,
      precioVenta: (json['precioVenta'] as num?)?.toDouble() ?? 0,
      porcentajeGanancia: (json['porcentajeGanancia'] as num?)?.toDouble() ?? 0,
      stockMinimo: (json['stockMinimo'] as num?)?.toInt() ?? 0,
      tipoMedida: json['tipoMedida'] as String? ?? medidaUnidad,
      nivelDemanda:
          json['nivelDemanda'] as String? ??
          demandaDesdeRotacion(json['rotacionSemanaAnterior'] as int? ?? 0),
      esClave: json['esClave'] as bool,
      ultimaVerificacion: json['ultimaVerificacion'] != null
          ? DateTime.parse(json['ultimaVerificacion'] as String)
          : null,
      disponibilidadConfirmada:
          json['disponibilidadConfirmada'] as bool? ?? false,
      disponibilidadCorregida:
          json['disponibilidadCorregida'] as bool? ?? false,
      requiereVerificacionAdministrador:
          json['requiereVerificacionAdministrador'] as bool? ?? false,
      rotacionSemanaAnterior: json['rotacionSemanaAnterior'] as int? ?? 0,
    );
  }

  static String demandaDesdeRotacion(int rotacionSemanaAnterior) {
    if (rotacionSemanaAnterior >= 80) {
      return demandaAlta;
    }

    if (rotacionSemanaAnterior >= 50) {
      return demandaMedia;
    }

    return demandaBaja;
  }
}
