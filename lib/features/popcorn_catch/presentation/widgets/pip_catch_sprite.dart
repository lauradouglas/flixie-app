import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../controllers/popcorn_controller.dart';

/// Registered sprite frames keep the bucket and collision line stationary.
class PipCatchSprite extends StatelessWidget {
  const PipCatchSprite({super.key, required this.controller});
  final PopcornController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller, e = c.engine;
    final moving = c.phase == PopcornPhase.playing;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final time = e.tick + c.fraction;
    final blink = moving && !reduced && time % 83 < 2.8 && e.tick > 0;
    final sinceCatch = time - e.feedbackTick;
    final hurt = e.feedback.startsWith('Ouch') && sinceCatch < 10;
    final happyCatch = !hurt && sinceCatch < 5;
    final expression = hurt
        ? 2
        : happyCatch
            ? 0
            : e.expression;
    final asset = blink
        ? 'pip_popcorn_blink'
        : expression == 2
            ? 'pip_popcorn_frantic'
            : expression == 1
                ? 'pip_popcorn_worried'
                : 'pip_popcorn_catch';
    final bounce = moving && !reduced && sinceCatch >= 0 && sinceCatch < 7
        ? -math.sin(sinceCatch / 7 * math.pi) * 3
        : 0.0;
    return Semantics(
      label:
          'Pip ${hurt ? 'reacting to burnt popcorn' : expression == 2 ? 'feeling frantic' : expression == 1 ? 'looking worried' : 'smiling'}, holding a bucket with ${e.caught} treats caught',
      child: Transform.translate(
          offset: Offset(
              0,
              bounce +
                  (moving && !reduced
                      ? -math.sin(time * .65).abs() * e.movement * 4
                      : 0)),
          child: Transform.scale(
              scaleX: moving && !reduced
                  ? 1 + math.sin(time * .7) * e.movement * .025
                  : 1,
              scaleY: moving && !reduced
                  ? 1 - math.sin(time * .7) * e.movement * .018
                  : 1,
              alignment: Alignment.topCenter,
              child: Stack(fit: StackFit.expand, children: [
                Image.asset('assets/icon/$asset.png',
                    fit: BoxFit.fill,
                    excludeFromSemantics: true,
                    gaplessPlayback: true),
                CustomPaint(painter: _BasketPainter(e.basket)),
              ]))),
    );
  }
}

class _BasketPainter extends CustomPainter {
  const _BasketPainter(this.treats);
  final List<int> treats;
  @override
  void paint(Canvas canvas, Size size) {
    if (treats.isEmpty) return;
    canvas.save();
    // Confine the growing pile to the opening, below the illustrated rim.
    canvas.translate(size.width * .50, size.height * .105);
    canvas.scale(size.width / 1223, size.height / 1286);
    canvas.clipPath(Path()..addOval(const Rect.fromLTWH(-210, -55, 420, 110)));
    for (var i = 0; i < treats.length; i++) {
      final row = i ~/ 6, column = i % 6;
      canvas.save();
      canvas.translate(
          -150 + column * 60 + (row.isOdd ? 15 : 0), 48 - row * 31);
      final kind = treats[i];
      if (kind == 4 || kind == 5) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(const Rect.fromLTWH(-15, -19, 30, 38),
                const Radius.circular(4)),
            Paint()..color = const Color(0xFFB97448));
        canvas.drawRRect(
            RRect.fromRectAndRadius(const Rect.fromLTWH(-11, -15, 22, 30),
                const Radius.circular(2)),
            Paint()..color = const Color(0xFF60352D));
      } else if (kind == 2 || kind == 3) {
        final paint = Paint()
          ..color =
              kind == 2 ? const Color(0xFFEF6380) : const Color(0xFF75D69A);
        canvas.drawOval(const Rect.fromLTWH(-13, -12, 26, 34), paint);
        canvas.drawCircle(const Offset(-8, -12), 7, paint);
        canvas.drawCircle(const Offset(8, -12), 7, paint);
      } else {
        final p = Paint()..color = const Color(0xFFC68A3F);
        canvas.drawCircle(Offset.zero, 20, p);
        p.color = kind == 9 ? const Color(0xFFFFD477) : const Color(0xFFFFF1CB);
        canvas.drawCircle(const Offset(-8, 0), 14, p);
        canvas.drawCircle(const Offset(6, -9), 15, p);
        canvas.drawCircle(const Offset(10, 9), 13, p);
        canvas.drawCircle(const Offset(-3, 12), 13, p);
      }
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BasketPainter oldDelegate) => true;
}
