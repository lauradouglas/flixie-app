import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/presentation/widgets/watch_entry_review_sheet.dart';
import '../../support/watchlist_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/features/social/presentation/pages/watch_requests_screen.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/write_review_sheet.dart';
import '../../support/api_fixture.dart';
import '../../../patrol_test/support/store_screenshot_fixture.dart';
import '../../../patrol_test/support/watch_plan_fixture.dart';

void main() {
  Future<WatchPlanFixture> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'app_review.last_prompt.store-viewer':
          DateTime.now().millisecondsSinceEpoch,
    });
    final api = WatchPlanFixture(status: 'ACCEPTED', scheduled: true);
    useApiFixture(api.client);
    final auth = StoreScreenshotAuth();
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) =>
              const WatchRequestsScreen(initialRequestId: 'patrol-plan')),
    ]);
    addTearDown(auth.dispose);
    addTearDown(router.dispose);
    addTearDown(() => expect(api.unexpected, isEmpty));
    await tester.pumpWidget(storeScreenshotApp(auth, router));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Log watch').first);
    await tester.tap(find.text('Log watch').first);
    await tester.pumpAndSettle();
    return api;
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).first);
    await tester.tap(find.text(text).first);
    await tester.pumpAndSettle();
  }

  testWidgets('save watch then write and publish a linked title and body',
      (tester) async {
    final api = await open(tester);
    await tap(tester, '8');
    await tap(tester, 'Recommend');
    await tester.enterText(
        find.widgetWithText(TextField, 'Watch comment (optional)'),
        'Cinema night with Robin');
    await tap(tester, 'Write a review next');
    expect(find.byType(WriteReviewSheet), findsNothing);
    await tap(tester, 'Save & write review');
    expect(api.diary.length, 1);
    expect(api.reviews, isEmpty);
    expect(api.diary.values.single['reviewText'], 'Cinema night with Robin');
    expect(api.diary.values.single['publishReview'], false);
    expect(find.byType(RewatchLogSheet), findsNothing);
    final editor =
        tester.widget<WriteReviewSheet>(find.byType(WriteReviewSheet));
    expect(editor.initialRating, 8);
    expect(editor.initialRecommended, true);
    expect(editor.watchEntryId, 'fixture-watch');
    final title =
        find.widgetWithText(TextFormField, 'Still thinking about that ending');
    final body =
        find.widgetWithText(TextFormField, 'What made this one memorable?');
    await tester.ensureVisible(title);
    await tester.enterText(title, 'Still terrifying');
    await tester.ensureVisible(body);
    await tester.enterText(body, 'Alien builds tension brilliantly.');
    final spoilerSwitch = find.text('Contains spoilers');
    await tester.ensureVisible(spoilerSwitch);
    await tester.tap(spoilerSwitch);
    await tester.pumpAndSettle();
    await tap(tester, 'Post review');
    expect(api.reviews.single['title'], 'Still terrifying');
    expect(api.reviews.single['body'], 'Alien builds tension brilliantly.');
    expect(api.reviews.single['containsSpoilers'], true);
    expect(api.reviews.single['watchEntryId'], 'fixture-watch');
    expect(api.diary.length, 1);
    expect(find.byType(WriteReviewSheet), findsNothing);
  });

  testWidgets(
      'failed watch save keeps review selection; cancelling editor keeps watch',
      (tester) async {
    final api = await open(tester);
    await tap(tester, 'Write a review next');
    api.failNextPath = '/watch-requests/patrol-plan/watch-confirmations';
    await tap(tester, 'Save & write review');
    expect(api.diary, isEmpty);
    expect(find.byType(WriteReviewSheet), findsNothing);
    expect(find.byType(RewatchLogSheet), findsOneWidget);
    expect(
        tester
            .widget<CheckboxListTile>(
                find.widgetWithText(CheckboxListTile, 'Write a review next'))
            .value,
        true);
    await tap(tester, 'Save & write review');
    expect(find.byType(WriteReviewSheet), findsOneWidget);
    await tester.tap(find
        .descendant(
            of: find.byType(WriteReviewSheet),
            matching: find.byType(IconButton))
        .first);
    await tester.pumpAndSettle();
    expect(api.diary.length, 1);
    expect(api.reviews, isEmpty);
    expect(find.byType(WriteReviewSheet), findsNothing);
  });

  testWidgets('watch can save without opting into a review', (tester) async {
    final api = await open(tester);
    await tap(tester, 'Save watch');
    expect(api.diary.length, 1);
    expect(api.reviews, isEmpty);
    expect(find.byType(WriteReviewSheet), findsNothing);
  });
  testWidgets(
      'editing a compact plan response loads and preserves its review title',
      (tester) async {
    final auth = TestAuth();
    addTearDown(auth.dispose);
    useApiFixture(MockClient((request) async {
      expect(request.url.path, '/users/viewer/movie/348/watches');
      return http.Response(
          jsonEncode([
            {
              'id': 'existing-watch',
              'userId': 'viewer',
              'movieId': 348,
              'reviews': [
                {
                  'title': 'Still terrifying',
                  'body': 'An old favourite.',
                  'containsSpoilers': true
                }
              ],
            }
          ]),
          200,
          headers: {'content-type': 'application/json'});
    }));
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () => showWatchEntryReviewSheet(context,
                          userId: 'viewer',
                          movieId: 348,
                          watchEntryId: 'existing-watch',
                          rating: 8,
                          recommended: false,
                          initialBody: 'An old favourite.',
                          initialContainsSpoilers: true),
                      child: const Text('Edit review'))))),
    ));
    await tap(tester, 'Edit review');
    expect(find.text('Still terrifying'), findsOneWidget);
    expect(find.text('An old favourite.'), findsOneWidget);
    final editor =
        tester.widget<WriteReviewSheet>(find.byType(WriteReviewSheet));
    expect(editor.watchEntryId, 'existing-watch');
    expect(editor.initialRecommended, false);
    expect(
        tester
            .widget<FlixiePill>(
                find.widgetWithText(FlixiePill, 'Contains spoilers'))
            .selected,
        true);
  });
}
