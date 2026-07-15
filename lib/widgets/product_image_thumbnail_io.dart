import 'dart:io';

import 'package:flutter/material.dart';

import '../data/models/producto_imagen_sqlite_model.dart';

class ProductImageThumbnail extends StatelessWidget {
  final ProductoImagenSqliteModel? image;
  final bool stockBajo;
  final bool esClave;
  final double size;

  const ProductImageThumbnail({
    super.key,
    required this.image,
    required this.stockBajo,
    required this.esClave,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    final imagePath = image?.localPath.trim();
    if (imagePath == null || imagePath.isEmpty) {
      return _ProductImagePlaceholder(
        stockBajo: stockBajo,
        esClave: esClave,
        size: size,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.file(
        File(imagePath),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _ProductImagePlaceholder(
          stockBajo: stockBajo,
          esClave: esClave,
          size: size,
        ),
      ),
    );
  }
}

class _ProductImagePlaceholder extends StatelessWidget {
  final bool stockBajo;
  final bool esClave;
  final double size;

  const _ProductImagePlaceholder({
    required this.stockBajo,
    required this.esClave,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final alert = stockBajo || esClave;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: alert
              ? const [Color(0xFFFFF4DB), Color(0xFFFFE2A8)]
              : const [Color(0xFFE7F3EF), Color(0xFFD3EEE7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        stockBajo
            ? Icons.warning_amber_rounded
            : esClave
            ? Icons.priority_high_rounded
            : Icons.inventory_2_outlined,
        color: alert ? const Color(0xFFB54708) : const Color(0xFF1F7A6B),
      ),
    );
  }
}
