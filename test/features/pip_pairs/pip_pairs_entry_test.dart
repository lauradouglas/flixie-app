import 'package:flixie_app/features/pip_games/audio/game_audio.dart';
import '../../support/fake_game_audio.dart';
import 'package:flixie_app/features/pip_games/presentation/pages/pip_games_screen.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/features/pip_pairs/presentation/pages/pip_pairs_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/features/pip_games/presentation/widgets/pip_games_home_entry.dart';

void main() {
  setUp(() {
    GameAudioSession.backendFactory = FakeGameAudioBackend.new;
  });
  tearDown(() {
    GameAudioSession.backendFactory = NativeGameAudioBackend.new;
  });
  testWidgets(
      'Play with Pip opens the games area and both games remain reachable',
      (tester) async {
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: PipGamesHomeEntry())),
      GoRoute(path: '/play', builder: (_, __) => const PipGamesScreen()),
      GoRoute(
          path: '/play/pip-pairs',
          builder: (_, __) => const Scaffold(body: Text('Pairs destination'))),
      GoRoute(
          path: '/play/popcorn-catch',
          builder: (_, __) =>
              const Scaffold(body: Text('Popcorn destination'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Play with Pip'));
    await tester.pumpAndSettle();
    expect(find.byType(PipGamesScreen), findsOneWidget);
    await tester.tap(find.text('PIP PAIRS'));
    await tester.pumpAndSettle();
    expect(find.text('Pairs destination'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('POPCORN CATCH'));
    await tester.tap(find.text('POPCORN CATCH'));
    await tester.pumpAndSettle();
    expect(find.text('Popcorn destination'), findsOneWidget);
  });
  testWidgets('games area wraps on a small phone with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: const PipGamesScreen()));
    await tester.pumpAndSettle();
    expect(find.text('PIP PAIRS'), findsOneWidget);
    await tester.ensureVisible(find.text('POPCORN CATCH'));
    expect(tester.takeException(), isNull);
  });
  for (final directEntry in [false, true]) {
    testWidgets('Pairs closes back to games, direct entry: $directEntry',
        (tester) async {
      final router = GoRouter(
          initialLocation: directEntry ? '/play/pip-pairs' : '/play',
          routes: [
            GoRoute(path: '/play', builder: (_, __) => const PipGamesScreen()),
            GoRoute(
                path: '/play/pip-pairs',
                builder: (_, __) => const PipPairsScreen()),
          ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      if (!directEntry) {
        await tester.tap(find.byKey(const ValueKey('arcade-pairs')));
        await tester.pumpAndSettle();
      }
      expect(find.byType(PipPairsScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Back to games'));
      await tester.pumpAndSettle();
      expect(find.byType(PipGamesScreen), findsOneWidget);
      expect(find.byType(PipPairsScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
