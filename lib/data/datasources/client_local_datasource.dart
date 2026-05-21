import '../../models/cliente.dart';
import '../../services/storage_service.dart';

abstract class ClientLocalDataSource {
  Future<List<Cliente>> getAll();
  Future<void> saveAll(List<Cliente> clients);
}

class SharedPreferencesClientLocalDataSource implements ClientLocalDataSource {
  @override
  Future<List<Cliente>> getAll() {
    return StorageService.cargarClientes();
  }

  @override
  Future<void> saveAll(List<Cliente> clients) {
    return StorageService.guardarClientes(clients);
  }
}
