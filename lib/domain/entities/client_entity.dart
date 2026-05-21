class ClientEntity {
  final String id;
  final String nombre;
  final String telefono;
  final double deuda;
  final DateTime? updatedAt;
  final bool pendingSync;

  const ClientEntity({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.deuda,
    this.updatedAt,
    this.pendingSync = false,
  });
}
