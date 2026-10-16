import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/popcorn_engine.dart';
import '../controllers/popcorn_controller.dart';
import 'pip_catch_sprite.dart';
import 'pip_performance.dart';

const popcornGold = Color(0xFFFFD477);

class PopcornArena extends StatelessWidget {
  const PopcornArena(
      {super.key,
      required this.controller,
      required this.topInset,
      required this.bottomInset});
  final PopcornController controller;
  final double topInset, bottomInset;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: controller.frame,
      builder: (context, _) => LayoutBuilder(builder: (context, box) {
            final c = controller, e = c.engine;
            final width = box.maxWidth, height = box.maxHeight;
            // A consistent virtual stage keeps bucket size/catch radius aligned on
            // phones, wide windows and short landscape screens.
            final laneWidth = math.min(width * .72, height * .52);
            final left = (width - laneWidth) / 2;
            final finished = c.phase == PopcornPhase.finished ||
                c.phase == PopcornPhase.roundComplete;
            final resting = finished ||
                c.phase == PopcornPhase.ready ||
                c.phase == PopcornPhase.starting;
            final spriteWidth = resting
                ? math.min(width * .66, height * .30)
                : laneWidth * .26 / .42;
            final spriteHeight = spriteWidth * 1286 / 1223;
            final visualX = e.previousX + (e.x - e.previousX) * c.fraction;
            final centerX = left + visualX / 1000 * laneWidth;
            final spriteTop = height - bottomInset - 26 - spriteHeight;
            final catchY = spriteTop + spriteHeight * .045;
            final startY = math.min(topInset + 16, catchY - 70);
            return RepaintBoundary(
                child: Stack(fit: StackFit.expand, children: [
              Image.asset('assets/icon/popcorn_cinema_stage.png',
                  fit: BoxFit.fill, excludeFromSemantics: true),
              if (c.phase == PopcornPhase.playing ||
                  c.phase == PopcornPhase.paused)
                CustomPaint(
                    painter: _KernelsPainter(
                        e, c.fraction, laneWidth, left, catchY, startY,
                        reducedMotion:
                            MediaQuery.disableAnimationsOf(context))),
              if (!finished)
                Positioned(
                    left: centerX - spriteWidth / 2,
                    top: spriteTop,
                    width: spriteWidth,
                    height: spriteHeight,
                    child: finished
                        ? PipPerformance(
                            key: ValueKey(e),
                            mood: c.newBest
                                ? PipPerformanceMood.celebrate
                                : c.roughRound
                                    ? PipPerformanceMood.rough
                                    : PipPerformanceMood.happy)
                        : PipCatchSprite(controller: c)),
              if (c.phase == PopcornPhase.playing &&
                  e.tick - e.feedbackTick < 14)
                Positioned(
                    top: catchY - 48,
                    left: 20,
                    right: 20,
                    child: Text(e.feedback,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: e.feedback.startsWith('Ouch')
                                ? const Color(0xFFFFAFA0)
                                : popcornGold,
                            fontSize: 22,
                            fontWeight: FontWeight.w900))),
              if (c.phase == PopcornPhase.paused)
                const ColoredBox(color: Color(0x66000000)),
            ]));
          }));
}

