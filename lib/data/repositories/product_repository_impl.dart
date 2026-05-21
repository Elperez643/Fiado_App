import '../../domain/entities/product_entity.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/product_local_datasource.dart';
import '../models/producto_mapper.dart';

class ProductRepositoryImpl implements ProductRepository {
  final ProductLocalDataSource localDataSource;

  const ProductRepositoryImpl({required this.localDataSource});

  @override
  Future<List<ProductEntity>> getProducts({
    int limit = 100,
    int offset = 0,
    String? query,
  }) async {
    final products = await localDataSource.getAll();
    final normalizedQuery = query?.trim().toLowerCase();
    final filtered = normalizedQuery == null || normalizedQuery.isEmpty
        ? products
        : products.where((product) {
            return product.nombre.toLowerCase().contains(normalizedQuery) ||
                product.ubicacion.toLowerCase().contains(normalizedQuery);
          }).toList();

    return filtered.skip(offset).take(limit).map((p) => p.toEntity()).toList();
  }

  @override
  Future<void> saveProduct(ProductEntity product) async {
    final products = await localDataSource.getAll();
    final index = products.indexWhere((item) => item.id == product.id);
    final legacy = product.toLegacyModel();

    if (index >= 0) {
      products[index] = legacy;
    } else {
      products.add(legacy);
    }

    await localDataSource.saveAll(products);
  }

  @override
  Future<void> saveProducts(List<ProductEntity> products) {
    return localDataSource.saveAll(
      products.map((product) => product.toLegacyModel()).toList(),
    );
  }
}
