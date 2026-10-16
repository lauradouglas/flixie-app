import 'package:flixie_app/features/pip_games/audio/game_audio.dart';
import '../../support/fake_game_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/features/space_premiere/domain/space_engine.dart';
import 'package:flixie_app/features/space_premiere/presentation/controllers/space_controller.dart';
import 'package:flixie_app/features/space_premiere/presentation/pages/space_premiere_screen.dart';
import 'package:flixie_app/features/pip_games/presentation/pages/pip_games_screen.dart';

void main() {
  setUp(() {
    GameAudioSession.backendFactory = FakeGameAudioBackend.new;
  });
  tearDown(() {
    GameAudioSession.backendFactory = NativeGameAudioBackend.new;
  });
  testWidgets('start, steer, pause and resume a real round', (tester) async {
    final c = SpaceController();
    addTearDown(c.dispose);
    await tester
        .pumpWidget(MaterialApp(home: SpacePremiereScreen(controller: c)));
    await tester.ensureVisible(find.text('Start game'));
    await tester.tap(find.text('Start game'));
    await tester.pump();
    expect(c.engine.phase, SpacePhase.playing);
    await tester.pump(const Duration(milliseconds: 200));
    final before = c.engine.x;
    await tester.drag(
        find.byKey(const ValueKey('space-steering')), const Offset(-80, 0));
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.engine.x, lessThan(before));
    await tester.tap(find.byTooltip('Pause game'));
    await tester.pumpAndSettle();
    final ticks = c.engine.ticks;
    await tester.pump(const Duration(seconds: 2));
    expect(c.engine.ticks, ticks);
    await tester.tap(find.text('Resume'));
    await tester.pump();
    expect(c.engine.phase, SpacePhase.playing);
    c.pause();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('clear wave then continue; practice survives a hit',
      (tester) async {
    final c = SpaceController();
    addTearDown(c.dispose);
    await tester
        .pumpWidget(MaterialApp(home: SpacePremiereScreen(controller: c)));
    await tester.ensureVisible(find.text('Practice · unlimited lives').last);
    await tester.tap(find.text('Practice · unlimited lives').last);
    await tester.pump();
    expect(c.engine.practice, isTrue);
    c.engine.enemyShots.add(SpaceShot(c.engine.x, 478));
    c.advance(const Duration(milliseconds: 20));
    expect(c.engine.lives, 3);
    c.engine.invaders.clear();
    c.advance(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();
    expect(find.text('Start wave 2'), findsOneWidget);
    await tester.tap(find.text('Start wave 2'));
    await tester.pump();
    expect(c.engine.wave, 2);
    expect(c.engine.score, 100);
    c.pause();
    await tester.pumpAndSettle();
  });
  testWidgets('arcade opens Space Premiere and close returns to games',
      (tester) async {
    final router = GoRouter(initialLocation: '/play', routes: [
      GoRoute(path: '/play', builder: (_, __) => const PipGamesScreen()),
      GoRoute(
          path: '/play/space-premiere',
          builder: (_, __) => const SpacePremiereScreen()),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    final card = find.byKey(const ValueKey('arcade-space'));
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.byType(SpacePremiereScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Back to games'));
    await tester.pumpAndSettle();
    expect(find.byType(PipGamesScreen), findsOneWidget);
  });
  testWidgets('backgrounding pauses and direct entry can close to the arcade',
      (tester) async {
    final c = SpaceController();
    addTearDown(c.dispose);
    final router = GoRouter(initialLocation: '/play/space-premiere', routes: [
      GoRoute(path: '/play', builder: (_, __) => const PipGamesScreen()),
      GoRoute(
          path: '/play/space-premiere',
          builder: (_, __) => SpacePremiereScreen(controller: c)),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start game'));
    await tester.tap(find.text('Start game'));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(c.engine.phase, SpacePhase.paused);
    final ticks = c.engine.ticks;
    await tester.pump(const Duration(seconds: 3));
    expect(c.engine.ticks, ticks);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(c.engine.phase, SpacePhase.paused);
    await tester.tap(find.byTooltip('Back to games'));
    await tester.pumpAndSettle();
    expect(find.byType(PipGamesScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'lives show filled hearts, lost lives outline, and practice infinity',
      (tester) async {
    final c = SpaceController();
    addTearDown(c.dispose);
    await tester
        .pumpWidget(MaterialApp(home: SpacePremiereScreen(controller: c)));
    expect(find.byIcon(Icons.favorite), findsNWidgets(3));
    await tester.ensureVisible(find.text('Start game'));
    await tester.tap(find.text('Start game'));
    await tester.pump();
    c.engine.enemyShots.add(SpaceShot(c.engine.x, 478));
    c.advance(const Duration(milliseconds: 20));
    await tester.pump();
    expect(find.byIcon(Icons.favorite), findsNWidgets(2));
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    c.start(practice: true);
    await tester.pump();
    expect(find.byIcon(Icons.all_inclusive), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);
    c.pause();
    await tester.pumpAndSettle();
  });
  testWidgets('ship and arcade scene are bundled', (tester) async {
    for (final asset in [
      'assets/images/space_premiere/pip-ship.png',
      'assets/images/pip_arcade/space-scene.png'
    ]) {
      expect((await rootBundle.load(asset)).lengthInBytes, greaterThan(0));
    }
  });
  for (final size in [
    const Size(320, 568),
    const Size(844, 390),
    const Size(1024, 1366)
  ]) {
    testWidgets('ready screen works at $size and large text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!),
          home: const SpacePremiereScreen()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Start game'));
      expect(tester.takeException(), isNull);
    });
  }
}
