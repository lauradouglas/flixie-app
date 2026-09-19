import 'package:flixie_app/core/safety/safety_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/group_plan/group_watch_plan_recap.dart';
import 'package:flixie_app/models/group_watch_request.dart';

GroupWatchRequest fixture({bool allMissed = false}) =>
    GroupWatchRequest.fromJson({
      'id': 'plan',
      'groupId': 'group',
      'requesterId': 'me',
      'movieTitle': 'Moana',
      'status': 'COMPLETED',
      'responses': [
        for (final item in [
          ('me', 'Laura', 9, true),
          ('friend', 'Bundha', 8, false)
        ])
          {
            'responderId': item.$1,
            'username': item.$2,
            'status': 'ACCEPTED',
            if (!allMissed) 'watchedAt': '2026-09-11T12:00:00Z',
            if (allMissed) 'missedAt': '2026-09-11T12:00:00Z',
            'rating': item.$3,
            'recommended': item.$4
          },
        {
          'responderId': 'missed',
          'username': 'Jamie',
          'status': 'ACCEPTED',
          'missedAt': '2026-09-11T12:00:00Z',
          'rating': 10,
          'recommended': true
        },
      ],
    });

void main() {
  setUp(SafetyService.reset);
  setUpAll(() async {
    final font = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  Future<void> show(WidgetTester tester,
      {double width = 430,
      double scale = 1,
      bool allMissed = false,
      GroupWatchRequest? request,
      VoidCallback? onChat}) async {
    await http.runWithClient(() => SafetyService.blockedUsers(),
        () => MockClient((_) async => http.Response('[]', 200)));
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Manrope'),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          backgroundColor: FlixieColors.background,
          body: SingleChildScrollView(
              child: Padding(
            padding: const EdgeInsets.all(20),
            child: GroupWatchPlanRecap(
                request: request ?? fixture(allMissed: allMissed),
                currentUserId: 'me',
                members: const [],
                onOpenChat: onChat ?? () {}),
          )),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'recap excludes missed attendees from scores and recommendations and opens chat',
      (tester) async {
    var opened = false;
    await show(tester, onChat: () => opened = true);
    expect(find.text('4.3'), findsOneWidget);
    expect(find.text('1 recommend'), findsOneWidget);
    expect(find.text('1 don’t recommend'), findsOneWidget);
    expect(find.text('Didn’t make it (1)'), findsOneWidget);
    expect(find.text('Jamie'), findsOneWidget);
    expect(find.text('5.0'), findsNothing);
    await expectLater(
        find.byType(Scaffold), matchesGoldenFile('goldens/group_recap.png'));
    await tester.tap(find.text('Open group chat'));
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small phone with large text reflows without overflow',
      (tester) async {
    await show(tester, width: 320, scale: 1.7);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Open group chat'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(Scaffold),
        matchesGoldenFile('goldens/group_recap_large_text.png'));
  });

  testWidgets('all missed has no fabricated ratings or recommendations',
      (tester) async {
    await show(tester, allMissed: true, width: 768);
    expect(find.text('No ratings yet'), findsOneWidget);
    expect(find.text('0 recommend'), findsOneWidget);
    expect(find.text('0 don’t recommend'), findsOneWidget);
    expect(find.text('Didn’t make it (3)'), findsOneWidget);
    expect(find.text('No one logged a viewing for this plan.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('unrated viewers and optional reviews stay visible',
      (tester) async {
    final request = GroupWatchRequest.fromJson({
      'id': 'plan',
      'groupId': 'group',
      'status': 'COMPLETED',
      'movieTitle': 'Moana',
      'responses': [
        {
          'responderId': 'me',
          'status': 'ACCEPTED',
          'watchedAt': '2026-09-11T12:00:00Z',
          'reviewText': 'A lovely evening with the group.'
        },
      ],
    });
    await show(tester, request: request);
    expect(find.text('Watched · Not rated'), findsOneWidget);
    expect(find.text('A lovely evening with the group.'), findsOneWidget);
    expect(find.text('0 don’t recommend'), findsOneWidget);
    expect(find.text('1 person hasn’t recommended either way'), findsOneWidget);
  });
  testWidgets(
      'other users reviews are reportable and disappear immediately after blocking',
      (tester) async {
    final request = GroupWatchRequest.fromJson({
      'id': 'plan',
      'groupId': 'group',
      'status': 'COMPLETED',
      'movieTitle': 'Moana',
      'responses': [
        {
          'responderId': 'friend',
          'username': 'Bundha',
          'status': 'ACCEPTED',
          'watchedAt': '2026-09-11T12:00:00Z',
          'reviewText': 'An enjoyable film.',
          'rating': 8
        }
      ],
    });
    await show(tester, request: request);
    expect(find.text('An enjoyable film.'), findsOneWidget);
    expect(find.text('Report'), findsOneWidget);
    expect(find.text('Block user'), findsOneWidget);
    await http.runWithClient(() => SafetyService.block('friend'),
        () => MockClient((_) async => http.Response('{}', 200)));
    await tester.pumpAndSettle();
    expect(find.text('An enjoyable film.'), findsNothing);
    expect(find.text('Bundha'), findsNothing);
    expect(find.text('No ratings yet'), findsOneWidget);
  });
}
