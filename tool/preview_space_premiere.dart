// Offline arcade preview. SPACE_CAPTURE=true freezes a deterministic 1.2s
// gameplay fixture for screenshots; the default is live, playable Space Premiere.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/pip_games/presentation/pages/pip_games_screen.dart';
import 'package:flixie_app/features/pip_games/presentation/widgets/pip_games_home_entry.dart';
import 'package:flixie_app/features/pip_pairs/presentation/pages/pip_pairs_screen.dart';
import 'package:flixie_app/features/popcorn_catch/presentation/pages/popcorn_catch_screen.dart';
import 'package:flixie_app/features/space_premiere/presentation/controllers/space_controller.dart';
import 'package:flixie_app/features/space_premiere/presentation/pages/space_premiere_screen.dart';
import 'game_audio_probe.dart';
import 'preview_popcorn_catch.dart' show PreviewPopcornService;

void main() {
  registerGameAudioProbe();
  const frozen = bool.fromEnvironment('SPACE_CAPTURE');
  final c = SpaceController();
  if (frozen) {
    c.start();
    for (var i = 0; i < 6; i++) {
      c.advance(const Duration(milliseconds: 200));
    }
  }
  final router = GoRouter(initialLocation: '/play/space-premiere', routes: [
    GoRoute(
        path: '/',
        builder: (_, __) =>
            const Scaffold(body: SafeArea(child: PipGamesHomeEntry()))),
    GoRoute(path: '/play', builder: (_, __) => const PipGamesScreen()),
    GoRoute(
        path: '/play/pip-pairs', builder: (_, __) => const PipPairsScreen()),
    GoRoute(
        path: '/play/popcorn-catch',
        builder: (_, __) => PopcornCatchScreen(
            userId: null, service: PreviewPopcornService(version: 3))),
    GoRoute(
        path: '/play/space-premiere',
        builder: (_, __) => TickerMode(
            enabled: !frozen, child: SpacePremiereScreen(controller: c))),
  ]);
  runApp(MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router));
}
