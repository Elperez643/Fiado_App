import '../../models/producto.dart';
import '../../services/storage_service.dart';

abstract class ProductLocalDataSource {
  Future<List<Producto>> getAll();
  Future<void> saveAll(List<Producto> products);
}

class SharedPreferencesProductLocalDataSource implements ProductLocalDataSource {
  @override
  Future<List<Producto>> getAll() {
    return StorageService.cargarProductos();
  }

  @override
  Future<void> saveAll(List<Producto> products) {
    return StorageService.guardarProductos(products);
  }
}
