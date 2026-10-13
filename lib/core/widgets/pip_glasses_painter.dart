import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Independently drawn facial layers over the approved clean character base.
class PipGlassesPainter extends CustomPainter {
  PipGlassesPainter(this.image, this.motion, {this.basePainter})
      : super(repaint: motion);
  final CustomPainter? basePainter;
  final ui.Image image;
  final Animation<double> motion;
  static const ink = Color(0xFF32063F);
  double ease(double value) {
    final x = value.clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = motion.value * 8;
    final surprise = ease((t - 2) / .35) * (1 - ease((t - 3.8) / .35));
    final grin = ease((t - 3.8) / .35) * (1 - ease((t - 7.5) / .45));
    basePainter?.paint(canvas, size);
    final fit = min(size.width / 1223, size.height / 1286);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(
        (size.width - 1223 * fit) / 2, (size.height - 1286 * fit) / 2);
    canvas.scale(fit);

    if (basePainter == null) {
      canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          const Rect.fromLTWH(0, 0, 1223, 1286),
          Paint());
    }
    brow(canvas, 491, 429, -.46 + surprise * .1 - grin * .06,
        surprise * 19 + grin * 5);
    brow(canvas, 733, 361, -.02 - surprise * .12, surprise * 24 + grin * 7);
    mouth(canvas, 0, 1 - max(surprise, grin));
    mouth(canvas, 1, surprise);
    mouth(canvas, 2, grin);
    canvas.restore();
  }

  void brow(Canvas c, double x, double y, double rotation, double raise) {
    c.save();
    c.translate(x, y - raise);
    c.rotate(rotation);
    final path = Path()
      ..moveTo(-47, 8)
      ..cubicTo(-38, -26, 24, -34, 48, -9)
      ..cubicTo(54, 3, 42, 12, 26, 6)
      ..cubicTo(-5, 0, -25, 8, -41, 15)
      ..cubicTo(-46, 17, -51, 13, -47, 8);
    c.drawPath(path, Paint()..color = ink);
    c.restore();
  }

  void mouth(Canvas c, int kind, double opacity) {
    if (opacity < .001) return;
    c.save();
    c.translate(662, 662);
    c.rotate(-.18);
    final p = Paint()
      ..color = ink.withValues(alpha: opacity)
      ..strokeCap = StrokeCap.round;
    if (kind == 0) {
      c.drawPath(
          Path()
            ..moveTo(-30, -4)
            ..quadraticBezierTo(0, 15, 30, -4),
          p
            ..style = PaintingStyle.stroke
            ..strokeWidth = 9);
    }
    if (kind == 1) {
      c.drawOval(const Rect.fromLTWH(-25, -31, 50, 72), p);
      c.drawOval(const Rect.fromLTWH(-9, 23, 20, 10),
          Paint()..color = const Color(0xFFFFB2C1).withValues(alpha: opacity));
    }
    if (kind == 2) {
      final shape = Path()
        ..moveTo(-45, -18)
        ..quadraticBezierTo(0, 5, 45, -18)
        ..cubicTo(42, 14, 25, 45, 0, 46)
        ..cubicTo(-25, 45, -40, 18, -45, -18)
        ..close();
      c.drawPath(shape, p);
      c.save();
      c.clipPath(shape);
      c.translate(-3, 40);
      c.rotate(-.2);
      c.drawOval(const Rect.fromLTWH(-29, -18, 58, 36),
          Paint()..color = const Color(0xFFFF8FAB).withValues(alpha: opacity));
      c.restore();
    }
    c.restore();
  }

  @override
  bool shouldRepaint(PipGlassesPainter previous) =>
      image != previous.image || motion != previous.motion;
}
