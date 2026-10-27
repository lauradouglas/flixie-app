import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Extends the actual edge pixels behind the intact, proportionally fitted
/// poster. The background is spatial image content, not a dominant-colour wash.
class BlendedSharePoster extends StatelessWidget {
  const BlendedSharePoster({super.key, this.image});
  final ui.Image? image;

  @override
  Widget build(BuildContext context) => CustomPaint(
        key: const ValueKey('blended-share-poster'),
        painter: _PosterPainter(image),
        child: image == null
            ? const Center(
                child: Text('Poster unavailable',
                    style: TextStyle(color: Colors.white70, fontSize: 13)))
            : null,
      );
}

class _PosterPainter extends CustomPainter {
  _PosterPainter(this.image);
  final ui.Image? image;

  @override
  void paint(Canvas canvas, Size size) {
    final image = this.image;
    if (image == null || size.isEmpty) return;
    final source =
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final fitted = applyBoxFit(BoxFit.contain, source.size, size);
    final target =
        Alignment.center.inscribe(fitted.destination, Offset.zero & size);
    final paint = Paint()..filterQuality = FilterQuality.high;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // Extend the nearest edge into each empty band. A soft blur removes
    // stretched detail while preserving the poster's local background tones.
    canvas.saveLayer(Offset.zero & size,
        Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10));
    if (target.left > 0) {
      canvas.drawImageRect(image, Rect.fromLTWH(0, 0, 1, source.height),
          Rect.fromLTRB(0, target.top, target.left + 2, target.bottom), paint);
      canvas.drawImageRect(
          image,
          Rect.fromLTWH(source.width - 1, 0, 1, source.height),
          Rect.fromLTRB(
              target.right - 2, target.top, size.width, target.bottom),
          paint);
    }
    if (target.top > 0) {
      canvas.drawImageRect(image, Rect.fromLTWH(0, 0, source.width, 1),
          Rect.fromLTRB(target.left, 0, target.right, target.top + 2), paint);
      canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, source.height - 1, source.width, 1),
          Rect.fromLTRB(
              target.left, target.bottom - 2, target.right, size.height),
          paint);
    }
    canvas.drawImageRect(image, source, target, paint);
    canvas.restore();
    canvas.saveLayer(target, Paint());
    canvas.drawImageRect(image, source, target, paint);
    // Feather only the boundary; the subject keeps its original geometry.
    canvas.drawRect(
        target,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = const LinearGradient(
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent
            ],
            stops: [0, .035, .965, 1],
          ).createShader(target));
    canvas.drawRect(
        target,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent
            ],
            stops: [0, .025, .92, 1],
          ).createShader(target));
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PosterPainter oldDelegate) => oldDelegate.image != image;
}
