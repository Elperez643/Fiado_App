import '../../models/movimiento.dart';
import '../../services/storage_service.dart';

abstract class MovementLocalDataSource {
  Future<List<Movimiento>> getAll();
  Future<void> saveAll(List<Movimiento> movements);
}

class SharedPreferencesMovementLocalDataSource
    implements MovementLocalDataSource {
  @override
  Future<List<Movimiento>> getAll() {
    return StorageService.cargarHistorial();
  }

  @override
  Future<void> saveAll(List<Movimiento> movements) {
    return StorageService.guardarHistorial(movements);
  }
}
