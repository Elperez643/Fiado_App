import '../../models/producto.dart';

abstract class ProductLocalDataSource {
  Future<List<Producto>> getAll();
  Future<void> saveAll(List<Producto> products);
}

class SharedPreferencesProductLocalDataSource
    implements ProductLocalDataSource {
  @override
  Future<List<Producto>> getAll() async {
    return const <Producto>[];
  }

  @override
  Future<void> saveAll(List<Producto> products) async {}
}
