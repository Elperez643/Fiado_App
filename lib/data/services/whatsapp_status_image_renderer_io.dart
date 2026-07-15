import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../../core/utils/money_formatter.dart';
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
  }) async {
    final validation = validateStatusText(statusText);
    if (validation != null) throw StateError(validation);

    final source = await _loadSourceImage(sourceImagePath, statusText);
    final canvas = resizeAndCropImage(
      source,
      width: whatsappStatusWidth,
      height: whatsappStatusHeight,
    );
    _drawFooter(
      canvas,
      statusText: statusText.trim(),
      salePrice: salePrice,
      businessName: businessName,
      availableToday: availableToday,
    );
    final path = await saveRenderedImage(
      canvas,
      productId: productId,
      statusText: statusText,
      sourceImagePath: sourceImagePath,
    );
    return RenderedStatusImage(
      productId: productId,
      sourceImagePath: sourceImagePath,
      renderedImagePath: path,
      statusText: statusText.trim(),
      width: whatsappStatusWidth,
      height: whatsappStatusHeight,
      generatedAt: DateTime.now(),
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

  img.Image resizeAndCropImage(
    img.Image source, {
    required int width,
    required int height,
  }) {
    final sourceRatio = source.width / source.height;
    final targetRatio = width / height;
    late img.Image cropped;

    if (sourceRatio > targetRatio) {
      final cropWidth = (source.height * targetRatio).round();
      final x = ((source.width - cropWidth) / 2).round();
      cropped = img.copyCrop(
        source,
        x: x,
        y: 0,
        width: cropWidth,
        height: source.height,
      );
    } else {
      final cropHeight = (source.width / targetRatio).round();
      final y = ((source.height - cropHeight) / 2).round();
      cropped = img.copyCrop(
        source,
        x: 0,
        y: y,
        width: source.width,
        height: cropHeight,
      );
    }

    return img.copyResize(
      cropped,
      width: width,
      height: height,
      interpolation: img.Interpolation.average,
    );
  }

  Future<String> saveRenderedImage(
    img.Image image, {
    required String productId,
    required String statusText,
    String? sourceImagePath,
  }) async {
    final cacheDir = await getTemporaryDirectory();
    final safeProductId = productId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final signature = Object.hash(
      productId,
      statusText.trim(),
      sourceImagePath ?? '',
      File(sourceImagePath ?? '').existsSync()
          ? File(sourceImagePath!).lastModifiedSync().millisecondsSinceEpoch
          : 0,
    ).abs();
    final path =
        '${cacheDir.path}${Platform.pathSeparator}fiado_status_${safeProductId}_$signature.jpg';
    final file = File(path);
    if (await file.exists()) return path;
    await file.writeAsBytes(img.encodeJpg(image, quality: 88), flush: true);
    return path;
  }

  Future<img.Image> _loadSourceImage(
    String? sourceImagePath,
    String statusText,
  ) async {
    if (sourceImagePath == null || sourceImagePath.trim().isEmpty) {
      return _simpleFlyerBackground(statusText);
    }
    final file = File(sourceImagePath);
    if (!await file.exists()) return _simpleFlyerBackground(statusText);
    final length = await file.length();
    if (length > 2 * 1024 * 1024) {
      throw StateError('La imagen debe pesar maximo 2 MB.');
    }
    final decoded = img.decodeImage(await file.readAsBytes());
    if (decoded == null) {
      throw StateError('Formato de imagen no soportado. Usa PNG o JPG.');
    }
    return decoded;
  }

  img.Image _simpleFlyerBackground(String statusText) {
    final image = img.Image(
      width: whatsappStatusWidth,
      height: whatsappStatusHeight,
    );
    img.fill(image, color: img.ColorRgb8(232, 246, 240));
    for (var y = 0; y < image.height; y++) {
      final shade = (232 - min(70, (y / image.height * 70).round())).toInt();
      final green = min(255, shade + 18).toInt();
      final blue = min(255, shade + 8).toInt();
      img.drawLine(
        image,
        x1: 0,
        y1: y,
        x2: image.width,
        y2: y,
        color: img.ColorRgb8(shade, green, blue),
      );
    }
    img.drawString(
      image,
      'Disponible',
      font: img.arial48,
      x: 44,
      y: 120,
      color: img.ColorRgb8(23, 50, 44),
    );
    img.drawString(
      image,
      statusText,
      font: img.arial48,
      x: 44,
      y: 180,
      color: img.ColorRgb8(23, 50, 44),
    );
    return image;
  }

  void _drawFooter(
    img.Image canvas, {
    required String statusText,
    required double salePrice,
    required String businessName,
    required bool availableToday,
  }) {
    final footerHeight = (canvas.height * 0.21).round();
    final footerTop = canvas.height - footerHeight;

    for (var y = footerTop - 48; y < footerTop; y++) {
      if (y < 0) continue;
      final alpha = ((y - (footerTop - 48)) / 48 * 180).clamp(0, 180).round();
      img.drawLine(
        canvas,
        x1: 0,
        y1: y,
        x2: canvas.width,
        y2: y,
        color: img.ColorRgba8(12, 32, 29, alpha),
      );
    }
    img.fillRect(
      canvas,
      x1: 0,
      y1: footerTop,
      x2: canvas.width,
      y2: canvas.height,
      color: img.ColorRgba8(16, 55, 50, 232),
    );

    final titleFont = statusText.length <= 18 ? img.arial48 : img.arial24;
    final textLines = _wrapText(
      statusText,
      maxChars: titleFont == img.arial48 ? 18 : 28,
    ).take(2).toList();
    var y = footerTop + 30;
    for (final line in textLines) {
      img.drawString(
        canvas,
        line,
        font: titleFont,
        x: 36,
        y: y,
        color: img.ColorRgb8(255, 255, 255),
      );
      y += titleFont.lineHeight + 4;
    }

    if (salePrice > 0) {
      img.drawString(
        canvas,
        MoneyFormatter.formatCurrency(salePrice),
        font: img.arial48,
        x: 36,
        y: footerTop + footerHeight - 82,
        color: img.ColorRgb8(255, 221, 130),
      );
    }

    img.drawString(
      canvas,
      availableToday ? 'Disponible hoy' : 'No disponible hoy',
      font: img.arial24,
      x: 36,
      y: canvas.height - 34,
      color: img.ColorRgb8(220, 233, 229),
    );
    final branding = 'Fiado App';
    img.drawString(
      canvas,
      businessName.trim().isEmpty ? branding : businessName.trim(),
      font: img.arial24,
      x: canvas.width - 260,
      y: canvas.height - 66,
      color: img.ColorRgb8(220, 233, 229),
    );
    img.drawString(
      canvas,
      branding,
      font: img.arial24,
      x: canvas.width - 150,
      y: canvas.height - 34,
      color: img.ColorRgb8(255, 255, 255),
    );
  }

  List<String> _wrapText(String text, {required int maxChars}) {
    final words = text.trim().split(RegExp(r'\s+'));
    final lines = <String>[];
    var current = '';
    for (final word in words) {
      final candidate = current.isEmpty ? word : '$current $word';
      if (candidate.length > maxChars && current.isNotEmpty) {
        lines.add(current);
        current = word;
      } else {
        current = candidate;
      }
    }
    if (current.isNotEmpty) lines.add(current);
    return lines.isEmpty ? [text] : lines;
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
