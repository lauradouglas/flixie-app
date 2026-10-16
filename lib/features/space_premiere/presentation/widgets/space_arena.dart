import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/space_engine.dart';
import '../controllers/space_controller.dart';

class SpaceArena extends StatelessWidget {
  const SpaceArena({super.key, required this.controller});
  final SpaceController controller;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final scale = math.min(box.maxWidth / 360, box.maxHeight / 520);
        return Center(
            child: SizedBox(
          width: 360 * scale,
          height: 520 * scale,
          child: Semantics(
            label:
                'Space arena. Drag left or right to steer Pip. Firing is automatic.',
            onIncrease: () => controller.moveTo(controller.engine.targetX + 40),
            onDecrease: () => controller.moveTo(controller.engine.targetX - 40),
            child: GestureDetector(
              key: const ValueKey('space-steering'),
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) =>
                  controller.moveTo(details.localPosition.dx / scale),
              onPanUpdate: (details) =>
                  controller.moveTo(details.localPosition.dx / scale),
              child: RepaintBoundary(
                  child: ListenableBuilder(
                listenable: controller.frame,
                child: Image.asset('assets/images/space_premiere/pip-ship.png',
                    fit: BoxFit.contain,
                    cacheWidth: 256,
                    excludeFromSemantics: true),
                builder: (context, ship) =>
                    Stack(fit: StackFit.expand, children: [
                  CustomPaint(painter: _SpacePainter(controller.engine)),
                  Positioned(
                      left: (controller.engine.x - 30) * scale,
                      top: 457 * scale,
                      width: 60 * scale,
                      height: 44 * scale,
                      child: ship!),
                ]),
              )),
            ),
          ),
        ));
      });
}

class _SpacePainter extends CustomPainter {
  _SpacePainter(this.engine);
  final SpaceEngine engine;
  static const patterns = [
    [
      '001101100',
      '011111110',
      '111111111',
      '110101011',
      '111111111',
      '001111100',
      '011000110'
    ],
    [
      '000010000',
      '110111011',
      '111111111',
      '011010110',
      '111111111',
      '110111011',
      '000101000'
    ],
    [
      '011000110',
      '111101111',
      '111111111',
      '110101011',
      '011111110',
      '001111100',
      '011000110'
    ],
  ];
  static const colors = [
    Color(0xFFFFD36D),
    Color(0xFFFF7AA6),
    Color(0xFF6EE8ED)
  ];
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 360, size.height / 520);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 360, 520),
        Paint()..color = const Color(0xFF090B23));
    final star = Paint();
    for (var i = 0; i < 65; i++) {
      star.color =
          i % 3 == 0 ? const Color(0xFF7359BD) : const Color(0xFFB8D5EC);
      canvas.drawRect(
          Rect.fromLTWH((i * 67 % 358).toDouble(), (i * 109 % 516).toDouble(),
              i % 7 == 0 ? 2 : 1, 1),
          star);
    }
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF31235A);
    canvas.drawCircle(const Offset(330, 340), 62, ring);
    canvas.drawOval(const Rect.fromLTWH(242, 325, 176, 30), ring);
    for (final enemy in engine.invaders) {
      final pattern = patterns[enemy.row];
      final paint = Paint()..color = colors[enemy.row];
      for (var row = 0; row < pattern.length; row++) {
        for (var col = 0; col < pattern[row].length; col++) {
          if (pattern[row][col] == '1') {
            final foot = row == pattern.length - 1 && (engine.ticks ~/ 18).isOdd
                ? 1.5
                : 0.0;
            canvas.drawRect(
                Rect.fromLTWH(enemy.x - 12 + col * 2.7 + foot,
                    enemy.y - 9 + row * 2.7, 2.7, 2.7),
                paint);
          }
        }
      }
    }
    for (final shield in engine.shields) {
      if (shield.health == 0) continue;
      final paint = Paint()..color = const Color(0xFF78E9CB);
      for (var row = 0; row < 3; row++) {
        for (var col = 0; col < 6; col++) {
          if ((row == 2 && (col == 2 || col == 3)) ||
              (row == 0 && (col == 0 || col == 5)) ||
              (row + col) % 4 >= shield.health) {
            continue;
          }
          canvas.drawRect(
              Rect.fromLTWH(shield.x - 24 + col * 8, 394 + row * 7, 7, 6),
              paint);
        }
      }
    }
    final bolt = Paint()..color = const Color(0xFFFFE692);
    for (final shot in engine.shots) {
      canvas.drawRect(
          Rect.fromCenter(center: Offset(shot.x, shot.y), width: 3, height: 10),
          bolt);
    }
    bolt.color = const Color(0xFFFF799D);
    for (final shot in engine.enemyShots) {
      canvas.drawRect(
          Rect.fromCenter(center: Offset(shot.x, shot.y), width: 4, height: 9),
          bolt);
    }
    if (engine.invulnerable > 0) {
      canvas.drawOval(
          Rect.fromCenter(center: Offset(engine.x, 479), width: 64, height: 47),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFF6EE8ED));
    }
    canvas.drawLine(
        const Offset(10, 510),
        const Offset(350, 510),
        Paint()
          ..color = const Color(0xFF7250AB)
          ..strokeWidth = 1);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpacePainter oldDelegate) => true;
}
