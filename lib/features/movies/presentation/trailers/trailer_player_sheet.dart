import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// Accepts the ID-only detail response and the URL-shaped Home response.
String? trailerVideoId(String source) {
  final text = source.trim();
  final idPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');
  if (idPattern.hasMatch(text)) return text;
  final uri = Uri.tryParse(text);
  if (uri == null || !['https', 'http'].contains(uri.scheme)) return null;
  final host = uri.host.toLowerCase();
  String? id;
  if (host == 'youtu.be') {
    id = uri.pathSegments.firstOrNull;
  } else if ([
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'youtube-nocookie.com',
    'www.youtube-nocookie.com'
  ].contains(host)) {
    if (uri.path == '/watch') id = uri.queryParameters['v'];
    if (uri.pathSegments.length == 2 &&
        ['embed', 'shorts', 'live'].contains(uri.pathSegments.first)) {
      id = uri.pathSegments[1];
    }
  }
  return id != null && idPattern.hasMatch(id) ? id : null;
}

Future<void> showTrailerPlayerSheet(
  BuildContext context, {
  required String source,
  String title = 'Trailer',
  @visibleForTesting Widget Function(String videoId)? playerBuilder,
}) async {
  final id = trailerVideoId(source);
  if (id == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This trailer is unavailable.')),
    );
    return;
  }
  try {
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 160),
        reverseTransitionDuration: const Duration(milliseconds: 160),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        pageBuilder: (context, animation, secondaryAnimation) =>
            _TrailerTransition(
          waitForRotation: playerBuilder == null,
          builder: (context) => Scaffold(
            backgroundColor: Colors.black,
            body: Stack(fit: StackFit.expand, children: [
              Positioned.fill(
                  child: LayoutBuilder(builder: (context, constraints) {
                final width = constraints.maxWidth
                    .clamp(0.0, constraints.maxHeight * 16 / 9);
                return Center(
                    child: SizedBox(
                        width: width,
                        child: playerBuilder?.call(id) ??
                            _TrailerPlayer(videoId: id)));
              })),
              Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                      child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                    child: Row(children: [
                      Expanded(
                          child: Text(title,
                              style: const TextStyle(color: Colors.white))),
                      IconButton(
                          tooltip: 'Close trailer',
                          color: Colors.white,
                          onPressed: () => _closeTrailer(context),
                          icon: const Icon(Icons.close)),
                    ]),
                  ))),
              Positioned(
                  bottom: 8,
                  right: 16,
                  child: SafeArea(
                      child: TextButton.icon(
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.black87),
                    onPressed: () async {
                      try {
                        final opened = await launchUrl(
                            Uri.https('www.youtube.com', '/watch', {'v': id}),
                            mode: LaunchMode.externalApplication);
                        if (opened && context.mounted) {
                          _closeTrailer(context);
                        }
                        if (!opened && context.mounted) _launchError(context);
                      } catch (_) {
                        if (context.mounted) _launchError(context);
                      }
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open in YouTube'),
                  ))),
            ]),
          ),
        ),
      ),
    );
  } finally {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
}

void _launchError(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Couldn’t open YouTube. Please try again.')),
  );
}

class _TrailerPlayer extends StatefulWidget {
  const _TrailerPlayer({required this.videoId});
  final String videoId;
  @override
  State<_TrailerPlayer> createState() => _TrailerPlayerState();
}

class _TrailerPlayerState extends State<_TrailerPlayer>
    with WidgetsBindingObserver {
  late final YoutubePlayerController _controller;
  StreamSubscription<YoutubePlayerValue>? _subscription;
  Timer? _timeout;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        strictRelatedVideos: true,
        showControls: true,
        showFullscreenButton: false,
      ),
    );
    _subscription = _controller.stream.listen((value) {
      if (value.playerState != PlayerState.unknown) _timeout?.cancel();
      if (value.hasError && mounted && !_failed) setState(() => _failed = true);
    });
    _timeout = Timer(const Duration(seconds: 20), () {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(_controller.pauseVideo());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timeout?.cancel();
    unawaited(_subscription?.cancel());
    unawaited(_controller.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _failed
      ? const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
              'This trailer couldn’t play here. Try opening it in YouTube.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white)),
        )
      : YoutubePlayer(
          controller: _controller,
          controlsBuilder: (context, isFullscreen) => Align(
            alignment: Alignment.topRight,
            child: SafeArea(
                child: Padding(
              padding: const EdgeInsets.all(8),
              child: Material(
                color: Colors.black87,
                shape: const CircleBorder(),
                child: IconButton(
                    tooltip: 'Close trailer',
                    color: Colors.white,
                    onPressed: () => _closeTrailer(this.context),
                    icon: const Icon(Icons.close)),
              ),
            )),
          ),
          autoFullScreen: false,
          enableFullScreenOnVerticalDrag: false,
        );
}

void _closeTrailer(BuildContext context) {
  context.findAncestorStateOfType<_TrailerTransitionState>()?.close();
}

class _TrailerTransition extends StatefulWidget {
  const _TrailerTransition(
      {required this.builder, required this.waitForRotation});
  final WidgetBuilder builder;
  final bool waitForRotation;
  @override
  State<_TrailerTransition> createState() => _TrailerTransitionState();
}

class _TrailerTransitionState extends State<_TrailerTransition>
    with WidgetsBindingObserver {
  bool _ready = false;
  bool _closing = false;
  bool _canPop = false;
  Orientation? _waitingFor;
  Completer<void>? _rotation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    // Cover Home completely before rotating the native window.
    await Future<void>.delayed(const Duration(milliseconds: 170));
    if (!mounted || _closing) return;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await _waitFor(Orientation.landscape);
    if (mounted && !_closing) setState(() => _ready = true);
  }

  Future<void> _waitFor(Orientation orientation) async {
    if (!mounted || !widget.waitForRotation) return;
    _waitingFor = orientation;
    _rotation = Completer<void>();
    didChangeMetrics();
    await _rotation!.future
        .timeout(const Duration(seconds: 1), onTimeout: () {});
    _waitingFor = null;
    // Allow iOS's native rotation animation to settle behind the black cover.
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  @override
  void didChangeMetrics() {
    if (!mounted || _waitingFor == null || _rotation!.isCompleted) return;
    final size = View.of(context).physicalSize;
    final orientation =
        size.width > size.height ? Orientation.landscape : Orientation.portrait;
    if (orientation == _waitingFor) _rotation!.complete();
  }

  Future<void> close() async {
    if (_closing) return;
    setState(() {
      _closing = true;
      _ready = false;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await _waitFor(Orientation.portrait);
    if (!mounted) return;
    setState(() => _canPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_rotation != null && !_rotation!.isCompleted) _rotation!.complete();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: _canPop,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) close();
        },
        child: ColoredBox(
            color: Colors.black,
            child: _ready
                ? Builder(builder: widget.builder)
                : const SizedBox.expand()),
      );
}
