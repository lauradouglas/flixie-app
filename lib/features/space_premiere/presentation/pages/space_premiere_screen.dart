import 'package:flixie_app/features/pip_games/audio/game_audio.dart';
import 'package:flixie_app/features/pip_games/presentation/widgets/game_audio_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/core/widgets/flixie_wordmark.dart';
import '../../domain/space_engine.dart';
import '../controllers/space_controller.dart';
import '../widgets/space_arena.dart';

class SpacePremiereScreen extends StatefulWidget {
  const SpacePremiereScreen({super.key, this.controller});
  final SpaceController? controller;
  @override
  State<SpacePremiereScreen> createState() => _SpacePremiereScreenState();
}

class _SpacePremiereScreenState extends State<SpacePremiereScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final SpaceController c = widget.controller ?? SpaceController();
  late final Ticker _ticker;
  final _focus = FocusNode();
  final _audio = GameAudioSession('space');
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker((elapsed) {
      final delta = elapsed - _last;
      _last = elapsed;
      c.advance(delta);
    });
    c.onSound = _audio.play;
    c.addListener(_syncTicker);
    _syncTicker();
  }

  void _syncTicker() {
    _audio.setPlaying(c.engine.phase == SpacePhase.playing);
    if (c.engine.phase == SpacePhase.playing && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (c.engine.phase != SpacePhase.playing && _ticker.isActive) {
      _ticker.stop();
      _last = Duration.zero;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) c.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.removeListener(_syncTicker);
    c.onSound = null;
    _audio.close();
    _ticker.dispose();
    _focus.dispose();
    if (widget.controller == null) c.dispose();
    super.dispose();
  }

  void _close() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      GoRouter.of(context).go('/play');
    }
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      c.moveTo(c.engine.targetX - 32);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      c.moveTo(c.engine.targetX + 32);
    } else if (event.logicalKey == LogicalKeyboardKey.space &&
        event is KeyDownEvent) {
      if (c.engine.phase == SpacePhase.playing) {
        c.pause();
      } else if (c.engine.phase == SpacePhase.paused) {
        c.resume();
      }
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => GameAudioBoundary(
      audio: _audio,
      child: Theme(
        data: Theme.of(context).copyWith(
            brightness: Brightness.dark,
            colorScheme: const ColorScheme.dark(
                primary: Color(0xFFFFD36D),
                onPrimary: Color(0xFF231036),
                surface: Color(0xFF15112B),
                onSurface: Color(0xFFFFF0C8)),
            textTheme: Theme.of(context).textTheme.apply(
                bodyColor: const Color(0xFFFFF0C8),
                displayColor: const Color(0xFFFFF0C8))),
        child: Scaffold(
          backgroundColor: const Color(0xFF090B23),
          appBar: AppBar(
            backgroundColor: const Color(0xFF090B23),
            foregroundColor: const Color(0xFFFFF0C8),
            leading: IconButton(
                tooltip: 'Back to games',
                onPressed: _close,
                icon: const Icon(Icons.close_rounded)),
            title: const FlixieWordmark(foregroundColor: Colors.white),
            centerTitle: true,
            actions: [
              GameAudioButton(onOpen: c.pause),
              ListenableBuilder(
                  listenable: c,
                  builder: (context, _) => IconButton(
                      tooltip: c.engine.phase == SpacePhase.paused
                          ? 'Resume game'
                          : 'Pause game',
                      onPressed: c.engine.phase == SpacePhase.playing
                          ? c.pause
                          : c.engine.phase == SpacePhase.paused
                              ? c.resume
                              : null,
                      icon: Icon(c.engine.phase == SpacePhase.paused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded)))
            ],
          ),
          body: SafeArea(
              top: false,
              child: Focus(
                focusNode: _focus,
                autofocus: true,
                onKeyEvent: _key,
                child: ListenableBuilder(
                    listenable: c,
                    builder: (context, _) => Column(children: [
                          Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 20,
                                  runSpacing: 8,
                                  children: [
                                    Text('SCORE ${c.engine.score}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFFFFD36D))),
                                    Text('WAVE ${c.engine.wave}'),
                                    Semantics(
                                      label: c.engine.practice
                                          ? 'Practice. Unlimited lives'
                                          : '${c.engine.lives} of 3 lives remaining',
                                      child: ExcludeSemantics(
                                          child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (c.engine.practice) ...[
                                            const Icon(Icons.all_inclusive,
                                                color: Color(0xFFFFD36D),
                                                size: 20),
                                            const SizedBox(width: 6),
                                            const Text('Practice'),
                                          ] else
                                            for (var i = 0; i < 3; i++)
                                              Icon(
                                                  i < c.engine.lives
                                                      ? Icons.favorite
                                                      : Icons.favorite_border,
                                                  size: 20,
                                                  color: i < c.engine.lives
                                                      ? const Color(0xFFFF81AA)
                                                      : const Color(
                                                          0xFFC9A9D8)),
                                        ],
                                      )),
                                    ),
                                  ])),
                          Expanded(
                              child: Stack(fit: StackFit.expand, children: [
                            SpaceArena(controller: c),
                            if (c.engine.phase != SpacePhase.playing)
                              _overlay(context),
                          ])),
                          Padding(
                              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                              child: Row(children: [
                                IconButton.filledTonal(
                                    tooltip: 'Move left',
                                    onPressed: () =>
                                        c.moveTo(c.engine.targetX - 48),
                                    icon: const Icon(Icons.arrow_back_rounded)),
                                const SizedBox(width: 8),
                                const Expanded(
                                    child: Text('Drag to steer · Auto fire',
                                        textAlign: TextAlign.center)),
                                const SizedBox(width: 8),
                                IconButton.filledTonal(
                                    tooltip: 'Move right',
                                    onPressed: () =>
                                        c.moveTo(c.engine.targetX + 48),
                                    icon: const Icon(
                                        Icons.arrow_forward_rounded)),
                              ])),
                        ])),
              )),
        ),
      ));

  Widget _overlay(BuildContext context) {
    final e = c.engine;
    final ready = e.phase == SpacePhase.ready;
    final paused = e.phase == SpacePhase.paused;
    final complete = e.phase == SpacePhase.waveComplete;
    return ColoredBox(
        color: const Color(0xE6090B23),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (ready)
                      Image.asset('assets/images/space_premiere/pip-ship.png',
                          height: 110, excludeFromSemantics: true),
                    const SizedBox(height: 12),
                    Text(
                        ready
                            ? 'SPACE\nPREMIERE'
                            : paused
                                ? 'PAUSED'
                                : complete
                                    ? 'WAVE ${e.wave}\nCLEARED!'
                                    : 'GOOD FLYING, PIP!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 20,
                            height: 1.6,
                            color: Color(0xFFFFD36D))),
                    const SizedBox(height: 16),
                    Text(
                        ready
                            ? 'Steer Pip’s ship, blast the invaders and protect the cinema galaxy.\n\nFiring is automatic. Shields block enemy shots. Clear a wave for bonus points and fresh shields. Don’t let the invaders reach Pip!'
                            : paused
                                ? 'Take your time. The galaxy can wait.'
                                : 'Score ${e.score} · Wave ${e.wave}',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    FilledButton(
                        onPressed: paused
                            ? c.resume
                            : complete
                                ? c.nextWave
                                : () => c.start(),
                        child: Text(paused
                            ? 'Resume'
                            : complete
                                ? 'Start wave ${e.wave + 1}'
                                : ready
                                    ? 'Start game'
                                    : 'Play again')),
                    if (ready || e.phase == SpacePhase.finished) ...[
                      const SizedBox(height: 8),
                      TextButton(
                          onPressed: () => c.start(practice: true),
                          child: const Text('Practice · unlimited lives')),
                    ],
                  ]),
            ),
          ),
        ));
  }
}
