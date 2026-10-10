import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/features/social/presentation/widgets/insights_tab.dart';
import 'package:flixie_app/features/social/presentation/widgets/group_insights/group_insight_review.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'package:flixie_app/models/group_insights.dart';
import 'package:flixie_app/models/user.dart';
import '../../test/support/api_fixture.dart';
import '../../test/support/watchlist_auth.dart';
import '../../test/features/social/group_insights/fixture.dart';

class InsightsAuth extends TestAuth {
  String viewer = 'viewer';
  @override
  User get dbUser => super.dbUser.copyWith(id: viewer);
  void switchAccount() {
    viewer = 'other-viewer';
    ApiClient.setToken(null);
    ApiClient.setToken(viewer);
    notifyListeners();
  }
}

Future<void> insightTap(PatrolTester $, Finder finder) async {
  await Scrollable.ensureVisible($.tester.element(finder), alignment: .5);
  await $.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget);
  await $.tester.tap(finder);
  await $.pumpAndSettle();
}

Future<GoRouter> openInsights(
  PatrolTester $, {
  InsightsAuth? auth,
  MovieRatingPrivacy? privacy,
}) async {
  final viewer = auth ?? InsightsAuth();
  addTearDown(viewer.dispose);
  ApiClient.setToken(viewer.viewer);
  addTearDown(() => ApiClient.setToken(null));
  final router = GoRouter(routes: [
    GoRoute(
        path: '/',
        builder: (_, __) =>
            const Scaffold(body: GroupInsightsTab(groupId: 'fixture'))),
    GoRoute(
        path: '/movies/:id',
        builder: (_, state) => Scaffold(
            appBar: AppBar(),
            body: Text('Movie destination ${state.pathParameters['id']}'))),
    GoRoute(
        path: '/friends/:id',
        builder: (_, state) => Scaffold(
            appBar: AppBar(),
            body: Text('Profile destination ${state.pathParameters['id']}'))),
  ]);
  addTearDown(router.dispose);
  await $.pumpWidgetAndSettle(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: viewer),
        if (privacy != null)
          ChangeNotifierProvider<MovieRatingPrivacy>.value(value: privacy),
      ],
      child:
          MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router)));
  return router;
}

