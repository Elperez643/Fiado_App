import '../../domain/entities/product_entity.dart';
import '../../models/producto.dart';

extension ProductoMapper on Producto {
  ProductEntity toEntity() {
    return ProductEntity(
      id: id,
      nombre: nombre,
      ubicacion: ubicacion,
      cantidad: cantidad,
      tipoMedida: tipoMedida,
      nivelDemanda: nivelDemanda,
      esClave: esClave,
      rotacionSemanaAnterior: rotacionSemanaAnterior,
      updatedAt: ultimaVerificacion,
    );
  }
}

extension ProductEntityMapper on ProductEntity {
  Producto toLegacyModel() {
    return Producto(
      id: id,
      nombre: nombre,
      ubicacion: ubicacion,
      cantidad: cantidad,
      tipoMedida: tipoMedida,
      nivelDemanda: nivelDemanda,
      esClave: esClave,
      ultimaVerificacion: updatedAt,
      rotacionSemanaAnterior: rotacionSemanaAnterior,
    );
  }
}
