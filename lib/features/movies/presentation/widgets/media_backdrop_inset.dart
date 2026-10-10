import 'package:flutter/material.dart';

/// Carries the preview's reserved artwork space into the loaded header.
class MediaBackdropInset extends StatelessWidget {
  const MediaBackdropInset(
      {super.key,
      required this.hasBackdrop,
      required this.width,
      required this.top,
      required this.bottom,
      required this.child,
      this.animate = false});
  final bool hasBackdrop, animate;
  final double width, top, bottom;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reserved = (width * .38).clamp(125.0, 190.0);
    final target = hasBackdrop ? reserved : 0.0;
    final motion = animate && !MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: motion ? reserved : target, end: target),
      duration: motion ? const Duration(milliseconds: 280) : Duration.zero,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (_, space, child) => Padding(
          padding: EdgeInsets.only(top: top + space, bottom: bottom),
          child: child),
    );
  }
}
