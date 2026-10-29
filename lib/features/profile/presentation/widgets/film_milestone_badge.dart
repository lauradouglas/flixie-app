import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/milestone_badge.dart';

/// Collectible medallion. Profile avatar borders remain independent.
class FilmMilestoneBadge extends StatelessWidget {
  const FilmMilestoneBadge(
      {super.key, required this.badge, this.size = 72, this.locked = false});
  final MilestoneBadge badge;
  final double size;
  final bool locked;
  @override
  Widget build(BuildContext context) {
    final colors = switch (badge.metal) {
      'purple' => const [
          Color(0xFFE5CCFF),
          Color(0xFFA36CF0),
          Color(0xFF432178)
        ],
      'gold' => const [Color(0xFFFFE6A1), Color(0xFFDCA83D), Color(0xFF83551B)],
      'silver' => const [
          Color(0xFFF0F3FF),
          Color(0xFFADB6CE),
          Color(0xFF59677F)
        ],
      _ => const [Color(0xFFF4CEA4), Color(0xFFBC8152), Color(0xFF73462E)],
    };
    return Semantics(
        label:
            '${badge.metal} badge, ${badge.label}${locked ? ', locked' : ''}',
        image: true,
        child: ExcludeSemantics(
            child: Opacity(
                opacity: locked ? .45 : 1,
                child: Container(
                    width: size,
                    height: size,
                    padding: EdgeInsets.all(size * .065),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: colors),
                        border: Border.all(color: colors.first, width: 1.5)),
                    child: Container(
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: colors.last.withValues(alpha: .6),
                                width: 1)),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CustomPaint(
                                  size: Size.square(size * .32),
                                  painter: _FilmReelPainter(
                                      colors.last, colors.first)),
                              SizedBox(
                                  width: size * .7,
                                  height: size * .22,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                        badge.target == 50
                                            ? '50'
                                            : '${badge.target}+',
                                        textScaler: TextScaler.noScaling,
                                        style: TextStyle(
                                            color: colors.last,
                                            fontSize: size * .19,
                                            fontWeight: FontWeight.w800,
                                            height: 1)),
                                  )),
                            ]))))));
  }
}

class _FilmReelPainter extends CustomPainter {
  const _FilmReelPainter(this.ink, this.holes);
  final Color ink, holes;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero), radius = size.width * .46;
    canvas.drawCircle(center, radius, Paint()..color = ink);
    final cutout = Paint()..color = holes;
    canvas.drawCircle(center, radius * .12, cutout);
    for (var i = 0; i < 5; i++) {
      final angle = i * math.pi * 2 / 5 - math.pi / 2;
      canvas.drawCircle(
          center + Offset(math.cos(angle), math.sin(angle)) * radius * .6,
          radius * .21,
          cutout);
    }
    canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy + radius)
          ..quadraticBezierTo(size.width * .8, size.height * 1.03, size.width,
              size.height * .88),
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * .08);
  }

  @override
  bool shouldRepaint(covariant _FilmReelPainter oldDelegate) =>
      oldDelegate.ink != ink || oldDelegate.holes != holes;
}
