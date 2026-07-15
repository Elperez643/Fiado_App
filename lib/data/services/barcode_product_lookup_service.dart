import '../../models/producto.dart';
import '../repositories/producto_repository.dart';

class BarcodeProductLookupResult {
  final String barcode;
  final Producto? existingProduct;

  const BarcodeProductLookupResult({
    required this.barcode,
    this.existingProduct,
  });

  bool get found => existingProduct != null;
}

class BarcodeProductLookupService {
  final ProductoRepository productoRepository;

  const BarcodeProductLookupService({required this.productoRepository});

  Future<BarcodeProductLookupResult> lookupByBarcode(
    String barcode, {
    required int negocioId,
  }) async {
    final normalized = barcode.trim();
    if (normalized.isEmpty) {
      return const BarcodeProductLookupResult(barcode: '');
    }

    final product = await productoRepository.obtenerProductoPorCodigoReferencia(
      normalized,
      negocioId: negocioId,
    );
    return BarcodeProductLookupResult(
      barcode: normalized,
      existingProduct: product,
    );
  }
}
