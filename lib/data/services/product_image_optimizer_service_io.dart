import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../models/product_optimized_image_result.dart';

const int productImageOptimizedSize = 500;
const int productImageIdealMinBytes = 120 * 1024;
const int productImageIdealMaxBytes = 200 * 1024;
const int productImageMaxBytes = 300 * 1024;
const List<int> _qualityAttempts = [85, 80, 75, 70, 65];

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
  }) async {
    if (!isAllowedFormat(mimeType, sourcePath)) {
      throw StateError('Formato no permitido. Usa PNG o JPG.');
    }

    final file = File(sourcePath);
    if (!await file.exists()) {
      throw StateError('No se encontro la imagen seleccionada.');
    }

    final outputDir = await _outputDirectory();
    final payload = <String, Object?>{
      'sourcePath': sourcePath,
      'outputDir': outputDir.path,
    };
    return compute(_optimizeInIsolate, payload);
  }

  Future<Directory> _outputDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(
      '${base.path}${Platform.pathSeparator}product_images',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}

Future<ProductOptimizedImageResult> _optimizeInIsolate(
  Map<String, Object?> payload,
) async {
  final sourcePath = payload['sourcePath'] as String;
  final outputDir = payload['outputDir'] as String;
  final sourceFile = File(sourcePath);
  final originalBytes = await sourceFile.readAsBytes();
  final decoded = img.decodeImage(originalBytes);
  if (decoded == null) {
    throw StateError('Formato de imagen no soportado. Usa PNG o JPG.');
  }

  final cropped = _resizeAndCropImage(
    decoded,
    width: productImageOptimizedSize,
    height: productImageOptimizedSize,
  );
  final hasTransparency = _hasTransparency(cropped);
  final encoded = _encodeAdaptive(cropped, allowPng: hasTransparency);
  if (encoded.bytes.length > productImageMaxBytes) {
    throw StateError('No se pudo optimizar la imagen por debajo de 300 KB.');
  }

  final extension = encoded.mimeType == 'image/png' ? 'png' : 'jpg';
  final safeName =
      'product_${DateTime.now().millisecondsSinceEpoch}_${sourcePath.hashCode.abs()}.$extension';
  final outputPath = '$outputDir${Platform.pathSeparator}$safeName';
  await File(outputPath).writeAsBytes(encoded.bytes, flush: true);

  return ProductOptimizedImageResult(
    originalPath: sourcePath,
    optimizedPath: outputPath,
    originalWidth: decoded.width,
    originalHeight: decoded.height,
    optimizedWidth: productImageOptimizedSize,
    optimizedHeight: productImageOptimizedSize,
    originalSizeBytes: originalBytes.length,
    optimizedSizeBytes: encoded.bytes.length,
    mimeType: encoded.mimeType,
    compressionQuality: encoded.quality,
    createdAt: DateTime.now(),
  );
}

img.Image _resizeAndCropImage(
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

_EncodedImage _encodeAdaptive(img.Image image, {required bool allowPng}) {
  if (allowPng) {
    final png = Uint8List.fromList(img.encodePng(image, level: 9));
    if (png.length <= productImageMaxBytes) {
      return _EncodedImage(bytes: png, mimeType: 'image/png', quality: 100);
    }
  }

  _EncodedImage? bestAcceptable;
  _EncodedImage? smallest;

  final flattened = _flattenOnWhite(image);
  for (final quality in _qualityAttempts) {
    final bytes = Uint8List.fromList(
      img.encodeJpg(flattened, quality: quality),
    );
    final encoded = _EncodedImage(
      bytes: bytes,
      mimeType: 'image/jpeg',
      quality: quality,
    );

    if (bytes.length >= productImageIdealMinBytes &&
        bytes.length <= productImageIdealMaxBytes) {
      return encoded;
    }

    if (bytes.length <= productImageMaxBytes) {
      bestAcceptable ??= encoded;
    }

    if (smallest == null || bytes.length < smallest.bytes.length) {
      smallest = encoded;
    }
  }

  return bestAcceptable ?? smallest!;
}

img.Image _flattenOnWhite(img.Image source) {
  final output = img.Image(width: source.width, height: source.height);
  img.fill(output, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(output, source);
  return output;
}

bool _hasTransparency(img.Image image) {
  if (image.numChannels < 4) return false;
  for (final pixel in image) {
    if (pixel.a.toInt() < 255) return true;
  }
  return false;
}

class _EncodedImage {
  final Uint8List bytes;
  final String mimeType;
  final int quality;

  const _EncodedImage({
    required this.bytes,
    required this.mimeType,
    required this.quality,
  });
}
