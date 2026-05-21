class MovementEntity {
  final String id;
  final String clientId;
  final String nombreCliente;
  final String tipo;
  final double monto;
  final DateTime fecha;
  final DateTime? updatedAt;
  final bool pendingSync;

  const MovementEntity({
    required this.id,
    required this.clientId,
    required this.nombreCliente,
    required this.tipo,
    required this.monto,
    required this.fecha,
    this.updatedAt,
    this.pendingSync = false,
  });
}
