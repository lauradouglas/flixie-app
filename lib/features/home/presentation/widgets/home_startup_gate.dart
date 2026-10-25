import 'dart:async';
import 'package:flixie_app/core/auth/startup_trace.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/pip_startup_brand.dart';

/// Holds the first Home reveal, never later refreshes, with an explicit slow-connection escape.
class HomeStartupGate extends StatefulWidget {
  const HomeStartupGate(
      {super.key,
      required this.ready,
      required this.child,
      this.onRevealed,
      this.maxWait = const Duration(seconds: 20)});
  final bool ready;
  final Widget child;
  final VoidCallback? onRevealed;
  final Duration maxWait;
  @override
  State<HomeStartupGate> createState() => _HomeStartupGateState();
}

class _HomeStartupGateState extends State<HomeStartupGate> {
  final _overlay = OverlayPortalController();
  Timer? _deadline;
  bool _revealed = false;
  bool _takingLong = false;
  @override
  void initState() {
    super.initState();
    _revealed = widget.ready;
    if (_revealed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onRevealed?.call();
      });
    }
    if (!_revealed) {
      _overlay.show();
      _deadline = Timer(widget.maxWait, () {
        if (mounted && !_revealed) setState(() => _takingLong = true);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A background Home branch must never cover a direct link or another tab.
    if (!TickerMode.valuesOf(context).enabled) _scheduleReveal();
  }

  @override
  void didUpdateWidget(HomeStartupGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ready) _scheduleReveal();
  }

  void _scheduleReveal() {
    if (_revealed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reveal();
    });
  }

  void _reveal() {
    if (!mounted || _revealed) return;
    _deadline?.cancel();
    StartupTrace.mark('home.revealed');
    widget.onRevealed?.call();
    _overlay.hide();
    setState(() => _revealed = true);
  }

  @override
  void dispose() {
    _deadline?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
        overlayLocation: OverlayChildLocation.rootOverlay,
        controller: _overlay,
        overlayChildBuilder: (_) => Positioned.fill(
            child: Scaffold(
          backgroundColor: context.colors.background,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const PipStartupBrand(),
                  if (_takingLong) ...[
                    const SizedBox(height: 24),
                    const Text('Taking a little longer to load…',
                        textAlign: TextAlign.center),
                    TextButton(
                        onPressed: _reveal,
                        child: const Text('Continue to Home')),
                  ],
                ]),
              ),
            ),
          ),
        )),
        child: ExcludeSemantics(excluding: !_revealed, child: widget.child),
      );
}
