class ProductOptimizedImageResult {
  final String originalPath;
  final String optimizedPath;
  final int originalWidth;
  final int originalHeight;
  final int optimizedWidth;
  final int optimizedHeight;
  final int originalSizeBytes;
  final int optimizedSizeBytes;
  final String mimeType;
  final int compressionQuality;
  final DateTime createdAt;

  const ProductOptimizedImageResult({
    required this.originalPath,
    required this.optimizedPath,
    required this.originalWidth,
    required this.originalHeight,
    required this.optimizedWidth,
    required this.optimizedHeight,
    required this.originalSizeBytes,
    required this.optimizedSizeBytes,
    required this.mimeType,
    required this.compressionQuality,
    required this.createdAt,
  });

  double get savingsPercent {
    if (originalSizeBytes <= 0) return 0;
    return (1 - (optimizedSizeBytes / originalSizeBytes)) * 100;
  }
}
