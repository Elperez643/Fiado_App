import 'package:flutter/material.dart';

import '../core/theme/app_motion.dart';

class AnimatedDashboardCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Duration delay;
  final BorderRadius borderRadius;

  const AnimatedDashboardCard({
    super.key,
    required this.child,
    this.onTap,
    this.delay = Duration.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
  });

  @override
  State<AnimatedDashboardCard> createState() => _AnimatedDashboardCardState();
}

class _AnimatedDashboardCardState extends State<AnimatedDashboardCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.normal);
    _opacity = CurvedAnimation(parent: _controller, curve: AppMotion.ease);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: AppMotion.ease));
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: AnimatedScale(
          duration: AppMotion.fast,
          curve: AppMotion.ease,
          scale: _pressed ? 0.985 : 1,
          child: InkWell(
            borderRadius: widget.borderRadius,
            onTap: widget.onTap,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
