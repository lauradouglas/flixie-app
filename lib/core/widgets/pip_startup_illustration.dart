import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'pip_glasses_painter.dart';

/// Gentle facial animation; the confused error pose only blinks its eyes.
class PipStartupIllustration extends StatefulWidget {
  const PipStartupIllustration(
      {super.key, required this.asset, required this.size});
  final String asset;
  final double size;
  @override
  State<PipStartupIllustration> createState() => _PipStartupIllustrationState();
}

class _PipStartupIllustrationState extends State<PipStartupIllustration>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 5200));
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ui.Image? _image;
  bool get _glasses => widget.asset.endsWith('/glasses.png');
  String get _baseAsset =>
      _glasses ? 'assets/splash/pip/glasses-clean-face.png' : widget.asset;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stream == null) {
      _stream = AssetImage(_baseAsset)
          .resolve(createLocalImageConfiguration(context));
      _listener = ImageStreamListener((info, _) {
        if (!mounted) return;
        _image?.dispose();
        setState(() => _image = info.image.clone());
      });
      _stream!.addListener(_listener!);
    }
    if (!MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled) {
      if (!_motion.isAnimating) {
        _motion.duration = Duration(milliseconds: _glasses ? 8000 : 5200);
        _motion.repeat();
      }
    } else {
      _motion.stop();
      _motion.value = 0;
    }
  }

  @override
  void dispose() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _image?.dispose();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: widget.size,
        child: _image != null
            ? RepaintBoundary(
                child: CustomPaint(
                    painter: _glasses
                        ? PipGlassesPainter(_image!, _motion,
                            basePainter:
                                _PipFacePainter(_image!, _motion, widget.asset))
                        : _PipFacePainter(_image!, _motion, widget.asset)))
            : Image.asset(widget.asset,
                fit: BoxFit.contain,
                cacheWidth: 640,
                excludeFromSemantics: true),
      );
}

class _PipFacePainter extends CustomPainter {
  _PipFacePainter(this.image, this.motion, this.asset) : super(repaint: motion);
  final ui.Image image;
  final Animation<double> motion;
  final String asset;
  static const grid = 36;
  static final _indices = Uint16List.fromList([
    for (var y = 0; y < grid; y++)
      for (var x = 0; x < grid; x++) ...[
        y * (grid + 1) + x,
        y * (grid + 1) + x + 1,
        (y + 1) * (grid + 1) + x,
        y * (grid + 1) + x + 1,
        (y + 1) * (grid + 1) + x + 1,
        (y + 1) * (grid + 1) + x,
      ]
  ]);
  double field(double x, double y, double cx, double cy, double rx, double ry) {
    final distance = pow((x - cx) / rx, 2) + pow((y - cy) / ry, 2);
    if (distance >= 1) return 0;
    return pow(1 - distance, 2).toDouble();
  }

