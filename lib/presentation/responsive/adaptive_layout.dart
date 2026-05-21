import 'package:flutter/material.dart';

class AdaptiveLayout {
  static const double compactWidth = 600;
  static const double tabletWidth = 900;
  static const double desktopWidth = 1200;
  static const double contentMaxWidth = 1040;

  static bool isCompact(double width) => width < compactWidth;

  static bool isTabletOrWider(double width) => width >= compactWidth;

  static bool isDesktop(double width) => width >= desktopWidth;

  static double horizontalPadding(double width) {
    if (width < compactWidth) {
      return 20;
    }

    if (width < tabletWidth) {
      return 28;
    }

    return 36;
  }

  static double contentInset(
    double width, {
    double maxWidth = contentMaxWidth,
  }) {
    final padding = horizontalPadding(width);
    if (width <= maxWidth + (padding * 2)) {
      return padding;
    }

    return (width - maxWidth) / 2;
  }

  static int responsiveColumns(
    double width, {
    int compact = 1,
    int tablet = 2,
    int desktop = 3,
  }) {
    if (width >= desktopWidth) {
      return desktop;
    }

    if (width >= compactWidth) {
      return tablet;
    }

    return compact;
  }
}

class AdaptiveWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final AlignmentGeometry alignment;

  const AdaptiveWidth({
    super.key,
    required this.child,
    this.maxWidth = AdaptiveLayout.contentMaxWidth,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
