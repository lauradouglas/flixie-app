import 'package:flixie_app/features/pip_games/audio/game_audio.dart';
import 'package:flixie_app/features/pip_games/presentation/widgets/game_audio_controls.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/core/widgets/flixie_wordmark.dart';
import '../controllers/pip_pairs_controller.dart';
import '../widgets/pip_pair_card.dart';

class PipPairsScreen extends StatefulWidget {
  const PipPairsScreen({super.key, this.controller});
  final PipPairsController? controller;
  @override
  State<PipPairsScreen> createState() => _PipPairsScreenState();
}

class _PipPairsScreenState extends State<PipPairsScreen> {
  late final PipPairsController game =
      widget.controller ?? PipPairsController();

  final _audio = GameAudioSession('pairs');
  @override
  void initState() {
    super.initState();
    game.onSound = _audio.play;
    game.addListener(_audioChanged);
    _audioChanged();
  }

  void _audioChanged() => _audio.setPlaying(!game.complete);

  @override
  void dispose() {
    game.removeListener(_audioChanged);
    game.onSound = null;
    _audio.close();
    if (widget.controller == null) game.dispose();
    super.dispose();
  }

  Future<void> _newGame([int? pairs, PipPairsDifficulty? difficulty]) async {
    if (game.moves > 0 && !game.complete) {
      final restart = await showFlixiePromptSheet<bool>(
        context: context,
        builder: (sheet) => FlixiePromptSheetContent(
          title: const Text('Start a fresh board?'),
          content: const Text('Your current matches will be cleared.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(sheet, false),
                child: const Text('Keep playing')),
            FilledButton(
                onPressed: () => Navigator.pop(sheet, true),
                child: const Text('New board')),
          ],
        ),
      );
      if (!mounted || restart != true) return;
    }
    game.newGame(pairs: pairs, difficulty: difficulty);
  }

  @override
  Widget build(BuildContext context) => GameAudioBoundary(
      audio: _audio,
      child: Theme(
        data: Theme.of(context).copyWith(
          brightness: Brightness.dark,
          colorScheme: const ColorScheme.dark(
              primary: Color(0xFFBDA0FF),
              onPrimary: Color(0xFF24133E),
              surface: Color(0xFF171320),
              onSurface: Colors.white),
          textTheme: Theme.of(context)
              .textTheme
              .apply(bodyColor: Colors.white, displayColor: Colors.white),
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFF100E19),
          appBar: AppBar(
            backgroundColor: const Color(0xFF100E19),
            foregroundColor: Colors.white,
            leading: IconButton(
              tooltip: 'Back to games',
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  GoRouter.of(context).go('/play');
                }
              },
            ),
            title: const FlixieWordmark(foregroundColor: Colors.white),
            centerTitle: true,
            actions: [
              const GameAudioButton(),
              IconButton(
                  tooltip: 'New board',
                  onPressed: () => _newGame(),
                  icon: const Icon(Icons.refresh_rounded))
            ],
          ),
          bottomNavigationBar: ListenableBuilder(
            listenable: game,
            builder: (context, _) => game.needsAnotherLook &&
                    game.difficulty == PipPairsDifficulty.easy
                ? SafeArea(
                    top: false,
                    child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                        child: FilledButton.icon(
                            onPressed: game.hideMismatch,
                            icon: const Icon(Icons.flip_to_back_rounded),
                            label: const Text('Turn cards back'))))
                : const SizedBox.shrink(),
          ),
          body: SafeArea(
              top: false,
              child: ListenableBuilder(
                listenable: game,
                builder: (context, _) =>
                    LayoutBuilder(builder: (context, constraints) {
                  final width = math.min(constraints.maxWidth, 680.0);
                  final largeBoard = game.pairCount == 12;
                  final columns = largeBoard
                      ? (width >= 600 && constraints.maxHeight < 500
                          ? 8
                          : width >= 360
                              ? 6
                              : 4)
                      : width < 360
                          ? 3
                          : 4;
                  final gap = largeBoard ? 6.0 : 10.0;
                  final cardWidth =
                      (width - 40 - (columns - 1) * gap) / columns;
                  final rows = (game.cards.length / columns).ceil();
                  // Compact the largest board without shrinking touch targets.
                  // Very short viewports and large text retain scrolling.
                  final heightBudget =
                      (constraints.maxHeight - 380 - (rows - 1) * gap) / rows;
                  final cardHeight = largeBoard
                      ? math.max(
                          48.0,
                          math.min(
                              cardWidth * 1.12, math.min(110.0, heightBudget)))
                      : math.max(86.0, math.min(cardWidth * 1.14, 145.0));
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    child: Center(
                        child: SizedBox(
                            width: 640,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                            Text('Pip Pairs',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headlineLarge
                                                    ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w900)),
                                            const SizedBox(height: 6),
                                            const Text(
                                                'A little memory. A lot of outfits.',
                                                style: TextStyle(
                                                    color: Color(0xFFD6C8EB))),
                                          ])),
                                      const SizedBox(width: 12),
                                      Image.asset(
                                          'assets/icon/community_pips/pip-flixie-hoodie.png',
                                          width: 72,
                                          height: 88,
                                          excludeFromSemantics: true),
                                    ]),
                                const SizedBox(height: 18),
                                Wrap(spacing: 10, runSpacing: 8, children: [
                                  for (final difficulty
                                      in PipPairsDifficulty.values)
                                    FlixiePill.choice(
                                      label: Text(difficulty.label),
                                      selected: game.difficulty == difficulty,
                                      onSelected: (selected) {
                                        if (selected &&
                                            difficulty != game.difficulty) {
                                          _newGame(null, difficulty);
                                        }
                                      },
                                    ),
                                ]),
                                const SizedBox(height: 8),
                                Text(game.difficulty.description,
                                    style: const TextStyle(
                                        color: Color(0xFFD6C8EB))),
                                const SizedBox(height: 12),
                                Wrap(spacing: 10, runSpacing: 10, children: [
                                  for (final pairs in [6, 8, 12])
                                    FlixiePill.choice(
                                      label: Text('$pairs pairs'),
                                      selected: game.pairCount == pairs,
                                      onSelected: (selected) {
                                        if (selected &&
                                            pairs != game.pairCount) {
                                          _newGame(pairs);
                                        }
                                      },
                                    ),
                                ]),
                                const SizedBox(height: 16),
                                Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    spacing: 16,
                                    runSpacing: 8,
                                    children: [
                                      Text(
                                          '${game.matches} / ${game.pairCount} pairs',
                                          style: const TextStyle(
                                              color: Color(0xFFF6CF70),
                                              fontWeight: FontWeight.w800)),
                                      Text('${game.moves} moves · No timer',
                                          style: const TextStyle(
                                              color: Color(0xFFD6C8EB))),
                                    ]),
                                const SizedBox(height: 16),
                                Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      game.complete
                                          ? 'All paired up! Pip’s wardrobe is complete.'
                                          : game.needsAnotherLook
                                              ? game.difficulty ==
                                                      PipPairsDifficulty.easy
                                                  ? 'Different outfits. Take a look, then try again.'
                                                  : 'Remember these outfits…'
                                              : 'Turn over two cards to find matching Pips.',
                                      style: const TextStyle(
                                          color: Color(0xFFD6C8EB)),
                                    )),
                                const SizedBox(height: 16),
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: game.cards.length,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: columns,
                                          mainAxisSpacing: gap,
                                          crossAxisSpacing: gap,
                                          mainAxisExtent: cardHeight),
                                  itemBuilder: (context, index) => PipPairCard(
                                    key: ValueKey('pip-card-$index'),
                                    outfit: game.cards[index],
                                    index: index,
                                    visible: game.isVisible(index),
                                    matched: game.isMatched(index),
                                    onTap: game.isVisible(index) ||
                                            game.needsAnotherLook
                                        ? null
                                        : () => game.flip(index),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                if (game.complete) ...[
                                  Image.asset(
                                      'assets/icon/community_pips/pip-laughing.png',
                                      height: 108,
                                      excludeFromSemantics: true),
                                  Text('Lovely matching!',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall),
                                  const SizedBox(height: 8),
                                  Text(
                                      'You found all ${game.pairCount} pairs in ${game.moves} moves.',
                                      textAlign: TextAlign.center),
                                  const SizedBox(height: 16),
                                  FilledButton(
                                      onPressed: () => _newGame(),
                                      child: const Text('Play another board')),
                                ],
                                const SizedBox(height: 12),
                                const Text(
                                    '24 Pips in the wardrobe. Different outfits every board.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Color(0xFFD6C8EB))),
                              ],
                            ))),
                  );
                }),
              )),
        ),
      ));
}
