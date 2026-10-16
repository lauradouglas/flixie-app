import 'package:flixie_app/features/pip_games/audio/game_audio.dart';
import '../../support/fake_game_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/popcorn_catch/presentation/pages/popcorn_catch_screen.dart';
import 'package:flixie_app/features/popcorn_catch/presentation/widgets/popcorn_arena.dart';
import '../../../tool/preview_popcorn_catch.dart';

void main() {
  setUp(() {
    GameAudioSession.backendFactory = FakeGameAudioBackend.new;
  });
  tearDown(() {
    GameAudioSession.backendFactory = NativeGameAudioBackend.new;
  });
  testWidgets('closing a pushed game returns to its original screen',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => PopcornCatchScreen(
                                userId: 'fictional-casey',
                                service: PreviewPopcornService()))),
                    child: const Text('Open game'))))));
    await tester.tap(find.text('Open game'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close game'));
    await tester.pumpAndSettle();
    expect(find.text('Open game'), findsOneWidget);
    expect(find.byType(PopcornCatchScreen), findsNothing);
  });
  testWidgets(
      'practice starts, moves with keyboard, pauses and ends without posting',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: PopcornCatchScreen(
            userId: 'fictional-casey', service: PreviewPopcornService())));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Untimed practice · works offline'));
    await tester.tap(find.text('Untimed practice · works offline'));
    for (var i = 0; i < 65; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byTooltip('Pause round'), findsOneWidget);
    final arena = tester.widget<PopcornArena>(find.byType(PopcornArena));
    expect(find.byTooltip('Move Pip left'), findsNothing);
    expect(find.byTooltip('Move Pip right'), findsNothing);
    expect(tester.getSize(find.byType(PopcornArena)),
        tester.view.physicalSize / tester.view.devicePixelRatio);
    final beforeDrag = arena.controller.engine.x;
    await tester.drag(
        find.byKey(const Key('popcorn-drag-zone')), const Offset(60, 0));
    await tester.pump(const Duration(milliseconds: 100));
    expect(arena.controller.engine.x, greaterThan(beforeDrag));
    final previousX = arena.controller.engine.x;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 50));
    expect(arena.controller.engine.x, greaterThan(previousX));
    await tester.tap(find.byTooltip('Pause round'));
    await tester.pumpAndSettle();
    expect(find.text('Resume round'), findsOneWidget);
    await tester.ensureVisible(find.text('Resume round'));
    await tester.tap(find.text('Resume round'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byTooltip('Pause round'), findsOneWidget);
    await tester.tap(find.byTooltip('Pause round'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Finish practice'));
    await tester.tap(find.text('Finish practice'));
    await tester.pumpAndSettle();
    expect(find.text('That’s a wrap!'), findsOneWidget);
    expect(find.text('Post to leaderboard'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('result actions stay reachable above the home indicator',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final config in [
      (const Size(393, 852), 1.0),
      (const Size(320, 568), 2.0),
      (const Size(844, 390), 2.0),
      (const Size(1024, 768), 2.0),
    ]) {
      tester.view.physicalSize = config.$1;
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  padding: const EdgeInsets.only(top: 59, bottom: 34),
                  textScaler: TextScaler.linear(config.$2)),
              child: child!),
          home: PopcornCatchScreen(
              userId: 'fictional-casey', service: PreviewPopcornService())));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Start round 1'));
      await tester.tap(find.text('Start round 1'));
      await tester.pump();
      for (var i = 0; i < 680; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      for (final label in [
        'Challenge a friend',
        'Post to leaderboard',
        'Play again',
        'Untimed practice · works offline'
      ]) {
        final action = find.text(label);
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        expect(action.hitTestable(), findsOneWidget,
            reason: '$label at $config');
        expect(tester.getRect(action).bottom, lessThan(config.$1.height - 34));
      }
      await tester.tap(find.text('Untimed practice · works offline'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('New personal best!'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
  testWidgets('ranked result posts and opens the leaderboard sheet',
      (tester) async {
    final service = PreviewPopcornService();
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: PopcornCatchScreen(userId: 'fictional-casey', service: service)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start round 1'));
    await tester.pump();
    for (var i = 0; i < 680; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('New personal best!'), findsOneWidget);
    await tester.ensureVisible(find.text('Post to leaderboard'));
    await tester.tap(find.text('Post to leaderboard'));
    await tester.pumpAndSettle();
    expect(find.text('Out of lives—give Pip another go!'), findsOneWidget);
    expect(find.text('Score posted'), findsOneWidget);
    expect(service.best, isNotNull);
    await tester.tap(find.byTooltip('Leaderboard'));
    await tester.pumpAndSettle();
    expect(find.text('Casey (you)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'ready screen reflows on narrow phone, landscape and tablet with large text',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final size in [
      const Size(320, 740),
      const Size(844, 390),
      const Size(1024, 768)
    ]) {
      for (final theme in [AppTheme.darkTheme, AppTheme.lightTheme]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(MaterialApp(
            theme: theme,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!),
            home: PopcornCatchScreen(
                userId: 'fictional-casey', service: PreviewPopcornService())));
        await tester.pumpAndSettle();
        expect(find.text('Start round 1'), findsOneWidget);
        expect(find.text('Popcorn legends'), findsNothing);
        expect(find.byTooltip('Leaderboard'), findsOneWidget);
        await tester.tap(find.byTooltip('Leaderboard'));
        await tester.pumpAndSettle();
        expect(find.text('Popcorn legends'), findsOneWidget);
        await tester.tap(find.byTooltip('Close sheet'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester
            .ensureVisible(find.text('Untimed practice · works offline'));
        await tester.tap(find.text('Untimed practice · works offline'));
        for (var i = 0; i < 65; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(find.byTooltip('Pause round'), findsOneWidget);
        await tester.tap(find.byTooltip('Pause round'));
        await tester.pumpAndSettle();
        expect(find.text('Finish practice'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });
}
