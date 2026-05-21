import '../../data/datasources/client_local_datasource.dart';
import '../../data/datasources/movement_local_datasource.dart';
import '../../data/datasources/product_local_datasource.dart';
import '../../data/repositories/client_repository_impl.dart';
import '../../data/repositories/movement_repository_impl.dart';
import '../../data/repositories/product_repository_impl.dart';
import '../../domain/repositories/client_repository.dart';
import '../../domain/repositories/movement_repository.dart';
import '../../domain/repositories/product_repository.dart';

class AppDependencies {
  final ClientRepository clientRepository;
  final MovementRepository movementRepository;
  final ProductRepository productRepository;

  const AppDependencies({
    required this.clientRepository,
    required this.movementRepository,
    required this.productRepository,
  });

  factory AppDependencies.legacySharedPreferences() {
    return AppDependencies(
      clientRepository: ClientRepositoryImpl(
        localDataSource: SharedPreferencesClientLocalDataSource(),
      ),
      movementRepository: MovementRepositoryImpl(
        localDataSource: SharedPreferencesMovementLocalDataSource(),
      ),
      productRepository: ProductRepositoryImpl(
        localDataSource: SharedPreferencesProductLocalDataSource(),
      ),
    );
  }
}
