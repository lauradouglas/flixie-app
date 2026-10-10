import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/social/data/community_service.dart';
import 'package:flixie_app/features/social/data/chat_unread_controller.dart';
import 'package:flixie_app/features/social/presentation/pages/community_activity_feed.dart';
import 'package:flixie_app/features/social/presentation/pages/social_screen.dart';
import 'package:flixie_app/features/social/presentation/widgets/social_activity_view.dart';
import 'package:flixie_app/features/social/presentation/widgets/social_groups_view.dart';
import 'package:flixie_app/features/social/presentation/widgets/social_people_view.dart';
import 'social_controllers_test.dart';
import 'package:flixie_app/features/social/presentation/widgets/people_directory.dart';
import 'package:flixie_app/features/social/data/people_cache.dart';
import '../../community_activity_feed_test.dart' show FixtureCommunity, fixture;

class Unread extends ChatUnreadController {
  int value = 0;
  @override
  int get total => value;
  void change() {
    value++;
    notifyListeners();
  }
}

class DelayedFeed extends FixtureCommunity {
  final reads = <Completer<CommunityPage>>[];
  @override
  Future<CommunityPage> load(
      {String? cursor,
      String filter = 'all',
      String sort = 'latest',
      String? owner,
      bool saved = false,
      int? limit}) {
    final work = Completer<CommunityPage>();
    reads.add(work);
    return work.future;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiClient.useClientForTesting(MockClient((r) async {
      if (r.url.path == '/community/activity-state') {
        return http.Response(
            jsonEncode({
              'items': [
                for (final t in jsonDecode(r.body)['targets'])
                  {
                    ...t,
                    'saved': false,
                    'reactions': {'counts': {}, 'mine': null}
                  }
              ]
            }),
            200);
      }
      return http.Response('{}', 503);
    }));
  });
  tearDown(() => ApiClient.useClientForTesting(null));
  testWidgets('Social visits lazily, retains tabs, and isolates unread updates',
      (t) async {
    final auth = SocialAuth();
    final unread = Unread();
    addTearDown(auth.dispose);
    addTearDown(unread.dispose);
    await t.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<ChatUnreadController>.value(value: unread),
        ],
        child: MaterialApp(
            theme: AppTheme.darkTheme, home: const SocialScreen())));
    await t.pumpAndSettle();
    expect(find.byType(SocialPeopleView), findsNothing);
    expect(find.byType(SocialGroupsView), findsNothing);
    final feed = t.widget<SocialActivityView>(find.byType(SocialActivityView));
    unread.change();
    await t.pump();
    expect(t.widget<SocialActivityView>(find.byType(SocialActivityView)),
        same(feed));
    expect(find.text('1'), findsOneWidget);
    auth.notifyOnly();
    await t.pump();
    expect(t.widget<SocialActivityView>(find.byType(SocialActivityView)),
        same(feed));
    await t.tap(find.text('Groups'));
    await t.pumpAndSettle();
    final state = t.state(find.byType(SocialGroupsView));
    await t.tap(find.text('Activity'));
    await t.pumpAndSettle();
    await t.tap(find.text('Groups'));
    await t.pumpAndSettle();
    expect(t.state(find.byType(SocialGroupsView)), same(state));
    auth.viewer = 'other';
    auth.notifyOnly();
    await t.pumpAndSettle();
    expect(t.state(find.byType(SocialGroupsView)), isNot(same(state)));
    expect(find.byType(SocialActivityView), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('feed polling pauses when hidden and backgrounded, then resumes',
      (t) async {
    final service = FixtureCommunity();
    Widget app(bool active) => MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
            body: CommunityActivityFeed(service: service, active: active)));
    await t.pumpWidget(app(true));
    await t.pumpAndSettle();
    expect(service.cursors, hasLength(1));
    await t.pump(const Duration(minutes: 1));
    await t.pumpAndSettle();
    expect(service.cursors, hasLength(2));
    await t.pumpWidget(app(false));
    await t.pumpAndSettle();
    await t.pump(const Duration(minutes: 2));
    expect(service.cursors, hasLength(2));
    await t.pumpWidget(app(true));
    await t.pumpAndSettle();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await t.pump(const Duration(minutes: 2));
    expect(service.cursors, hasLength(2));
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump(const Duration(minutes: 1));
    await t.pumpAndSettle();
    expect(service.cursors, hasLength(3));
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('hidden People defers starred-friend resume reads until visible',
      (t) async {
    PeopleCache.instance.selectAccount(null);
    var reads = 0;
    ApiClient.useClientForTesting(MockClient((r) async {
      if (r.url.path == '/community/stars') reads++;
      return http.Response(
          jsonEncode(r.url.path == '/community/stars'
              ? {'ids': []}
              : {'items': [], 'nextCursor': null}),
          200);
    }));
    Widget app(bool active) => MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
            body: PeopleDirectory(
                userId: 'poll-fixture', friends: const [], active: active)));
    await t.pumpWidget(app(false));
    await t.pumpAndSettle();
    expect(reads, 1);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpAndSettle();
    expect(reads, 1);
    await t.pumpWidget(app(true));
    await t.pumpAndSettle();
    expect(reads, 2);
    await t.pumpWidget(const SizedBox());
    PeopleCache.instance.selectAccount(null);
  });
  testWidgets('an open feed action sheet closes when the account changes',
      (t) async {
    final auth = SocialAuth();
    addTearDown(auth.dispose);
    await t.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
                body: CommunityActivityFeed(service: FixtureCommunity())))));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Activity options').first);
    await t.pumpAndSettle();
    expect(find.text('Hide this post'), findsOneWidget);
    auth.viewer = 'other';
    auth.notifyOnly();
    await t.pumpAndSettle();
    expect(find.text('Hide this post'), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('standalone community feed drops an old account response',
      (t) async {
    final auth = SocialAuth();
    final service = DelayedFeed();
    addTearDown(auth.dispose);
    await t.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(body: CommunityActivityFeed(service: service)))));
    await t.pump();
    auth.viewer = 'other';
    auth.notifyOnly();
    await t.pump();
    await t.pump();
    expect(service.reads, hasLength(2));
    service.reads[1].complete(CommunityPage([fixture('new')], null));
    await t.pumpAndSettle();
    service.reads[0].complete(CommunityPage([fixture('old')], null));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('community:movie-review:new')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('community:movie-review:old')), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
