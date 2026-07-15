import '../models/product_optimized_image_result.dart';

const int productImageOptimizedSize = 500;
const int productImageIdealMinBytes = 120 * 1024;
const int productImageIdealMaxBytes = 200 * 1024;
const int productImageMaxBytes = 300 * 1024;

class ProductImageOptimizerService {
  const ProductImageOptimizerService();

  bool isAllowedFormat(String? mimeType, String path) {
    final normalized = mimeType?.toLowerCase().trim();
    if (normalized == 'image/png' ||
        normalized == 'image/jpeg' ||
        normalized == 'image/jpg') {
      return true;
    }
    final lowerPath = path.toLowerCase();
    return lowerPath.endsWith('.png') ||
        lowerPath.endsWith('.jpg') ||
        lowerPath.endsWith('.jpeg');
  }

  Future<ProductOptimizedImageResult> optimizeProductImage({
    required String sourcePath,
    String? mimeType,
  }) {
    throw UnsupportedError(
      'La optimizacion de imagenes requiere acceso a archivos locales.',
    );
  }
}
