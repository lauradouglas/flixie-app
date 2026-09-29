import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/pick_for_us/pick_for_us_screen.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/models/friendship.dart';
import 'support/pick_fixture.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Manrope')
          ..addFont(
              rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  Future<void> show(WidgetTester tester, FixturePickService service,
      {Size size = const Size(390, 844),
      double scale = 1,
      bool light = false}) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // Match the app's nested navigator: Home, picker and details share a shell.
    final router = GoRouter(routes: [
      ShellRoute(
        builder: (_, __, child) => child,
        routes: [
          GoRoute(
              path: '/',
              builder: (context, _) => Scaffold(
                  body: TextButton(
                      onPressed: () => context.push('/pick-for-us'),
                      child: const Text('Pick for me')))),
          GoRoute(
              path: '/pick-for-us',
              builder: (_, __) =>
                  PickForUsScreen(userId: 'fixture-casey', service: service)),
          GoRoute(
              path: '/movies/:id',
              builder: (_, state) => Scaffold(
                  appBar: AppBar(),
                  body: Text('Movie ${state.pathParameters['id']}'))),
        ],
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(
        theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Pick for me'));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final finder = find.text(text);
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(finder, 240,
          scrollable: find.byType(Scrollable).first);
    }
    await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester) => tap(tester, 'Next · Your evening');
  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('PICK_CAPTURE')) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first);
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('/tmp/flixie-pick-$name.png')
          .writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('selected mood reaches service and solo movie opens then returns',
      (tester) async {
    final service = FixturePickService();
    await show(tester, service);
    await capture(tester, 'mood');
    await tap(tester, 'Get hooked');
    await next(tester);
    expect(find.text('Robin'), findsNothing);
    await capture(tester, 'evening');
    await tap(tester, 'Find my picks');
    expect(service.mood, 'hooked');
    expect(service.friendId, isNull);
    expect(service.allowRewatches, false);
    expect(service.openToRent, false);
    expect(find.text('Alien'), findsOneWidget);
    await capture(tester, 'results');
    await tap(tester, 'View movie');
    expect(find.text('Movie 348'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Alien'), findsOneWidget);
  });
  testWidgets('shared alternative details open above picker and Back retains choice',
      (tester) async {
    await show(tester, FixturePickService());
    await next(tester);
    await tap(tester, 'With a friend');
    await tap(tester, 'Robin');
    await tap(tester, 'Find our picks');
    await tap(tester, 'Alternative 1');
    await tap(tester, 'View movie details');
    expect(find.text('Movie 571'), findsOneWidget);
    expect(find.text('Your picks'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('The Birds'), findsOneWidget);
    expect(find.text('Make a Watch Plan'), findsOneWidget);
  });
  for (final stage in ['mood', 'evening', 'results']) {
    testWidgets('Close exits directly from $stage', (tester) async {
      await show(tester, FixturePickService());
      if (stage != 'mood') await next(tester);
      if (stage == 'results') {
        await tap(tester, 'Find my picks');
        await tap(tester, 'Change preferences');
        await tap(tester, 'Find my picks');
      }
      await tester.tap(find.byTooltip('Close picker'));
      await tester.pumpAndSettle();
      expect(find.byType(PickForUsScreen), findsNothing);
      expect(find.widgetWithText(TextButton, 'Pick for me'), findsOneWidget);
    });
  }
  testWidgets(
      'genre runtime rewatch and content filters are independent from mood',
      (tester) async {
    final service = FixturePickService();
    await show(tester, service);
    await tap(tester, 'Feel good');
    await next(tester);
    await tap(tester, 'Refine your picks');
    await tap(tester, '150 min');
    await tap(tester, 'Rom com');
    await tap(tester, 'Graphic violence');
    await tap(tester, 'Include rewatches');
    await tap(tester, 'Find my picks');
    expect(service.mood, 'feel_good');
    expect(service.genres, [35, 10749]);
    expect(service.minutes, 150);
    expect(service.avoided, {'violence'});
    expect(service.allowRewatches, true);
  });
  testWidgets(
      'different films excludes previous shortlists and retains results on exhaustion',
      (tester) async {
    final service = FixturePickService();
    await show(tester, service);
    await next(tester);
    await tap(tester, 'Find my picks');
    await tap(tester, 'Alternative 1');
    expect(find.text('The Birds'), findsOneWidget);
    await tap(tester, 'Show different films');
    expect(service.excluded, {348, 571, 539});
    expect(find.text('Se7en'), findsOneWidget);
    await tap(tester, 'Show different films');
    expect(service.excluded.length, 6);
    expect(find.text('Se7en'), findsOneWidget);
    expect(find.textContaining('No different films matched'), findsOneWidget);
  });
  testWidgets('older server repeating films cannot masquerade as new picks',
      (tester) async {
    final service = FixturePickService()..ignoreExclusions = true;
    await show(tester, service);
    await next(tester);
    await tap(tester, 'Find my picks');
    await tap(tester, 'Show different films');
    expect(find.text('Alien'), findsOneWidget);
    expect(find.textContaining('No different films matched'), findsOneWidget);
  });
  testWidgets('failed replacement retains previous picks and retries',
      (tester) async {
    final service = FixturePickService();
    await show(tester, service);
    await tap(tester, 'Get scared');
    await next(tester);
    await tap(tester, 'Find my picks');
    service.fail = true;
    await tap(tester, 'Show different films');
    expect(find.text('Alien'), findsOneWidget);
    expect(find.textContaining('Couldn’t find your picks'), findsOneWidget);
    service.fail = false;
    await tap(tester, 'Show different films');
    expect(find.text('Se7en'), findsOneWidget);
    expect(service.mood, 'scared');
  });
  testWidgets('empty result revisions retain the selected mood',
      (tester) async {
    final service = FixturePickService()..empty = true;
    await show(tester, service);
    await tap(tester, 'Get scared');
    await next(tester);
    await tap(tester, 'Find my picks');
    expect(find.text('No films fit just yet.'), findsOneWidget);
    await tap(tester, 'Change preferences');
    expect(find.text('Get scared · Change'), findsOneWidget);
  });
  testWidgets(
      'solo works while friends are pending and viewer retry preserves avatar border',
      (tester) async {
    final pending = Completer<FriendsData>();
    final service = FixturePickService()..pendingFriends = pending;
    await show(tester, service);
    await next(tester);
    await tap(tester, 'Find my picks');
    expect(find.text('Alien'), findsOneWidget);
    pending.completeError(Exception('offline'));
    await tester.pumpAndSettle();
    await tap(tester, 'Change preferences');
    await tap(tester, 'With a friend');
    expect(find.textContaining('Some viewers couldn’t load'), findsOneWidget);
    service.pendingFriends = null;
    await tap(tester, 'Retry viewers');
    expect(
        tester
            .widget<ProfileAvatarView>(find.byType(ProfileAvatarView))
            .profileBadges,
        ['FOUNDER']);
    await tap(tester, 'Robin');
    await tap(tester, 'Find our picks');
    expect(service.friendId, 'fixture-robin');
  });
  testWidgets('group selection is explicit and back retains the mood',
      (tester) async {
    final service = FixturePickService();
    await show(tester, service);
    await tap(tester, 'Get hooked');
    await next(tester);
    await tap(tester, 'With a group');
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Choose a group to continue'))
            .onPressed,
        isNull);
    await tap(tester, 'Friday Film Club');
    await tap(tester, 'Find our picks');
    expect(service.groupId, 'fixture-group');
    expect(service.friendId, isNull);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Get hooked · Change'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('What would feel good tonight?'), findsOneWidget);
  });
  testWidgets(
      'in-flight pick disables duplicate submission and tolerates disposal',
      (tester) async {
    final pending = Completer<PickForUsResponse>();
    final service = FixturePickService()..pendingPick = pending;
    await show(tester, service);
    await next(tester);
    await tester.tap(find.text('Find my picks'));
    await tester.pump();
    expect(service.calls, 1);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Finding your picks…'))
            .onPressed,
        isNull);
    await tester.tap(find.byTooltip('Close picker'));
    await tester.pumpAndSettle();
    expect(find.byType(PickForUsScreen), findsNothing);
    expect(find.widgetWithText(TextButton, 'Pick for me'), findsOneWidget);
    pending.complete(const PickForUsResponse([], null));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  for (final size in [
    const Size(320, 640),
    const Size(430, 932),
    const Size(844, 390),
    const Size(1024, 1366)
  ]) {
    testWidgets('guided journey fits $size at large text', (tester) async {
      final service = FixturePickService();
      await show(tester, service, size: size, scale: 1.8);
      await capture(tester, 'mood-${size.width.toInt()}');
      await tap(tester, 'Have a laugh');
      await next(tester);
      await capture(tester, 'evening-${size.width.toInt()}');
      await tap(tester, 'Find my picks');
      await capture(tester, 'results-${size.width.toInt()}');
      await tap(tester, 'Alternative 1');
      expect(find.text('The Birds'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('journey inherits the light theme', (tester) async {
    await show(tester, FixturePickService(), light: true);
    await next(tester);
    await tap(tester, 'Find my picks');
    await capture(tester, 'light-results');
    expect(tester.takeException(), isNull);
  });
}
