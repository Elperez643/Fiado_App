class Producto {
  static const String medidaUnidad = 'unidad';
  static const String medidaPeso = 'peso';
  static const String demandaBaja = 'baja';
  static const String demandaMedia = 'media';
  static const String demandaAlta = 'alta';

  final String id;
  final String nombre;
  final String ubicacion;
  final int cantidad;
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
    required this.ubicacion,
    required this.cantidad,
    this.tipoMedida = medidaUnidad,
    this.nivelDemanda = demandaMedia,
    required this.esClave,
    this.ultimaVerificacion,
    this.disponibilidadConfirmada = false,
    this.disponibilidadCorregida = false,
    this.requiereVerificacionAdministrador = false,
    this.rotacionSemanaAnterior = 0,
  });

  Producto copyWith({
    String? id,
    String? nombre,
    String? ubicacion,
    int? cantidad,
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
      ubicacion: ubicacion ?? this.ubicacion,
      cantidad: cantidad ?? this.cantidad,
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
      'ubicacion': ubicacion,
      'cantidad': cantidad,
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
      ubicacion: json['ubicacion'] as String? ?? 'Sin ubicacion',
      cantidad: json['cantidad'] as int,
      tipoMedida: json['tipoMedida'] as String? ?? medidaUnidad,
      nivelDemanda: json['nivelDemanda'] as String? ??
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
