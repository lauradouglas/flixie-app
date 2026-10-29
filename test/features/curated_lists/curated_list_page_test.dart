import 'package:flixie_app/features/pip/presentation/widgets/my_pip_sheet.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/curated_lists/presentation/pages/curated_list_page.dart';
import 'package:flixie_app/features/pip/presentation/controllers/pip_collection_controller.dart';
import 'curated_list_fixtures.dart';

Future<void> curatedWatchRewardJourney(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final lists = CuratedFixtureService(), auth = CuratedFixtureAuth();
  final diary = CuratedFixtureDiary(lists), pips = CuratedFixturePips(lists);
  final controller = PipCollectionController(service: pips)
    ..syncUser(auth.dbUser!.id, 0);
  await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider.value(value: controller)
      ],
      child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: CuratedListPage(id: fixtureId, service: lists, diary: diary))));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Join challenge'));
  await tester.tap(find.text('Join challenge'));
  await tester.pumpAndSettle();
  expect(lists.joins, 1);
  await tester.ensureVisible(find.text('Log & rate').first);
  await tester.tap(find.text('Log & rate').first);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Save watch'));
  await tester.tap(find.text('Save watch'));
  await tester.pumpAndSettle();
  expect(diary.writes, isEmpty);
  expect(find.text('Add your rating to count this film towards the challenge.'),
      findsOneWidget);
  await tester.ensureVisible(find.bySemanticsLabel('Rate 8 out of 10'));
  await tester.tap(find.bySemanticsLabel('Rate 8 out of 10'));
  await tester.ensureVisible(find.text('Save watch'));
  await tester.tap(find.text('Save watch'));
  await tester.pumpAndSettle();
  expect(diary.writes.length, 1);
  expect(diary.writes.single.rating, 8);
  expect(diary.writes.single.draftId, isNotEmpty);
  expect(lists.done, true);
  expect(find.text('Your rewards are unlocked'), findsOneWidget);
  expect(find.text('Added to your avatar'), findsOneWidget);
  expect(pips.active, 'classic');
  await tester.ensureVisible(find.text('Choose Pip'));
  await tester.tap(find.text('Choose Pip'));
  await tester.pumpAndSettle();
  final seasonalChoice = find.descendant(
      of: find.byType(MyPipSheet), matching: find.text('Christmas Pip'));
  expect(seasonalChoice, findsOneWidget);
  await tester.ensureVisible(seasonalChoice);
  await tester.tap(seasonalChoice);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Use this Pip'));
  await tester.tap(find.text('Use this Pip'));
  await tester.pumpAndSettle();
  expect(pips.active, 'christmasLights');
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
  controller.dispose();
  auth.dispose();
}

void main() {
  testWidgets(
      'join, log a diary watch, unlock both rewards and explicitly choose Christmas Pip',
      curatedWatchRewardJourney);
  testWidgets('underlined tabs filter rated films and restore the full list',
      (tester) async {
    final auth = CuratedFixtureAuth();
    final lists = CuratedFixtureService()
      ..value = fixtureList(target: 2)
      ..joined = true
      ..watched.add(71);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: CuratedListPage(id: fixtureId, service: lists))));
    await tester.pumpAndSettle();
    expect(find.text('Your rewards'), findsOneWidget);
    await tester.ensureVisible(find.text('Still to watch'));
    await tester.tap(find.text('Still to watch'));
    await tester.pumpAndSettle();
    expect(find.text('Elf'), findsNothing);
    expect(find.text('Home Alone'), findsOneWidget);
    await tester.tap(find.text('All (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Elf'), findsOneWidget);
    expect(find.text('Watched & rated'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
  });
  testWidgets('poster opens its movie and returning refreshes list progress',
      (tester) async {
    final auth = CuratedFixtureAuth();
    final lists = CuratedFixtureService()
      ..value = fixtureList(target: 2)
      ..joined = true;
    final router = GoRouter(initialLocation: '/list', routes: [
      GoRoute(
          path: '/list',
          builder: (_, __) => CuratedListPage(id: fixtureId, service: lists)),
      GoRoute(
          path: '/movies/:id',
          builder: (_, state) => Scaffold(
              appBar:
                  AppBar(title: Text('Movie ${state.pathParameters['id']}')))),
    ]);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp.router(
            theme: AppTheme.darkTheme, routerConfig: router)));
    await tester.pumpAndSettle();
    final poster = find.bySemanticsLabel('View Elf');
    await tester.ensureVisible(poster);
    await tester.tap(poster);
    await tester.pumpAndSettle();
    expect(find.text('Movie 71'), findsOneWidget);
    lists.watched.add(71);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 2 watched & rated'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    auth.dispose();
  });
  for (final width in [320.0, 768.0, 1180.0]) {
    testWidgets('list reflows at $width and increased text size',
        (tester) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = CuratedFixtureAuth();
      addTearDown(auth.dispose);
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
              theme: AppTheme.darkTheme,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(1.7)),
                  child: child!),
              home: CuratedListPage(
                  id: fixtureId, service: CuratedFixtureService()))));
      await tester.pumpAndSettle();
      expect(find.text('Did someone say Christmas?'), findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(AppBar),
              matching: find.text('Did someone say Christmas?')),
          findsOneWidget);
      expect(find.text('Watch challenges'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