  void paintErrorBlink(Canvas canvas, Size size) {
    final fit = min(size.width / image.width, size.height / image.height);
    canvas.save();
    canvas.translate((size.width - image.width * fit) / 2,
        (size.height - image.height * fit) / 2);
    canvas.scale(fit);
    canvas.drawImage(image, Offset.zero, Paint());
    final blink = exp(-pow((motion.value * 5.2 - 2.65) / .12, 2));
    if (blink > .001) {
      for (final eye in [
        Rect.fromLTWH(image.width * .325, image.height * .397,
            image.width * .135, image.height * .135),
        Rect.fromLTWH(image.width * .491, image.height * .364,
            image.width * .14, image.height * .14),
      ]) {
        canvas.save();
        canvas.clipPath(Path()..addOval(eye));
        // Close only the eye patch: the original face, eyebrows and props
        // remain untouched instead of being pulled by a deformation mesh.
        canvas.drawRect(
            eye,
            Paint()
              ..shader = const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xff8946ff), Color(0xff9149ff)],
              ).createShader(eye));
        final squeezed = Rect.fromCenter(
            center: eye.center,
            width: eye.width,
            height: eye.height * (1 - .98 * blink));
        canvas.drawImageRect(image, eye, squeezed,
            Paint()..filterQuality = FilterQuality.medium);
        if (blink > .8) {
          final lid = Path()
            ..moveTo(eye.left + eye.width * .08, eye.center.dy)
            ..quadraticBezierTo(eye.center.dx, eye.center.dy + eye.height * .08,
                eye.right - eye.width * .08, eye.center.dy);
          canvas.drawPath(
              lid,
              Paint()
                ..color =
                    const Color(0xff3b104a).withValues(alpha: (blink - .8) / .2)
                ..style = PaintingStyle.stroke
                ..strokeWidth = image.width * .006
                ..strokeCap = StrokeCap.round);
        }
        canvas.restore();
      }
    }
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (asset.endsWith('/confused-phone.png')) {
      paintErrorBlink(canvas, size);
      return;
    }
    final seconds = motion.value * 5.2;
    final expression = .5 - .5 * cos(seconds * 2 * pi / 5.2);
    final blink = exp(-pow((seconds - 2.65) / .12, 2));
    final popcorn = asset.endsWith('/popcorn.png');
    final ticket = asset.endsWith('/ticket.png');
    final glasses = asset.endsWith('/glasses.png');
    final eyeA = popcorn
        ? const Offset(.437, .465)
        : ticket
            ? const Offset(.438, .434)
            : glasses
                ? const Offset(.445, .406)
                : const Offset(.432, .434);
    final eyeB = popcorn
        ? const Offset(.628, .412)
        : ticket
            ? const Offset(.630, .385)
            : glasses
                ? const Offset(.631, .358)
                : const Offset(.624, .387);
    final mouth = popcorn
        ? const Offset(.549, .522)
        : ticket
            ? const Offset(.557, .498)
            : glasses
                ? const Offset(.550, .526)
                : const Offset(.530, .487);
    final positions = Float32List((grid + 1) * (grid + 1) * 2);
    final texture = Float32List(positions.length);
    var i = 0;
    for (var y = 0; y <= grid; y++) {
      for (var x = 0; x <= grid; x++) {
        final u = x / grid, v = y / grid;
        final mouthWeight = field(u, v, mouth.dx, mouth.dy, .065, .045);
        final px = u + (u - mouth.dx) * expression * .13 * mouthWeight;
        var py = v;
        // Restrict blinking to the exposed eyes so glasses remain still.
        if (!glasses || v < .483 - .16 * u) {
          py -= (v - eyeA.dy) *
              blink *
              .94 *
              field(u, v, eyeA.dx, eyeA.dy, .102, .088);
          py -= (v - eyeB.dy) *
              blink *
              .94 *
              field(u, v, eyeB.dx, eyeB.dy, .095, .091);
        }
        py -= expression *
            .003 *
            field(u, v, eyeA.dx - .018, eyeA.dy - .112, .075, .028);
        py -= expression *
            .004 *
            field(u, v, eyeB.dx - .004, eyeB.dy - .102, .075, .025);
        py += (v - mouth.dy) * expression * .09 * mouthWeight;
        positions[i] = px * image.width;
        positions[i + 1] = py * image.height;
        texture[i] = u * image.width;
        texture[i + 1] = v * image.height;
        i += 2;
      }
    }
    final fit = min(size.width / image.width, size.height / image.height);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate((size.width - image.width * fit) / 2,
        (size.height - image.height * fit) / 2);
    canvas.scale(fit);
    final shader = ui.ImageShader(image, ui.TileMode.clamp, ui.TileMode.clamp,
        Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]));
    final mesh = ui.Vertices.raw(ui.VertexMode.triangles, positions,
        textureCoordinates: texture, indices: _indices);
    canvas.drawVertices(mesh, BlendMode.srcOver, Paint()..shader = shader);
    mesh.dispose();
    shader.dispose();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PipFacePainter oldDelegate) =>
      image != oldDelegate.image ||
      motion != oldDelegate.motion ||
      asset != oldDelegate.asset;
}
