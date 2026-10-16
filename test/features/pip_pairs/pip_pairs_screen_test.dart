import 'package:flixie_app/features/pip_games/audio/game_audio.dart';
import '../../support/fake_game_audio.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:ui' show SemanticsAction, SemanticsActionEvent;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/pip_pairs/models/pip_outfit.dart';
import 'package:flixie_app/features/pip_pairs/presentation/controllers/pip_pairs_controller.dart';
import 'package:flixie_app/features/pip_pairs/presentation/pages/pip_pairs_screen.dart';

void main() {
  setUp(() {
    GameAudioSession.backendFactory = FakeGameAudioBackend.new;
  });
  tearDown(() {
    GameAudioSession.backendFactory = NativeGameAudioBackend.new;
  });
  testWidgets('all outfit artwork is bundled', (tester) async {
    for (final outfit in pipOutfits) {
      expect(
          (await rootBundle.load(outfit.asset)).lengthInBytes, greaterThan(0));
    }
  });
  testWidgets('tap pairs through completion then play another board',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final game = PipPairsController(random: Random(2));
    addTearDown(game.dispose);
    await tester
        .pumpWidget(MaterialApp(home: PipPairsScreen(controller: game)));
    for (final id in game.cards.map((c) => c.id).toSet()) {
      final indices = List.generate(game.cards.length, (i) => i)
          .where((i) => game.cards[i].id == id);
      for (final i in indices) {
        await tester.tap(find.byKey(ValueKey('pip-card-$i')));
        await tester.pumpAndSettle();
      }
    }
    expect(find.text('Lovely matching!'), findsOneWidget);
    await tester.ensureVisible(find.text('Play another board'));
    await tester.tap(find.text('Play another board'));
    await tester.pumpAndSettle();
    expect(game.matches, 0);
    expect(find.text('Lovely matching!'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'screen reader can activate a hidden card without revealing its identity',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final game = PipPairsController(random: Random(3));
    addTearDown(game.dispose);
    await tester
        .pumpWidget(MaterialApp(home: PipPairsScreen(controller: game)));
    final node =
        tester.getSemantics(find.bySemanticsLabel('Card 1, face down'));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    tester.binding.performSemanticsAction(SemanticsActionEvent(
        type: SemanticsAction.tap,
        nodeId: node.id,
        viewId: tester.view.viewId));
    await tester.pumpAndSettle();
    expect(game.isVisible(0), isTrue);
    expect(
        find.bySemanticsLabel('Card 1, ${game.cards[0].name}'), findsOneWidget);
    semantics.dispose();
  });
  for (final size in [const Size(390, 844), const Size(440, 956)]) {
    testWidgets('12 pairs fit on $size without scrolling', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final game = PipPairsController()..newGame(pairs: 12);
      addTearDown(game.dispose);
      await tester
          .pumpWidget(MaterialApp(home: PipPairsScreen(controller: game)));
      await tester.pumpAndSettle();
      for (var i = 0; i < 24; i++) {
        final rect = tester.getRect(find.byKey(ValueKey('pip-card-$i')));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
      }
      expect(tester.takeException(), isNull);
    });
  }
  for (final difficulty in PipPairsDifficulty.values) {
    testWidgets('${difficulty.label} respects mismatch timing and reset',
        (tester) async {
      final game = PipPairsController(random: Random(5));
      addTearDown(game.dispose);
      game.newGame(difficulty: difficulty);
      final different =
          game.cards.indexWhere((c) => c.id != game.cards.first.id);
      game.flip(0);
      await tester.pump(const Duration(seconds: 3));
      expect(game.isVisible(0), isTrue);
      game.flip(different);
      if (difficulty.revealTime case final delay?) {
        await tester.pump(delay - const Duration(milliseconds: 1));
        expect(game.isVisible(0), isTrue);
        await tester.pump(const Duration(milliseconds: 1));
        expect(game.isVisible(0), isFalse);
      } else {
        await tester.pump(const Duration(seconds: 10));
        expect(game.isVisible(0), isTrue);
        game.hideMismatch();
        expect(game.isVisible(0), isFalse);
      }
      game.flip(0);
      game.flip(different);
      game.newGame(difficulty: PipPairsDifficulty.easy);
      game.flip(0);
      await tester.pump(const Duration(seconds: 3));
      expect(game.isVisible(0), isTrue,
          reason: 'Old timer must not affect a fresh board');
    });
  }
  testWidgets('difficulty selector and manual mismatch control work',
      (tester) async {
    final game = PipPairsController(random: Random(9));
    addTearDown(game.dispose);
    await tester
        .pumpWidget(MaterialApp(home: PipPairsScreen(controller: game)));
    await tester.tap(find.text('Medium'));
    await tester.pumpAndSettle();
    expect(game.difficulty, PipPairsDifficulty.medium);
    await tester.tap(find.text('Hard'));
    await tester.pumpAndSettle();
    expect(game.difficulty, PipPairsDifficulty.hard);
    await tester.tap(find.text('Easy'));
    await tester.pumpAndSettle();
    final different = game.cards.indexWhere((c) => c.id != game.cards.first.id);
    game.flip(0);
    game.flip(different);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Turn cards back'));
    await tester.tap(find.text('Turn cards back'));
    await tester.pumpAndSettle();
    expect(game.isVisible(0), isFalse);
    expect(game.moves, 1);
  });
  for (final size in [
    const Size(320, 568),
    const Size(844, 390),
    const Size(1024, 1366)
  ]) {
    testWidgets('board reflows at $size with large text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!),
          home: const PipPairsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Pip Pairs'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
