import '../entities/product_entity.dart';

abstract class ProductRepository {
  Future<List<ProductEntity>> getProducts({
    int limit = 100,
    int offset = 0,
    String? query,
  });

  Future<void> saveProduct(ProductEntity product);
  Future<void> saveProducts(List<ProductEntity> products);
}
