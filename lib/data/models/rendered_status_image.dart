class RenderedStatusImage {
  final String productId;
  final String? sourceImagePath;
  final String renderedImagePath;
  final String statusText;
  final int width;
  final int height;
  final DateTime generatedAt;

  const RenderedStatusImage({
    required this.productId,
    required this.sourceImagePath,
    required this.renderedImagePath,
    required this.statusText,
    required this.width,
    required this.height,
    required this.generatedAt,
  });
}
