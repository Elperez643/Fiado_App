import '../models/rendered_status_image.dart';

const int whatsappStatusWidth = 720;
const int whatsappStatusHeight = 1280;
const int whatsappStatusMaxTextLength = 30;

class WhatsappStatusImageRenderer {
  const WhatsappStatusImageRenderer();

  String? validateStatusText(String value) {
    final text = value.trim();
    if (text.isEmpty) return 'El texto del estado es obligatorio.';
    if (text.length > whatsappStatusMaxTextLength) {
      return 'El texto debe tener maximo $whatsappStatusMaxTextLength caracteres.';
    }
    return null;
  }

  Future<RenderedStatusImage> renderProductStatusImage({
    required String productId,
    required String? sourceImagePath,
    required String statusText,
    required double salePrice,
    required String businessName,
    String? description,
    bool availableToday = true,
  }) {
    throw UnsupportedError(
      'El render de imagenes para Estados requiere una plataforma con archivos locales.',
    );
  }

  Future<List<RenderedStatusImage>> renderBatchSequentially(
    List<WhatsappStatusRenderRequest> requests,
  ) async {
    final rendered = <RenderedStatusImage>[];
    for (final request in requests) {
      rendered.add(
        await renderProductStatusImage(
          productId: request.productId,
          sourceImagePath: request.sourceImagePath,
          statusText: request.statusText,
          salePrice: request.salePrice,
          businessName: request.businessName,
          description: request.description,
          availableToday: request.availableToday,
        ),
      );
    }
    return rendered;
  }
}

class WhatsappStatusRenderRequest {
  final String productId;
  final String? sourceImagePath;
  final String statusText;
  final double salePrice;
  final String businessName;
  final String? description;
  final bool availableToday;

  const WhatsappStatusRenderRequest({
    required this.productId,
    required this.sourceImagePath,
    required this.statusText,
    required this.salePrice,
    required this.businessName,
    this.description,
    this.availableToday = true,
  });
}
