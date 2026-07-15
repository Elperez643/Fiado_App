import '../../domain/entities/client_entity.dart';
import '../../models/cliente.dart';

extension ClienteMapper on Cliente {
  ClientEntity toEntity() {
    return ClientEntity(
      id: telefono,
      nombre: nombre,
      telefono: telefono,
      deuda: deuda,
    );
  }
}

extension ClientEntityMapper on ClientEntity {
  Cliente toLegacyModel() {
    return Cliente(nombre: nombre, telefono: telefono, deuda: deuda);
  }
}