void groupInsightsJourneys(
    void Function(String, Future<void> Function(PatrolTester)) test) {
  test('empty monthly insights can switch to populated all time', ($) async {
    final periods = <String?>[];
    useApiFixture(MockClient((request) async {
      final p = request.url.queryParameters['timeWindow'];
      periods.add(p);
      return insightsResponse(p == 'month' ? {} : insightFixture());
    }));
    await openInsights($);
    expect(find.text('No group insights yet'), findsOneWidget);
    await insightTap($, find.text('All time'));
    expect(find.text('Highlights'), findsOneWidget);
    expect(periods, ['month', 'all']);
    await insightTap($, find.text('All time'));
    expect(periods, hasLength(2));
  });

  test('failed insights load retries and overlapping refresh shares one read',
      ($) async {
    var calls = 0;
    Completer<http.Response>? pending;
    useApiFixture(MockClient((_) async {
      calls++;
      return pending != null
          ? await pending.future
          : insightsResponse(insightFixture(), status: calls == 1 ? 500 : 200);
    }));
    await openInsights($);
    await insightTap($, find.text('Retry'));
    expect(find.text('Highlights'), findsOneWidget);
    pending = Completer<http.Response>();
    final refresh = $.tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh;
    final both = Future.wait([refresh(), refresh()]);
    await $.pump();
    expect(calls, 3);
    pending.complete(insightsResponse(insightFixture()));
    await both;
    await $.pumpAndSettle();
    expect(find.text('Highlights'), findsOneWidget);
  });

  test(
      'spoiler remains hidden until tapped and resets for a replacement review',
      ($) async {
    var review = GroupInsightReview.fromJson(
        (insightFixture()['recentReviews'] as List).single);
    Future<void> show() => $.pumpWidgetAndSettle(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
            body: SingleChildScrollView(
                child: InsightReviewCard(review: review)))));
    await show();
    expect(find.text('The fictional ending is revealed here.'), findsNothing);
    await insightTap($, find.text('Tap to reveal review'));
    expect(find.text('The fictional ending is revealed here.'), findsOneWidget);
    review = GroupInsightReview.fromJson(
        (insightFixture(reviewId: 'review-2')['recentReviews'] as List).single);
    await show();
    expect(find.text('The fictional ending is revealed here.'), findsNothing);
    expect(find.text('Tap to reveal review'), findsOneWidget);
  });

  test('rating privacy and each user badge border survive insights rendering',
      ($) async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final privacy = MovieRatingPrivacy(loadRatings: (_) async => {});
    addTearDown(privacy.dispose);
    await $.tester.runAsync(() async {
      privacy.syncUser('viewer');
      await Future<void>.delayed(Duration.zero);
      await privacy.setEnabled(true);
    });
    useApiFixture(MockClient((_) async => insightsResponse(insightFixture())));
    await openInsights($, privacy: privacy);
    await $.tester.scrollUntilVisible(find.text('Tap to reveal review'), 200);
    await $.pumpAndSettle();
    expect(find.text('8.8/10'), findsNothing);
    expect(find.text('Rate to see score'), findsOneWidget);
    final avatars =
        $.tester.widgetList<ProfileAvatarView>(find.byType(ProfileAvatarView));
    expect(
        avatars.any((a) => a.profileBadges.contains('EARLY_ADOPTER')), isTrue);
    await $.tester.scrollUntilVisible(find.text('@movie_friend'), 200);
    await $.pumpAndSettle();
    expect(
        $.tester
            .widgetList<ProfileAvatarView>(find.byType(ProfileAvatarView))
            .any((a) => a.profileBadges.contains('VERIFIED')),
        isTrue);
    $.tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await $.pumpAndSettle();
    expect(
        $.tester
            .widgetList<ProfileAvatarView>(find.byType(ProfileAvatarView))
            .any((a) => a.profileBadges.contains('FOUNDER')),
        isTrue);
    privacy.ratingSaved('viewer', 348, 7);
    await $.pumpAndSettle();
    expect(find.text('8.8/10'), findsWidgets);
  });

  test('highlight and contributor open the correct movie and profile',
      ($) async {
    useApiFixture(MockClient((_) async => insightsResponse(insightFixture())));
    final router = await openInsights($);
    await insightTap($, find.text('Alien').first);
    expect(find.text('Movie destination 348'), findsOneWidget);
    router.pop();
    await $.pumpAndSettle();
    await $.tester.scrollUntilVisible(find.text('@movie_friend'), 250);
    await insightTap($, find.text('@movie_friend'));
    expect(find.text('Profile destination contributor'), findsOneWidget);
  });

  test(
      'switching accounts removes old insights and rejects old refresh response',
      ($) async {
    final auth = InsightsAuth();
    var calls = 0;
    final old = Completer<http.Response>();
    useApiFixture(MockClient((_) async {
      calls++;
      if (calls == 2) return old.future;
      return insightsResponse(insightFixture(
          title: auth.viewer == 'viewer'
              ? 'Old private film'
              : 'New account film'));
    }));
    await openInsights($, auth: auth);
    final refresh = $.tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await $.pump();
    auth.switchAccount();
    await $.pumpAndSettle();
    expect(find.text('Old private film'), findsNothing);
    expect(find.text('New account film'), findsWidgets);
    old.complete(insightsResponse(insightFixture(title: 'Late old film')));
    await refresh;
    await $.pumpAndSettle();
    expect(find.text('Late old film'), findsNothing);
    expect(find.text('New account film'), findsWidgets);
  });
}
