class Movimiento {
  String nombreCliente;
  final String tipo;
  final double monto;
  final DateTime fecha;

  Movimiento({
    required this.nombreCliente,
    required this.tipo,
    required this.monto,
    required this.fecha,
  });

  Map<String, dynamic> toJson() {
    return {
      'nombreCliente': nombreCliente,
      'tipo': tipo,
      'monto': monto,
      'fecha': fecha.toIso8601String(),
    };
  }

  factory Movimiento.fromJson(Map<String, dynamic> json) {
    return Movimiento(
      nombreCliente: json['nombreCliente'],
      tipo: json['tipo'],
      monto: json['monto'],
      fecha: DateTime.parse(json['fecha']),
    );
  }
}
