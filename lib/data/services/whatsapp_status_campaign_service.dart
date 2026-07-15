import 'package:share_plus/share_plus.dart';

import '../models/rendered_status_image.dart';
import '../models/whatsapp_campaign_publication.dart';
import '../repositories/whatsapp_campaign_repository.dart';

class WhatsappStatusCampaignService {
  final WhatsappCampaignRepository repository;

  const WhatsappStatusCampaignService({required this.repository});

  Future<WhatsappCampaignPublication> crearPublicacionPendiente({
    required int negocioId,
    required String mode,
    required List<String> productIds,
    required List<RenderedStatusImage> renderedImages,
    int quotaUnits = 1,
  }) {
    return repository.crearPendiente(
      negocioId: negocioId,
      mode: mode,
      productIds: productIds,
      renderedImagePaths: renderedImages
          .map((image) => image.renderedImagePath)
          .toList(growable: false),
      statusTexts: renderedImages
          .map((image) => image.statusText)
          .toList(growable: false),
      quotaUnits: quotaUnits,
    );
  }

  Future<WhatsappCampaignPublication> compartirPublicacion(
    WhatsappCampaignPublication publication,
  ) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: publication.renderedImagePaths
              .map((path) => XFile(path))
              .toList(growable: false),
          text: 'Estados generados con Fiado App.',
        ),
      );
      return repository.registrarEnviadoAWhatsapp(publication);
    } catch (error) {
      return repository.registrarFalloAntesDeAbrirWhatsapp(
        publication,
        error: '$error',
      );
    }
  }

  Future<WhatsappCampaignPublication> reintentarMismaPublicacion(
    WhatsappCampaignPublication publication,
  ) async {
    final canRetry = await repository.puedeReintentarMismaPublicacion(
      publication,
    );
    if (!canRetry) {
      throw StateError(
        'Esta publicacion ya no puede reintentarse sin consumir cupo.',
      );
    }
    return compartirPublicacion(publication);
  }
}
