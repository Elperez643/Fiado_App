import 'package:flutter/material.dart';

class RenderedStatusImageView extends StatelessWidget {
  final String path;

  const RenderedStatusImageView({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Preview disponible en Android, iOS, Windows, macOS o Linux.',
        textAlign: TextAlign.center,
      ),
    );
  }
}
