import 'package:flixie_app/features/pip_games/presentation/widgets/game_audio_controls.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/core/widgets/flixie_wordmark.dart';
import '../widgets/arcade_game_cabinet.dart';

const arcadeGold = Color(0xFFFFD36D);
const arcadeCream = Color(0xFFFFF0C8);

class PipGamesScreen extends StatelessWidget {
  const PipGamesScreen({super.key, this.guest = false});
  final bool guest;

  @override
  Widget build(BuildContext context) => Theme(
        data: Theme.of(context).copyWith(
          brightness: Brightness.dark,
          colorScheme: const ColorScheme.dark(
              primary: arcadeGold,
              onPrimary: Color(0xFF301439),
              surface: Color(0xFF100C25),
              onSurface: arcadeCream),
          textTheme: Theme.of(context)
              .textTheme
              .apply(bodyColor: arcadeCream, displayColor: arcadeCream),
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFF08091D),
          appBar: AppBar(
            backgroundColor: const Color(0xFF08091D),
            foregroundColor: arcadeCream,
            title: const FlixieWordmark(foregroundColor: Colors.white),
            centerTitle: true,
            actions: const [GameAudioButton()],
            leading: IconButton(
                tooltip: 'Back to Home',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    GoRouter.maybeOf(context)?.go('/');
                  }
                }),
          ),
          body: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                child: Center(
                    child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 6),
                        const _ArcadeHeading(),
                        const SizedBox(height: 10),
                        Text(
                            guest
                                ? 'Play all three games without an account. Join Flixie to post a Popcorn Catch score.'
                                : 'Choose your next little obsession.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: arcadeCream)),
                        const SizedBox(height: 20),
                        ArcadeGameCabinet(
                            key: const ValueKey('arcade-pairs'),
                            title: 'Pip Pairs',
                            description:
                                'Match the outfits. Find your favourites.',
                            asset: 'assets/images/pip_arcade/pairs-scene.png',
                            neon: const Color(0xFFB966FF),
                            onPlay: () => context.push('/play/pip-pairs')),
                        const SizedBox(height: 20),
                        ArcadeGameCabinet(
                            key: const ValueKey('arcade-popcorn'),
                            title: 'Popcorn Catch',
                            description: 'Catch treats. Chase your best.',
                            asset: 'assets/images/pip_arcade/popcorn-scene.png',
                            neon: const Color(0xFFFF6D9D),
                            onPlay: () => context.push('/play/popcorn-catch')),
                        const SizedBox(height: 20),
                        ArcadeGameCabinet(
                            key: const ValueKey('arcade-space'),
                            title: 'Space Premiere',
                            description:
                                'Steer Pip. Blast invaders. Save the galaxy.',
                            asset: 'assets/images/pip_arcade/space-scene.png',
                            neon: const Color(0xFF6EE8ED),
                            onPlay: () => context.push('/play/space-premiere')),
                        const SizedBox(height: 24),
                        const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.star_rounded,
                                  color: arcadeGold, size: 18),
                              SizedBox(width: 12),
                              Flexible(
                                  child: Text('Little games. Brighter days.',
                                      textAlign: TextAlign.center,
                                      style:
                                          TextStyle(color: Color(0xFFC5A4FF)))),
                              SizedBox(width: 12),
                              Icon(Icons.star_rounded,
                                  color: arcadeGold, size: 18),
                            ]),
                      ]),
                )),
              )),
        ),
      );
}

class _ArcadeHeading extends StatelessWidget {
  const _ArcadeHeading();
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final fontSize = constraints.maxWidth < 330
            ? 20.0
            : constraints.maxWidth < 500
                ? 25.0
                : 36.0;
        return Text('PLAY WITH PIP',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: fontSize,
                height: 1.6,
                color: arcadeCream,
                shadows: const [
                  Shadow(color: Color(0xFF5927A2), offset: Offset(0, 4)),
                  Shadow(color: Color(0xFF251347), offset: Offset(0, 7)),
                ]));
      });
}
