import 'package:flixie_app/features/space_premiere/presentation/pages/space_premiere_screen.dart';
// Offline preview: no authentication, database or real account data.
// Starts at the chooser; Pairs has a seeded mid-round artwork fixture.
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/features/pip_games/presentation/pages/pip_games_screen.dart';
import 'package:flixie_app/features/pip_games/presentation/widgets/pip_games_home_entry.dart';
import 'package:flixie_app/features/popcorn_catch/presentation/pages/popcorn_catch_screen.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/pip_pairs/presentation/controllers/pip_pairs_controller.dart';
import 'package:flixie_app/features/pip_pairs/presentation/pages/pip_pairs_screen.dart';

void main() {
  final game = PipPairsController(random: Random(19));
  final firstPair = List.generate(game.cards.length, (i) => i)
      .where((i) => game.cards[i].id == game.cards.first.id);
  for (final i in firstPair) {
    game.flip(i);
  }
  final first = List.generate(game.cards.length, (i) => i)
      .firstWhere((i) => !game.isMatched(i));
  final second = List.generate(game.cards.length, (i) => i).firstWhere(
      (i) => !game.isMatched(i) && game.cards[i].id != game.cards[first].id);
  game.flip(first);
  game.flip(second);
  final router = GoRouter(initialLocation: '/play', routes: [
    GoRoute(
        path: '/',
        builder: (_, __) =>
            const Scaffold(body: SafeArea(child: PipGamesHomeEntry()))),
    GoRoute(path: '/play', builder: (_, __) => const PipGamesScreen()),
    GoRoute(
        path: '/play/space-premiere',
        builder: (_, __) => const SpacePremiereScreen()),
    GoRoute(
        path: '/play/pip-pairs',
        builder: (_, __) => PipPairsScreen(controller: game)),
    GoRoute(
        path: '/play/popcorn-catch',
        builder: (_, __) => const PopcornCatchScreen(userId: null)),
  ]);
  runApp(MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router));
}
