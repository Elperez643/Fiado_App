import '../entities/movement_entity.dart';

abstract class MovementRepository {
  Future<List<MovementEntity>> getMovements({int limit = 100, int offset = 0});

  Future<List<MovementEntity>> getMovementsByClient({
    required String clientId,
    int limit = 100,
    int offset = 0,
  });

  Future<void> saveMovement(MovementEntity movement);
  Future<void> saveMovements(List<MovementEntity> movements);
}
