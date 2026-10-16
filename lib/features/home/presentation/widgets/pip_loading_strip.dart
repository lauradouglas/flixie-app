import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

/// A delayed, bounded Home companion; content skeletons remain available.
class PipLoadingStrip extends StatefulWidget {
  const PipLoadingStrip(
      {super.key,
      this.size = 60,
      this.message = 'Finding your next great watch…'});
  final double size;
  final String message;
  @override
  State<PipLoadingStrip> createState() => _PipLoadingStripState();
}

class _PipLoadingStripState extends State<PipLoadingStrip>
    with SingleTickerProviderStateMixin {
  late final _motion =
      AnimationController(vsync: this, duration: const Duration(seconds: 6));
  Timer? _delay;
  bool _visible = false;
  bool _animate = false;

  @override
  void initState() {
    super.initState();
    _delay = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() => _visible = true);
      _updateMotion();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate = !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    _updateMotion();
  }

  void _updateMotion() {
    if (_visible && _animate) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.stop();
      _motion.value = 0;
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(children: [
          // Reserve the same space before the delayed reveal to avoid shifting content.
          Opacity(
              opacity: _visible ? 1 : 0,
              child: ExcludeSemantics(
                  excluding: !_visible,
                  child: Text(widget.message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: context.colors.medium)))),
          SizedBox(
              height: widget.size + 16,
              child: _visible
                  ? ClipRect(
                      child: LayoutBuilder(
                          builder: (context, box) => AnimatedBuilder(
                              animation: _motion,
                              child: Image.asset(
                                  'assets/splash/pip/popcorn.png',
                                  width: widget.size,
                                  height: widget.size,
                                  fit: BoxFit.contain,
                                  cacheWidth: 160,
                                  excludeFromSemantics: true),
                              builder: (context, child) {
                                final travel =
                                    math.max(0.0, box.maxWidth - widget.size);
                                final t = _motion.value;
                                final x = _animate
                                    ? (1 - math.cos(t * math.pi * 2)) /
                                        2 *
                                        travel
                                    : travel / 2;
                                final skip = math.sin(t * math.pi * 24);
                                return Stack(children: [
                                  Positioned(
                                      left: x,
                                      bottom: 0,
                                      child: Transform.translate(
                                          offset: Offset(0,
                                              _animate ? -skip.abs() * 10 : 0),
                                          child: Transform.rotate(
                                              angle: _animate ? skip * .08 : 0,
                                              child: Transform.flip(
                                                  flipX: _animate && t > .5,
                                                  child: child))))
                                ]);
                              })))
                  : const SizedBox.shrink()),
        ]),
      );
}
