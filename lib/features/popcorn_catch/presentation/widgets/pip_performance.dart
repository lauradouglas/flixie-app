import 'dart:math' as math;
import 'package:flutter/material.dart';

enum PipPerformanceMood { celebrate, rough, happy }

/// Finite authored performance: anticipation, leap, squash and victory dance.
class PipPerformance extends StatefulWidget {
  const PipPerformance({super.key, required this.mood});
  final PipPerformanceMood mood;
  @override
  State<PipPerformance> createState() => _PipPerformanceState();
}

class _PipPerformanceState extends State<PipPerformance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 4200));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _play();
  }

  @override
  void didUpdateWidget(covariant PipPerformance old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood) _play();
  }

  void _play() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.value = 1;
    } else {
      _animation.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final t = _animation.value;
        var pose = 'land';
        double dy = 0, sx = 1, sy = 1, angle = 0;
        if (widget.mood == PipPerformanceMood.rough) {
          pose = 'sad';
          dy = 8 * math.sin(math.pi * t) * (1 - t);
        } else if (widget.mood == PipPerformanceMood.celebrate) {
          if (t < .13) {
            pose = 'crouch';
            final p = t / .13;
            sx = 1 + .06 * p;
            sy = 1 - .10 * p;
          } else if (t < .36) {
            pose = 'leap';
            final p = (t - .13) / .23;
            dy = -48 * math.sin(math.pi * p);
            sx = .96;
            sy = 1.04;
          } else if (t < .46) {
            pose = 'land';
            final p = (t - .36) / .10;
            sx = 1 + .10 * (1 - p);
            sy = 1 - .12 * (1 - p);
          } else {
            pose = 'dance';
            final p = (t - .46) / .54;
            final wave = math.sin(p * math.pi * 6);
            dy = -8 * wave.abs() * (1 - p);
            angle = wave * .09 * (1 - p);
          }
        }
        return Semantics(
            label: widget.mood == PipPerformanceMood.celebrate
                ? 'Pip celebrates your new personal best'
                : widget.mood == PipPerformanceMood.rough
                    ? 'Pip peeks sadly out of his bucket. Another go?'
                    : 'Pip smiles with his popcorn bucket',
            child: Stack(fit: StackFit.expand, children: [
              if (widget.mood == PipPerformanceMood.celebrate &&
                  t > .18 &&
                  t < .95)
                CustomPaint(painter: _Confetti(t)),
              Transform.translate(
                  offset: Offset(0, dy),
                  child: Transform.rotate(
                      angle: angle,
                      alignment: Alignment.bottomCenter,
                      child: Transform.scale(
                          scaleX: sx,
                          scaleY: sy,
                          alignment: Alignment.bottomCenter,
                          child: Image.asset(
                              'assets/icon/pip_popcorn_$pose.png',
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                              excludeFromSemantics: true)))),
            ]));
      });
}

class _Confetti extends CustomPainter {
  _Confetti(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final p = ((progress - .18) / .77).clamp(0.0, 1.0);
    for (var i = 0; i < 18; i++) {
      final x = size.width * (.08 + (i * 37 % 89) / 100),
          y = size.height * (p * .8 - .15 + (i % 4) * .07);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(i + p * 5);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(-2, -4, 4, 8), const Radius.circular(1)),
          Paint()
            ..color =
                (i.isEven ? const Color(0xFFFFD477) : const Color(0xFFB68AFF))
                    .withValues(alpha: 1 - p));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _Confetti old) => progress != old.progress;
}
