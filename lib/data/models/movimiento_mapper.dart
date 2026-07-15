import '../../domain/entities/movement_entity.dart';
import '../../models/movimiento.dart';

extension MovimientoMapper on Movimiento {
  MovementEntity toEntity({String? clientId}) {
    return MovementEntity(
      id: '${nombreCliente}_${fecha.toIso8601String()}_$tipo',
      clientId: clientId ?? clienteId?.toString() ?? nombreCliente,
      nombreCliente: nombreCliente,
      tipo: tipo,
      monto: monto,
      fecha: fecha,
    );
  }
}

extension MovementEntityMapper on MovementEntity {
  Movimiento toLegacyModel() {
    return Movimiento(
      clienteId: int.tryParse(clientId),
      nombreCliente: nombreCliente,
      tipo: tipo,
      monto: monto,
      fecha: fecha,
    );
  }
}
