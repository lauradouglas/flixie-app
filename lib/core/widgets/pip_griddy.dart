import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Hoodie Pip's looping heel taps. The image owns the articulated poses;
/// the painter only supplies the small continuous bounce between those poses.
class PipGriddy extends StatefulWidget {
  const PipGriddy({super.key, this.size = 220});
  static const asset = 'assets/splash/pip/hoodie-griddy-sheet.png';
  final double size;
  @override
  State<PipGriddy> createState() => _PipGriddyState();
}

class _PipGriddyState extends State<PipGriddy>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _motion = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3200));
  static final _phaseClock = Stopwatch();
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ui.Image? _image;
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stream == null) {
      _stream = const AssetImage(PipGriddy.asset)
          .resolve(createLocalImageConfiguration(context));
      _listener = ImageStreamListener((info, _) {
        if (!mounted) return;
        _image?.dispose();
        setState(() => _image = info.image.clone());
        _phaseClock.start();
        _motion.value = (_phaseClock.elapsedMilliseconds % 3200) / 3200;
        _syncMotion();
      }, onError: (Object error, StackTrace? stack) {
        // Keep the real hoodie artwork visible if sprite decoding fails.
      });
      _stream!.addListener(_listener!);
    }
    _syncMotion();
  }

  void _syncMotion() {
    if (_image != null &&
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context)) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.stop();
      if (MediaQuery.disableAnimationsOf(context)) _motion.value = 0;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_listener != null) _stream?.removeListener(_listener!);
    _image?.dispose();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
      label: 'Pip dances the Griddy in his Flixie hoodie',
      image: true,
      child: SizedBox.square(
          dimension: widget.size,
          child: RepaintBoundary(
              child: _image == null
                  ? Image.asset('assets/splash/pip/launch-frame.png',
                      fit: BoxFit.contain, excludeFromSemantics: true)
                  : CustomPaint(
                      painter: PipGriddyPainter(_image!, _motion,
                          reducedMotion:
                              MediaQuery.disableAnimationsOf(context))))));
}

class PipGriddyPainter extends CustomPainter {
  PipGriddyPainter(this.image, this.motion, {required this.reducedMotion})
      : super(repaint: motion);
  final ui.Image image;
  final Animation<double> motion;
  final bool reducedMotion;
  int get frame => reducedMotion ? 0 : (motion.value * 16).floor().clamp(0, 15);
  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = image.width / 4, cellHeight = image.height / 4;
    final source = Rect.fromLTWH((frame % 4) * cellWidth,
        (frame ~/ 4) * cellHeight, cellWidth, cellHeight);
    final side = math.min(size.width, size.height);
    final bounce = reducedMotion
        ? 0.0
        : math.sin(motion.value * math.pi * 8).abs() * side * .012;
    final destination = Rect.fromLTWH(
        (size.width - side) / 2, (size.height - side) / 2 - bounce, side, side);
    canvas.drawImageRect(image, source, destination,
        Paint()..filterQuality = FilterQuality.medium);
  }

  @override
  bool shouldRepaint(covariant PipGriddyPainter old) =>
      old.image != image ||
      old.motion != motion ||
      old.reducedMotion != reducedMotion;
}