class _KernelsPainter extends CustomPainter {
  _KernelsPainter(this.engine, this.fraction, this.laneWidth, this.left,
      this.catchY, this.startY,
      {required this.reducedMotion});
  final PopcornEngine engine;
  final double fraction, laneWidth, left, catchY, startY;
  final bool reducedMotion;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = (laneWidth / 240).clamp(.65, 1.0);
    for (final kernel in engine.kernels) {
      final progress =
          ((engine.tick - 1 - kernel.born + fraction) / kernel.fall)
              .clamp(0.0, 1.0);
      final position = Offset(left + kernel.x / 1000 * laneWidth,
          startY + (catchY - startY) * progress);
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.scale(scale);
      if (!reducedMotion) canvas.rotate((kernel.x % 7 - 3) * progress * .5);
      if (kernel.gummyBear || kernel.chocolate) {
        drawCandy(canvas, kernel);
        canvas.restore();
        continue;
      }
      final fill = kernel.burnt
          ? const Color(0xFF57404C)
          : kernel.golden
              ? popcornGold
              : const Color(0xFFFFF1CB);
      final edge =
          kernel.burnt ? const Color(0xFFFFAFA0) : const Color(0xFFCC913A);
      final shape = Path()
        ..addOval(const Rect.fromLTWH(-12, -4, 14, 16))
        ..addOval(const Rect.fromLTWH(-4, -13, 16, 19))
        ..addOval(const Rect.fromLTWH(4, -4, 14, 17))
        ..addOval(const Rect.fromLTWH(-4, 3, 14, 14));
      canvas.drawPath(
          shape,
          Paint()
            ..color = edge
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      canvas.drawPath(shape, Paint()..color = fill);
      canvas.drawOval(const Rect.fromLTWH(0, 0, 7, 8), Paint()..color = edge);
      if (kernel.burnt) {
        final p = Paint()
          ..color = const Color(0xFFFFD6CC)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(-4, -4), const Offset(5, 5), p);
        canvas.drawLine(const Offset(5, -4), const Offset(-4, 5), p);
      }
      if (kernel.golden) {
        final star = Path();
        for (var i = 0; i < 10; i++) {
          final angle = -math.pi / 2 + i * math.pi / 5;
          final r = i.isEven ? 6.0 : 2.5;
          final x = math.cos(angle) * r, y = math.sin(angle) * r;
          if (i == 0) {
            star.moveTo(x, y);
          } else {
            star.lineTo(x, y);
          }
        }
        star.close();
        canvas.drawPath(star, Paint()..color = const Color(0xFF6F3C16));
      }
      canvas.restore();
    }
  }

  static void drawCandy(Canvas canvas, PopcornKernel kernel) {
    if (kernel.chocolate) {
      final bar = RRect.fromRectAndRadius(
          const Rect.fromLTWH(-12, -16, 24, 32), const Radius.circular(4));
      canvas.drawRRect(bar, Paint()..color = const Color(0xFFE4A56B));
      canvas.drawRRect(
          bar.deflate(1.5), Paint()..color = const Color(0xFF542B26));
      for (var row = 0; row < 3; row++) {
        for (var column = 0; column < 2; column++) {
          final square = RRect.fromRectAndRadius(
              Rect.fromLTWH(-9 + column * 10, -13 + row * 9, 8, 7),
              const Radius.circular(1.5));
          canvas.drawRRect(square, Paint()..color = const Color(0xFF995C3E));
          canvas.drawLine(
              square.outerRect.topLeft + const Offset(1, 1),
              square.outerRect.topRight + const Offset(-1, 1),
              Paint()
                ..color = const Color(0xFFD49661)
                ..strokeWidth = 1.3);
        }
      }
      return;
    }
    final color =
        kernel.kind == 2 ? const Color(0xFFEF6380) : const Color(0xFF75D69A);
    final bear = Path()
      ..addOval(const Rect.fromLTWH(-10, -18, 9, 10))
      ..addOval(const Rect.fromLTWH(1, -18, 9, 10))
      ..addOval(const Rect.fromLTWH(-10, -14, 20, 18))
      ..addOval(const Rect.fromLTWH(-9, -1, 18, 21))
      ..addOval(const Rect.fromLTWH(-14, 1, 9, 12))
      ..addOval(const Rect.fromLTWH(5, 1, 9, 12))
      ..addOval(const Rect.fromLTWH(-10, 13, 10, 10))
      ..addOval(const Rect.fromLTWH(0, 13, 10, 10));
    canvas.drawPath(bear, Paint()..color = color);
    canvas.drawOval(const Rect.fromLTWH(-5, 3, 10, 12),
        Paint()..color = Colors.white.withValues(alpha: .22));
    canvas.drawOval(const Rect.fromLTWH(-6, -11, 3, 5),
        Paint()..color = Colors.white.withValues(alpha: .65));
    final face = Paint()..color = const Color(0xFF48233E);
    canvas.drawCircle(const Offset(-3.5, -6), 1.2, face);
    canvas.drawCircle(const Offset(3.5, -6), 1.2, face);
    canvas.drawOval(const Rect.fromLTWH(-2, -3, 4, 3), face);
  }

  @override
  bool shouldRepaint(covariant _KernelsPainter oldDelegate) => true;
}
