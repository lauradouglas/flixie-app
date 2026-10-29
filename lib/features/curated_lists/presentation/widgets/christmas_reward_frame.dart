import 'package:flutter/material.dart';

/// Decorative trim stays outside the reward copy and never handles input.
class ChristmasRewardFrame extends StatelessWidget {
  const ChristmasRewardFrame(
      {super.key,
      required this.child,
      required this.enabled,
      this.showSnow = true,
      this.borderRadius = 14});
  final Widget child;
  final bool enabled, showSnow;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(children: [
          child,
          Positioned.fill(
              child: IgnorePointer(
                  child: ExcludeSemantics(
                      child: CustomPaint(
                          painter:
                              _ChristmasTrimPainter(showSnow: showSnow))))),
        ]));
  }
}

class _ChristmasTrimPainter extends CustomPainter {
  const _ChristmasTrimPainter({required this.showSnow});
  final bool showSnow;
  static const _bulbs = [
    Color(0xFFFF4747),
    Color(0xFFFFE441),
    Color(0xFF38DD77),
    Color(0xFF4BBDFF)
  ];
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 40 || size.height < 30) return;
    final paint = Paint()..isAntiAlias = true;
    final span = size.width - 28;
    double cableY(double t) {
      final segment = t * 4;
      final u = segment - segment.floor();
      return 3 + 3.5 * 4 * u * (1 - u);
    }

    final wire = Path()
      ..moveTo(-3, 18)
      ..cubicTo(3, 15, 5, 0, 14, cableY(0));
    for (var i = 1; i <= 96; i++) {
      final t = i / 96;
      wire.lineTo(14 + span * t, cableY(t));
    }
    wire.cubicTo(size.width - 5, 0, size.width - 3, 15, size.width + 3, 18);
    canvas.drawPath(
        wire,
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = .9
          ..color = const Color(0xFF305D43));
    canvas.drawPath(
        wire,
        paint
          ..strokeWidth = .3
          ..color = const Color(0xFF8AA77A));
    final count = (span / 25).floor().clamp(6, 26);
    for (var i = 0; i < count; i++) {
      final t = (i + .5) / count;
      final x = 14 + span * t;
      final y = cableY(t);
      final hang = i.isEven ? 1.5 : 2.5;
      final top = y + hang + 2;
      final colour = _bulbs[i % _bulbs.length];
      canvas.drawLine(
          Offset(x, y),
          Offset(x, top),
          paint
            ..style = PaintingStyle.stroke
            ..color = const Color(0xFF305D43)
            ..strokeWidth = .8);
      canvas.save();
      canvas.translate(x, top);
      canvas.scale(.64);
      canvas.translate(-x, -top);
      canvas.drawCircle(
          Offset(x, top + 5),
          6.5,
          Paint()
            ..color = colour.withValues(alpha: .4)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5));
      final glass = Path()
        ..moveTo(x - 2.2, top)
        ..cubicTo(x - 3.6, top + 2, x - 4, top + 5, x - 2.5, top + 8)
        ..quadraticBezierTo(x, top + 12, x + 2.5, top + 8)
        ..cubicTo(x + 4, top + 5, x + 3.6, top + 2, x + 2.2, top)
        ..close();
      canvas.drawPath(
          glass,
          Paint()
            ..shader = RadialGradient(
                center: const Alignment(-.3, -.3),
                radius: 1,
                colors: [
                  Color.lerp(Colors.white, colour, .25)!,
                  colour,
                  Color.lerp(colour, Colors.black, .28)!
                ],
                stops: const [
                  0,
                  .45,
                  1
                ]).createShader(Rect.fromLTWH(x - 4, top, 8, 11)));
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x - 2.1, top - 1.8, 4.2, 2.5),
              const Radius.circular(.6)),
          Paint()..color = const Color(0xFF315A3F));
      canvas.drawOval(Rect.fromLTWH(x - 1.5, top + 2, 1.5, 3.5),
          Paint()..color = Colors.white.withValues(alpha: .85));
      canvas.restore();
    }
    if (!showSnow) return;
    final snow = Path()..moveTo(0, size.height - 4);
    var x = 0.0;
    while (x < size.width) {
      snow.quadraticBezierTo(x + 10, size.height - 10, x + 20, size.height - 5);
      snow.quadraticBezierTo(x + 30, size.height - 2, x + 40, size.height - 5);
      x += 40;
    }
    snow.lineTo(size.width, size.height);
    snow.lineTo(0, size.height);
    snow.close();
    canvas.drawPath(
        snow,
        paint
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFE5ECF5));
  }

  @override
  bool shouldRepaint(covariant _ChristmasTrimPainter oldDelegate) =>
      oldDelegate.showSnow != showSnow;
}
