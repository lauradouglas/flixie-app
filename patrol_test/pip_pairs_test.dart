import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/features/pip_games/presentation/pages/pip_games_screen.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/pip_pairs/presentation/controllers/pip_pairs_controller.dart';
import 'package:flixie_app/features/pip_pairs/presentation/pages/pip_pairs_screen.dart';

void main() {
  patrolTest('match outfit Pips, finish a board and start another', ($) async {
    final game = PipPairsController(random: Random(12));
    addTearDown(game.dispose);
    await $.pumpWidgetAndSettle(MaterialApp(
        theme: AppTheme.darkTheme, home: PipPairsScreen(controller: game)));
    for (final id in game.cards.map((c) => c.id).toSet()) {
      final indices = List.generate(game.cards.length, (i) => i)
          .where((i) => game.cards[i].id == id);
      for (final i in indices) {
        final card = find.byKey(ValueKey('pip-card-$i'));
        await $.tester.ensureVisible(card);
        await $(card).tap();
        await $.pumpAndSettle();
      }
    }
    expect(find.text('Lovely matching!'), findsOneWidget);
    await $.tester.ensureVisible(find.text('Play another board'));
    await $(find.text('Play another board')).tap();
    await $.pumpAndSettle();
    expect(game.matches, 0);
    expect(game.moves, 0);
    expect($.tester.takeException(), isNull);
  });
  patrolTest('Pairs can close from a direct entry and from the arcade chooser',
      ($) async {
    final router = GoRouter(initialLocation: '/play/pip-pairs', routes: [
      GoRoute(path: '/play', builder: (_, __) => const PipGamesScreen()),
      GoRoute(
          path: '/play/pip-pairs', builder: (_, __) => const PipPairsScreen()),
    ]);
    addTearDown(router.dispose);
    await $.pumpWidgetAndSettle(
        MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router));
    await $(find.byTooltip('Back to games')).tap();
    await $.pumpAndSettle();
    expect(find.byType(PipGamesScreen), findsOneWidget);
    await $(find.byKey(const ValueKey('arcade-pairs'))).tap();
    await $.pumpAndSettle();
    expect(find.byType(PipPairsScreen), findsOneWidget);
    await $(find.byTooltip('Back to games')).tap();
    await $.pumpAndSettle();
    expect(find.byType(PipGamesScreen), findsOneWidget);
    expect($.tester.takeException(), isNull);
  });
}
