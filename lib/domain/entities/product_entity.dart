class ProductEntity {
  final String id;
  final String nombre;
  final String ubicacion;
  final int cantidad;
  final String tipoMedida;
  final String nivelDemanda;
  final bool esClave;
  final int rotacionSemanaAnterior;
  final DateTime? updatedAt;
  final bool pendingSync;

  const ProductEntity({
    required this.id,
    required this.nombre,
    required this.ubicacion,
    required this.cantidad,
    required this.tipoMedida,
    required this.nivelDemanda,
    required this.esClave,
    required this.rotacionSemanaAnterior,
    this.updatedAt,
    this.pendingSync = false,
  });
}
