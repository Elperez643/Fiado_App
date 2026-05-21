import '../entities/client_entity.dart';

abstract class ClientRepository {
  Future<List<ClientEntity>> getClients({
    int limit = 50,
    int offset = 0,
    String? query,
  });

  Future<ClientEntity?> getClientByPhone(String phone);
  Future<void> saveClient(ClientEntity client);
  Future<void> saveClients(List<ClientEntity> clients);
}
