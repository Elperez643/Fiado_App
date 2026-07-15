class BillableProduct {
  final int id;
  final String? legacyId;
  final int negocioId;
  final String nombre;
  final String? codigoReferencia;
  final String? categoria;
  final String? descripcion;
  final String ubicacion;
  final int stock;
  final double costoUnitario;
  final double precioVenta;
  final double porcentajeGanancia;
  final bool activo;
  final String? imagenPrincipalPath;

  const BillableProduct({
    required this.id,
    required this.legacyId,
    required this.negocioId,
    required this.nombre,
    required this.codigoReferencia,
    required this.categoria,
    required this.descripcion,
    required this.ubicacion,
    required this.stock,
    required this.costoUnitario,
    required this.precioVenta,
    required this.porcentajeGanancia,
    required this.activo,
    required this.imagenPrincipalPath,
  });

  factory BillableProduct.fromMap(Map<String, Object?> map) {
    return BillableProduct(
      id: (map['id'] as num).toInt(),
      legacyId: map['legacy_id'] as String?,
      negocioId: (map['negocio_id'] as num).toInt(),
      nombre: map['nombre'] as String,
      codigoReferencia: map['codigo_referencia'] as String?,
      categoria: map['categoria'] as String?,
      descripcion: map['descripcion'] as String?,
      ubicacion: map['ubicacion'] as String? ?? 'Sin ubicacion',
      stock: (map['cantidad'] as num? ?? 0).toInt(),
      costoUnitario:
          (map['costo_unitario'] as num?)?.toDouble() ??
          (map['precio_compra'] as num?)?.toDouble() ??
          0,
      precioVenta: (map['precio_venta'] as num? ?? 0).toDouble(),
      porcentajeGanancia: (map['porcentaje_ganancia'] as num? ?? 0).toDouble(),
      activo: (map['activo'] as num? ?? 1).toInt() == 1,
      imagenPrincipalPath: map['imagen_principal_path'] as String?,
    );
  }
}
