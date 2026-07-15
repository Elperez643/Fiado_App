class ProductEntity {
  final String id;
  final String nombre;
  final String ubicacion;
  final int cantidad;
  final double costoUnitario;
  final double precioVenta;
  final double porcentajeGanancia;
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
    this.costoUnitario = 0,
    this.precioVenta = 0,
    this.porcentajeGanancia = 0,
    required this.tipoMedida,
    required this.nivelDemanda,
    required this.esClave,
    required this.rotacionSemanaAnterior,
    this.updatedAt,
    this.pendingSync = false,
  });
}
