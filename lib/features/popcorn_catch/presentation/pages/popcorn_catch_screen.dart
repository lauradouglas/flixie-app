import 'package:flixie_app/features/guest/presentation/guest_access.dart';
import 'package:flixie_app/features/pip_games/audio/game_audio.dart';
import 'package:flixie_app/features/pip_games/presentation/widgets/game_audio_controls.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:flixie_app/core/widgets/flixie_wordmark.dart';
import '../../data/popcorn_service.dart';
import '../controllers/popcorn_controller.dart';
import '../widgets/popcorn_arena.dart';
import 'popcorn_leaderboard_screen.dart';
import '../widgets/popcorn_share_sheet.dart';
import '../widgets/pip_performance.dart';
import '../widgets/popcorn_action_button.dart';

class PopcornCatchScreen extends StatefulWidget {
  const PopcornCatchScreen(
      {super.key,
      required this.userId,
      this.service,
      this.challengeId,
      this.autoStartChallenge = false});
  final String? userId;
  final String? challengeId;
  final bool autoStartChallenge;
  final PopcornService? service;
  @override
  State<PopcornCatchScreen> createState() => _PopcornCatchScreenState();
}

class _PopcornCatchScreenState extends State<PopcornCatchScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final PopcornController _game;
  final _audio = GameAudioSession('popcorn');
  late final Ticker _ticker;
  final FocusNode _focus = FocusNode(debugLabel: 'Popcorn controls');
  Duration _last = Duration.zero;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game = PopcornController(
        userId: widget.userId,
        service: widget.service,
        challengeId: widget.challengeId)
      ..onSound = _audio.play
      ..addListener(_changed);
    _ticker = createTicker((elapsed) {
      final delta = elapsed - _last;
      _last = elapsed;
      _game.advance(delta);
    });
    unawaited(_game.loadBoard());
    if (widget.userId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        GuestAccess.takeAction('/play/popcorn-catch');
        unawaited(_game.restoreGuestScore());
      });
    }
    if (widget.challengeId != null && widget.autoStartChallenge) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ranked();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final frame in [
      'catch',
      'worried',
      'frantic',
      'blink',
      'crouch',
      'leap',
      'land',
      'dance',
      'sad'
    ]) {
      unawaited(precacheImage(
          AssetImage('assets/icon/pip_popcorn_$frame.png'), context));
    }
  }

  void _changed() {
    if (!mounted) return;
    _audio.setPlaying(_game.phase == PopcornPhase.playing);
    if (_game.animating && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
    if (!_game.animating && _ticker.isActive) _ticker.stop();
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant PopcornCatchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _game.bind(widget.userId);
    if (oldWidget.userId != widget.userId && widget.userId != null) {
      unawaited(_game.restoreGuestScore());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _game.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _game.removeListener(_changed);
    _game.onSound = null;
    _audio.close();
    _ticker.dispose();
    _game.dispose();
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent ||
        (_game.phase != PopcornPhase.playing &&
            _game.phase != PopcornPhase.paused)) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _game.nudge(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _game.nudge(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.space && event is KeyDownEvent) {
      if (_game.phase == PopcornPhase.paused) {
        _game.resume();
      } else {
        _game.pause();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _remove(BuildContext context) async {
    final remove = await showFlixiePromptSheet<bool>(
        context: context,
        builder: (context) => FlixiePromptSheetContent(
                title: const Text('Remove your score?'),
                content: const Text(
                    'Your leaderboard entry will be removed. You can post a new score after another round.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep it')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Remove score'))
                ]));
    if (remove == true && mounted) await _game.removeScore();
  }

  Future<void> _sheet(BuildContext context, {required bool leaderboard}) async {
    _game.pause();
    if (leaderboard && widget.userId == null) {
      await _joinLeaderboard();
      return;
    }
    if (leaderboard) {
      final phase = _game.phase;
      await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (context) => PopcornLeaderboardScreen(
              controller: _game,
              userId: widget.userId,
              onRemove: () => unawaited(_remove(context)),
              playLabel: phase == PopcornPhase.paused
                  ? 'Resume game'
                  : phase == PopcornPhase.roundComplete
                      ? 'Back to game'
                      : phase == PopcornPhase.ready
                          ? 'Play now'
                          : 'Play again',
              onPlay: () {
                Navigator.pop(context);
                if (phase == PopcornPhase.paused) {
                  _game.resume();
                } else if (phase != PopcornPhase.roundComplete) {
                  _ranked();
                }
              })));
      if (mounted) _focus.requestFocus();
      return;
    }
    await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: const Color(0xFF190F2C),
        builder: (sheetContext) => Theme(
            data: AppTheme.darkTheme,
            child: SizedBox(
                height: MediaQuery.sizeOf(sheetContext).height * .78,
                child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: ListenableBuilder(
                        listenable: _game,
                        builder: (context, _) => Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Align(
                                      alignment: Alignment.centerRight,
                                      child: IconButton(
                                          tooltip: 'Close sheet',
                                          onPressed: () =>
                                              Navigator.pop(sheetContext),
                                          icon: const Icon(Icons.close))),
                                  Text('Catch the good stuff.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall),
                                  const SizedBox(height: 16),
                                  const Text(
                                      'Slide your finger over Pip, his bucket or the space below him to move. You can lift your finger and start another drag anywhere in that area.'),
                                  const SizedBox(height: 16),
                                  const Text(
                                      'Each round lasts 30 seconds. Survive it to refill your 3 lives and unlock a faster round. Your score carries forward. Lose all 3 lives and the run ends. Popcorn, gummy bears and chocolate earn 10 points; golden popcorn earns 30. Every 5 catches builds your multiplier, up to ×4. Missing a treat resets your combo. Burnt popcorn costs 1 life and 20 points, with a brief recovery before another piece can hurt you. Practice has unlimited lives. Pip gets more anxious in later rounds and when you move quickly.'),
                                  const SizedBox(height: 16),
                                  const Text(
                                      'You can finish and keep your score between rounds. Runs end after 60 rounds at most. Practice has no timer and works offline. Posting a ranked score shares your username, avatar and best score with signed-in Flixie players.'),
                                  const SizedBox(height: 16),
                                  const Text(
                                      'Keyboard: ← → to move · Space to pause. With a screen reader, adjust the movement area up or down to move Pip.'),
                                ]))))));
    if (mounted) _focus.requestFocus();
  }

  String? _guestSaveError;
  Future<void> _joinLeaderboard() async {
    try {
      final saved = await _game.rememberGuestScore();
      if (!mounted) return;
      await GuestAccess.require(context,
          title: saved
              ? 'Put your score on the board'
              : 'Join the Popcorn legends',
          message: saved
              ? 'Create an account or sign in to post these ${_game.engine.score} points. Your round will be waiting when you return, for up to 24 hours from starting it.'
              : 'Keep playing without an account. Create an account or sign in when you want to post a Popcorn Catch score.',
          path: '/play/popcorn-catch',
          intent: 'post-score');
    } catch (_) {
      if (mounted) {
        setState(() => _guestSaveError =
            'Couldn’t keep your score for signup. Please try again.');
      }
    }
  }

  void _ranked() {
    _focus.requestFocus();
    unawaited(_game.startRanked());
  }

  void _practice() {
    _focus.requestFocus();
    _game.startPractice();
  }

  bool _sharing = false;
  Future<void> _share() async {
    if (_sharing || widget.userId == null) return;
    final owner = widget.userId!;
    setState(() => _sharing = true);
    try {
      final round = await _game.verifyForSharing();
      if (round != null && mounted && widget.userId == owner) {
        await showPopcornShareSheet(context,
            roundId: round,
            userId: owner,
            service: widget.service ?? PopcornService(),
            isCurrent: () => mounted && widget.userId == owner);
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Widget _panel(BuildContext context) {
    final c = _game;
    if (c.phase == PopcornPhase.countdown) {
      return Center(
          child: Text('${c.countdown}',
              style: const TextStyle(
                  color: popcornGold,
                  fontSize: 64,
                  fontWeight: FontWeight.w900)));
    }
    if (c.phase == PopcornPhase.paused) {
      return Center(
          child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Paused',
            style: TextStyle(
                color: popcornGold, fontSize: 32, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        FilledButton.icon(
            onPressed: c.resume,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Resume round')),
        if (c.practice)
          TextButton(
              onPressed: c.finishPractice,
              child: const Text('Finish practice')),
      ])));
    }
    if (c.phase == PopcornPhase.roundComplete) {
      return Center(
          child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                    height: 140,
                    child: PipPerformance(
                        key: ValueKey('round-${c.engine.roundNumber}'),
                        mood: PipPerformanceMood.celebrate)),
                Text('Round ${c.engine.roundNumber} complete!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text('${c.engine.score} points so far',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: popcornGold,
                        fontSize: 32,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                const Text('Three fresh lives. A faster round awaits.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                SizedBox(
                    width: double.infinity,
                    child: PopcornActionButton(
                        label: 'Start round ${c.engine.roundNumber + 1}',
                        onPressed: c.nextRound)),
                const SizedBox(height: 12),
                FilledButton(
                    style: _secondaryActionStyle,
                    onPressed: c.finishRun,
                    child: const Text('Finish run & keep score')),
              ])));
    }
    final finished = c.phase == PopcornPhase.finished;
    return LayoutBuilder(
        builder: (context, constraints) => Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                    key: const Key('popcorn-result-scroll'),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (finished)
                            SizedBox(
                                height: (constraints.maxHeight * .25)
                                    .clamp(80.0, 180.0),
                                width: 260,
                                child: PipPerformance(
                                    key: ValueKey(c.engine),
                                    mood: c.newBest
                                        ? PipPerformanceMood.celebrate
                                        : c.roughRound
                                            ? PipPerformanceMood.rough
                                            : PipPerformanceMood.happy)),
                          Text(
                              finished
                                  ? c.newBest
                                      ? 'New personal best!'
                                      : c.roughRound
                                          ? 'Another go?'
                                          : 'That’s a wrap!'
                                  : 'Pip’s\nPopcorn Catch',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: finished ? Colors.white : popcornGold,
                                  fontSize: finished ? 26 : 32,
                                  fontWeight: FontWeight.w900,
                                  height: 1.1)),
                          const SizedBox(height: 12),
                          if (finished) ...[
                            Text('${c.engine.score} points',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: popcornGold,
                                    fontSize: 48,
                                    fontWeight: FontWeight.w900)),
                            const SizedBox(height: 8),
                            Text(
                                '${c.engine.version >= 3 ? 'Round' : 'Level'} ${c.engine.level} · ${c.engine.caught} caught · best streak ${c.engine.bestCombo}',
                                textAlign: TextAlign.center),
                            if (c.engine.lives == 0)
                              const Text('Out of lives—give Pip another go!',
                                  textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            if (!c.practice &&
                                widget.challengeId == null &&
                                widget.userId != null &&
                                !c.guestRound) ...[
                              SizedBox(
                                  width: double.infinity,
                                  child: PopcornActionButton(
                                      onPressed: _sharing ? null : _share,
                                      label: _sharing
                                          ? 'Verifying score…'
                                          : 'Challenge a friend')),
                              const SizedBox(height: 12),
                            ],
                            if (widget.challengeId != null) ...[
                              Text(
                                  c.replySent
                                      ? 'First result sent to your friend'
                                      : c.replying
                                          ? 'Sending your first result…'
                                          : 'Your first result is ready to send',
                                  textAlign: TextAlign.center),
                              if (!c.replySent && !c.replying)
                                TextButton(
                                    onPressed: c.replyToChallenge,
                                    child: const Text('Retry sending result')),
                            ],
                            if (!c.practice && widget.challengeId == null) ...[
                              FilledButton.icon(
                                  onPressed: c.posting || c.posted
                                      ? null
                                      : widget.userId == null
                                          ? _joinLeaderboard
                                          : c.postScore,
                                  style: _secondaryActionStyle,
                                  icon: Icon(c.posted
                                      ? Icons.check
                                      : Icons.emoji_events_outlined),
                                  label: Text(c.posting
                                      ? 'Posting…'
                                      : c.posted
                                          ? 'Score posted'
                                          : widget.userId == null
                                              ? 'Join to post this score'
                                              : 'Post to leaderboard')),
                              const SizedBox(height: 8),
                              const Text(
                                  'Posting shares your username, avatar and best score with Flixie players.',
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                            ],
                          ] else ...[
                            const Text(
                                '3 lives each round. 30 seconds per round.\nCatch treats. Every round gets harder.',
                                textAlign: TextAlign.center),
                            const SizedBox(height: 20),
                          ],
                          if (finished && widget.challengeId != null)
                            TextButton(
                                onPressed: () => Navigator.maybePop(context),
                                child: const Text('Back to chat'))
                          else if (finished && !c.practice && !c.posted)
                            FilledButton(
                                style: _secondaryActionStyle,
                                onPressed: c.posting ? null : _ranked,
                                child: const Text('Play again'))
                          else
                            FilledButton(
                                onPressed: c.phase == PopcornPhase.starting ||
                                        c.posting
                                    ? null
                                    : _ranked,
                                style: FilledButton.styleFrom(
                                    backgroundColor: popcornGold,
                                    foregroundColor: const Color(0xFF2C153E),
                                    minimumSize: const Size(0, 52)),
                                child: Text(c.phase == PopcornPhase.starting
                                    ? 'Setting the stage…'
                                    : finished
                                        ? 'Play again'
                                        : widget.challengeId != null
                                            ? 'Start my first attempt'
                                            : 'Start round 1')),
                          if (widget.challengeId == null)
                            Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: FilledButton(
                                    style: _secondaryActionStyle,
                                    onPressed: c.replying ||
                                            c.posting ||
                                            c.phase == PopcornPhase.starting
                                        ? null
                                        : _practice,
                                    child: const Text(
                                        'Untimed practice · works offline',
                                        textAlign: TextAlign.center))),
                          if (widget.userId == null && !c.practice)
                            const Padding(
                                padding: EdgeInsets.only(top: 12),
                                child: Text(
                                    'Free to play. An account is only needed to post a leaderboard score.',
                                    textAlign: TextAlign.center)),
                          if (_guestSaveError != null)
                            Text(_guestSaveError!, textAlign: TextAlign.center),
                          if (c.error != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(c.error!,
                                    textAlign: TextAlign.center)),
                        ])))));
  }

  ButtonStyle get _secondaryActionStyle => FilledButton.styleFrom(
      backgroundColor: const Color(0xFF39214F),
      foregroundColor: Colors.white,
      disabledBackgroundColor: const Color(0xFF2A1B3B),
      disabledForegroundColor: const Color(0xFFD7C7E6),
      minimumSize: const Size.fromHeight(50),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)));

  @override
  Widget build(BuildContext context) => GameAudioBoundary(
      audio: _audio,
      child: Theme(
          data: AppTheme.darkTheme,
          child: Builder(builder: (context) {
            final c = _game, media = MediaQuery.of(context);
            final compact = media.size.height < 600;
            final scale = media.textScaler.scale(1).clamp(1.0, 2.0);
            final active = c.phase == PopcornPhase.playing ||
                c.phase == PopcornPhase.paused ||
                c.phase == PopcornPhase.countdown;
            final hudHeight = compact ? 64 * scale : 92 * scale;
            final topInset =
                media.padding.top + 64 + (active ? hudHeight + 12 : 0);
            final bottomInset = media.padding.bottom + (compact ? 12 : 32);
            final panelBottom = c.phase == PopcornPhase.finished ||
                    c.phase == PopcornPhase.roundComplete
                ? bottomInset
                : bottomInset + 26 + media.size.height * .30;
            return AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle.light,
                child: Scaffold(
                    backgroundColor: const Color(0xFF150C24),
                    body: Focus(
                        focusNode: _focus,
                        autofocus: true,
                        onKeyEvent: _key,
                        child: Stack(children: [
                          Positioned.fill(
                              child: PopcornArena(
                                  controller: c,
                                  topInset: topInset,
                                  bottomInset: bottomInset)),
                          Positioned(
                              top: media.padding.top + 4,
                              left: 12,
                              right: 12,
                              child: Row(children: [
                                IconButton(
                                    tooltip: 'Close game',
                                    onPressed: () {
                                      if (Navigator.canPop(context)) {
                                        Navigator.pop(context);
                                      } else {
                                        context.go('/');
                                      }
                                    },
                                    icon: const Icon(Icons.close)),
                                Expanded(
                                    child: Center(
                                        child: MediaQuery(
                                            data: media.copyWith(
                                                textScaler:
                                                    TextScaler.noScaling),
                                            child: const FlixieWordmark(
                                                fontSize: 20)))),
                                GameAudioButton(onOpen: c.pause),
                                IconButton(
                                    tooltip: 'Leaderboard',
                                    onPressed: () => unawaited(
                                        _sheet(context, leaderboard: true)),
                                    icon: const Icon(
                                        Icons.emoji_events_outlined)),
                                if (active)
                                  IconButton(
                                      tooltip: c.phase == PopcornPhase.paused
                                          ? 'Resume round'
                                          : 'Pause round',
                                      onPressed: c.phase == PopcornPhase.paused
                                          ? c.resume
                                          : c.pause,
                                      icon: Icon(c.phase == PopcornPhase.paused
                                          ? Icons.play_arrow
                                          : Icons.pause)),
                                IconButton(
                                    tooltip: 'How to play',
                                    onPressed: () => unawaited(
                                        _sheet(context, leaderboard: false)),
                                    icon: const Icon(Icons.info_outline)),
                              ])),
                          if (active)
                            Positioned(
                                top: media.padding.top + 64,
                                left: 24,
                                right: 24,
                                child: compact
                                    ? Text(
                                        '${c.engine.version >= 3 ? 'Round' : 'Level'} ${c.engine.level} · ${c.practice ? 'Unlimited lives' : '${c.engine.lives}/3 lives'}\n${c.engine.score} points · ${c.practice ? 'Practice' : '${c.secondsLeft}s'} · ×${c.engine.multiplier}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800))
                                    : Wrap(
                                        spacing: 20,
                                        runSpacing: 8,
                                        alignment: WrapAlignment.spaceBetween,
                                        children: [
                                            _stat('Score', '${c.engine.score}'),
                                            _stat(
                                                c.engine.version >= 3
                                                    ? 'Round'
                                                    : 'Level',
                                                '${c.engine.level}'),
                                            Semantics(
                                                label: c.practice
                                                    ? 'Unlimited lives'
                                                    : '${c.engine.lives} of 3 lives remaining',
                                                child: ExcludeSemantics(
                                                    child: Column(children: [
                                                  const Text('Lives'),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        if (c.practice)
                                                          const Icon(
                                                              Icons
                                                                  .all_inclusive,
                                                              color:
                                                                  popcornGold)
                                                        else
                                                          for (var i = 0;
                                                              i < 3;
                                                              i++)
                                                            Icon(
                                                                i < c.engine.lives
                                                                    ? Icons
                                                                        .favorite
                                                                    : Icons
                                                                        .favorite_border,
                                                                size: 20,
                                                                color: i <
                                                                        c.engine
                                                                            .lives
                                                                    ? const Color(
                                                                        0xFFFF81AA)
                                                                    : const Color(
                                                                        0xFFC9A9D8))
                                                      ])
                                                ]))),
                                            _stat(
                                                c.practice ? 'Mode' : 'Time',
                                                c.practice
                                                    ? 'Practice'
                                                    : '${c.secondsLeft}s'),
                                            _stat('Combo',
                                                '×${c.engine.multiplier}'),
                                          ])),
                          if (c.phase != PopcornPhase.playing)
                            Positioned(
                                top: topInset + 8,
                                bottom: panelBottom,
                                left: 24,
                                right: 24,
                                child: _panel(context)),
                          if (c.phase == PopcornPhase.playing)
                            Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                // Cover Pip and his bucket, plus a generous area above them.
                                height: ((media.size.width * .72).clamp(1.0, media.size.height * .52) *
                                        .26 /
                                        .42 *
                                        1286 /
                                        1223) +
                                    bottomInset +
                                    26 +
                                    60,
                                child: Semantics(
                                    label:
                                        'Move Pip. Drag across the bottom of the screen.',
                                    onIncrease: () => c.nudge(1),
                                    onDecrease: () => c.nudge(-1),
                                    child: GestureDetector(
                                        key: const Key('popcorn-drag-zone'),
                                        behavior: HitTestBehavior.opaque,
                                        onHorizontalDragStart: (_) {
                                          _focus.requestFocus();
                                          c.move(c.engine.x / 1000);
                                        },
                                        onHorizontalDragUpdate: (details) => c.dragBy(details
                                                .delta.dx /
                                            (media.size.width * .72).clamp(
                                                1.0, media.size.height * .52)),
                                        child: Container(
                                            alignment: Alignment.bottomCenter,
                                            padding: EdgeInsets.only(
                                                bottom:
                                                    media.padding.bottom + 12),
                                            decoration: const BoxDecoration(
                                                gradient: LinearGradient(
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                    colors: [Colors.transparent, Color(0xBB150C24)])),
                                            child: const IgnorePointer(
                                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                              Icon(Icons.swipe_rounded,
                                                  color: popcornGold, size: 20),
                                              SizedBox(width: 8),
                                              Flexible(
                                                  child: Text(
                                                      'Drag here to move Pip',
                                                      style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 14))),
                                            ])))))),
                        ]))));
          })));

  Widget _stat(String label, String value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(color: Color(0xFFE4D8F6), fontSize: 12)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900)),
      ]);
}
