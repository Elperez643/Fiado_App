import '../../domain/entities/movement_entity.dart';
import '../../domain/repositories/movement_repository.dart';
import '../datasources/movement_local_datasource.dart';
import '../models/movimiento_mapper.dart';

class MovementRepositoryImpl implements MovementRepository {
  final MovementLocalDataSource localDataSource;

  const MovementRepositoryImpl({required this.localDataSource});

  @override
  Future<List<MovementEntity>> getMovements({
    int limit = 100,
    int offset = 0,
  }) async {
    final movements = await localDataSource.getAll();
    movements.sort((a, b) => b.fecha.compareTo(a.fecha));
    return movements
        .skip(offset)
        .take(limit)
        .map((movement) => movement.toEntity())
        .toList();
  }

  @override
  Future<List<MovementEntity>> getMovementsByClient({
    required String clientId,
    int limit = 100,
    int offset = 0,
  }) async {
    final movements = await localDataSource.getAll();
    final filtered =
        movements
            .where(
              (movement) =>
                  movement.clienteId?.toString() == clientId ||
                  (movement.clienteId == null &&
                      movement.nombreCliente == clientId),
            )
            .toList()
          ..sort((a, b) => b.fecha.compareTo(a.fecha));

    return filtered
        .skip(offset)
        .take(limit)
        .map((movement) => movement.toEntity(clientId: clientId))
        .toList();
  }

  @override
  Future<void> saveMovement(MovementEntity movement) async {
    final movements = await localDataSource.getAll();
    movements.add(movement.toLegacyModel());
    await localDataSource.saveAll(movements);
  }

  @override
  Future<void> saveMovements(List<MovementEntity> movements) {
    return localDataSource.saveAll(
      movements.map((movement) => movement.toLegacyModel()).toList(),
    );
  }
}
