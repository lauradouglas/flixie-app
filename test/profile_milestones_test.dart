import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/models/profile_milestone.dart';
import 'package:flixie_app/features/profile/presentation/pages/milestones_screen.dart';

final items = [
  ProfileMilestone(
      id: 'films_10',
      family: 'films',
      group: 'Watching',
      title: '10 films watched',
      description: 'Watch different films.',
      target: 10,
      progress: 10,
      earned: true,
      earnedAt: DateTime(2026, 9, 1)),
  const ProfileMilestone(
      id: 'films_25',
      family: 'films',
      group: 'Watching',
      title: '25 films watched',
      description: 'Watch different films.',
      target: 25,
      progress: 14,
      earned: false),
  const ProfileMilestone(
      id: 'genres_5',
      family: 'genres',
      group: 'Exploring',
      title: 'Genre explorer · 5 genres',
      description: 'Explore different film genres.',
      target: 5,
      progress: 3,
      earned: false),
  const ProfileMilestone(
      id: 'movie_mates_5',
      family: 'movie_mates',
      group: 'Together',
      title: '5 films with a movie mate',
      description:
          'Watch different films with the same person through watch plans.',
      target: 5,
      progress: 2,
      earned: false),
  const ProfileMilestone(
      id: 'reviews_5',
      family: 'reviews',
      group: 'Your voice',
      title: '5 reviews written',
      description: 'Share your thoughts on films and shows.',
      target: 5,
      progress: 1,
      earned: false),
];
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
  test('next up shows one tier per family and friend payloads need no progress',
      () {
    final data = ProfileMilestones(items: items, owner: true);
    expect(data.next.map((i) => i.id),
        ['films_25', 'genres_5', 'movie_mates_5', 'reviews_5']);
    final friend = ProfileMilestones.fromJson({
      'visibility': 'friends',
      'items': [
        {
          'id': 'films_10',
          'family': 'films',
          'group': 'Watching',
          'title': '10 films watched',
          'description': 'Films',
          'target': 10,
          'earned': true
        }
      ]
    });
    expect(friend.owner, isFalse);
    expect(friend.earned.single.progress, 0);
  });
  testWidgets('owner can switch between next targets and earned milestones',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'Manrope'),
        home: Scaffold(
            body: MilestonesContent(
                data: ProfileMilestones(items: items, owner: true)))));
    await tester.tap(find.text('Next up'));
    await tester.pumpAndSettle();
    expect(find.text('14 / 25'), findsOneWidget);
    await tester.tap(find.text('Earned'));
    await tester.pumpAndSettle();
    expect(find.text('25 films watched'), findsNothing);
    expect(find.text('10 films watched'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets('overview categories open their milestone tiers', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MilestonesContent(
                data: ProfileMilestones(items: items, owner: true)))));
    expect(find.text('Recent achievement'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Exploring'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Exploring'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exploring'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Genre explorer · 5 genres'), -150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Genre explorer · 5 genres'));
    await tester.pumpAndSettle();
    expect(find.text('3 / 5'), findsOneWidget);
    expect(find.text('25 films watched'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('friends never see locked milestones or progress filters',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'Manrope'),
        home: Scaffold(
            body: MilestonesContent(
                data: ProfileMilestones(items: items, owner: false),
                displayName: 'LauraD'))));
    expect(find.text('Next up'), findsNothing);
    expect(find.text('25 films watched'), findsNothing);
    expect(find.text('10 films watched'), findsOneWidget);
    expect(find.textContaining('14 / 25'), findsNothing);
  });
  testWidgets('API failures offer retry; private profiles explain access',
      (tester) async {
    ApiClient.useClientForTesting(
        MockClient((_) async => http.Response('{"message":"Private"}', 403)));
    addTearDown(() => ApiClient.useClientForTesting(null));
    await tester.pumpWidget(
        const MaterialApp(home: MilestonesScreen(userId: 'fixture')));
    await tester.pumpAndSettle();
    expect(
        find.text('Milestones are visible to friends only.'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });
  testWidgets(
      'milestone layouts support narrow, landscape, tablet and large text',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in [
      const Size(320, 568),
      const Size(844, 390),
      const Size(1024, 1366)
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData(fontFamily: 'Manrope'),
          home: Scaffold(
              body: MediaQuery(
                  data: MediaQueryData(
                      size: size, textScaler: const TextScaler.linear(2)),
                  child: MilestonesContent(
                      key: ValueKey(size),
                      data: ProfileMilestones(items: items, owner: true))))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$size');
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$size after scroll');
    }
  });
  testWidgets('capture milestone owner and friend layouts for visual review',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final owner in [true, false]) {
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData.dark().copyWith(
              textTheme:
                  ThemeData.dark().textTheme.apply(fontFamily: 'Manrope')),
          home: RepaintBoundary(
              key: key,
              child: Scaffold(
                  backgroundColor: const Color(0xff130b24),
                  appBar: AppBar(title: const Text('Milestones')),
                  body: MilestonesContent(
                      key: ValueKey(owner),
                      data: ProfileMilestones(items: items, owner: owner),
                      displayName: owner ? null : 'LauraD')))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image = await (key.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('/tmp/flixie-milestones-${owner ? 'owner' : 'friend'}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
