import '../../domain/entities/client_entity.dart';
import '../../domain/repositories/client_repository.dart';
import '../datasources/client_local_datasource.dart';
import '../models/cliente_mapper.dart';

class ClientRepositoryImpl implements ClientRepository {
  final ClientLocalDataSource localDataSource;

  const ClientRepositoryImpl({required this.localDataSource});

  @override
  Future<List<ClientEntity>> getClients({
    int limit = 50,
    int offset = 0,
    String? query,
  }) async {
    final clients = await localDataSource.getAll();
    final normalizedQuery = query?.trim().toLowerCase();
    final filtered = normalizedQuery == null || normalizedQuery.isEmpty
        ? clients
        : clients.where((client) {
            return client.nombre.toLowerCase().contains(normalizedQuery) ||
                client.telefono.contains(normalizedQuery);
          }).toList();

    return filtered.skip(offset).take(limit).map((c) => c.toEntity()).toList();
  }

  @override
  Future<ClientEntity?> getClientByPhone(String phone) async {
    final clients = await localDataSource.getAll();
    for (final client in clients) {
      if (client.telefono == phone) {
        return client.toEntity();
      }
    }

    return null;
  }

  @override
  Future<void> saveClient(ClientEntity client) async {
    final clients = await localDataSource.getAll();
    final index = clients.indexWhere((item) => item.telefono == client.telefono);
    final legacy = client.toLegacyModel();

    if (index >= 0) {
      clients[index] = legacy;
    } else {
      clients.add(legacy);
    }

    await localDataSource.saveAll(clients);
  }

  @override
  Future<void> saveClients(List<ClientEntity> clients) {
    return localDataSource.saveAll(
      clients.map((client) => client.toLegacyModel()).toList(),
    );
  }
}
