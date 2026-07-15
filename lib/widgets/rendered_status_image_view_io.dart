import 'dart:io';

import 'package:flutter/material.dart';

class RenderedStatusImageView extends StatelessWidget {
  final String path;

  const RenderedStatusImageView({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return const Center(child: Text('No se pudo cargar el preview.'));
      },
    );
  }
}
