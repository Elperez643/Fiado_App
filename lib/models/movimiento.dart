class Movimiento {
  final int? id;
  final int? clienteId;
  String nombreCliente;
  final String? clienteTelefono;
  final String? clienteNombreSnapshot;
  final String? clienteTelefonoSnapshot;
  final String tipo;
  final double monto;
  final DateTime fecha;
  final String? concepto;

  Movimiento({
    this.id,
    this.clienteId,
    required this.nombreCliente,
    this.clienteTelefono,
    this.clienteNombreSnapshot,
    this.clienteTelefonoSnapshot,
    required this.tipo,
    required this.monto,
    required this.fecha,
    this.concepto,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clienteId': clienteId,
      'nombreCliente': nombreCliente,
      'clienteTelefono': clienteTelefono,
      'clienteNombreSnapshot': clienteNombreSnapshot,
      'clienteTelefonoSnapshot': clienteTelefonoSnapshot,
      'tipo': tipo,
      'monto': monto,
      'fecha': fecha.toIso8601String(),
      'concepto': concepto,
    };
  }

  factory Movimiento.fromJson(Map<String, dynamic> json) {
    return Movimiento(
      id: (json['id'] as num?)?.toInt(),
      clienteId: (json['clienteId'] as num?)?.toInt(),
      nombreCliente: json['nombreCliente'],
      clienteTelefono: json['clienteTelefono'] as String?,
      clienteNombreSnapshot: json['clienteNombreSnapshot'] as String?,
      clienteTelefonoSnapshot: json['clienteTelefonoSnapshot'] as String?,
      tipo: json['tipo'],
      monto: (json['monto'] as num).toDouble(),
      fecha: DateTime.parse(json['fecha']),
      concepto: json['concepto'] as String?,
    );
  }
}
