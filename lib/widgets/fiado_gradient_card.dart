import 'package:flutter/material.dart';

import '../core/theme/app_gradients.dart';
import '../core/theme/app_shadows.dart';

class FiadoGradientCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient gradient;

  const FiadoGradientCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.gradient = AppGradients.executive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppShadows.elevated,
      ),
      child: child,
    );
  }
}
