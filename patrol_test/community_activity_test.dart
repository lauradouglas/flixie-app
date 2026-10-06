import 'package:flixie_app/features/home/presentation/widgets/home_community_section.dart';
import 'package:flixie_app/features/social/data/friend_activity_service.dart';
import 'package:flixie_app/features/social/presentation/pages/friend_activity_screen.dart';
import 'package:flixie_app/features/social/presentation/pages/community_post_screen.dart';
import 'package:flixie_app/features/social/presentation/pages/community_profile_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/features/social/presentation/controllers/friend_actions_controller.dart';
import 'support/fixture_app.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/core/navigation/instant_swipe_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/social/data/community_service.dart';
import 'package:flixie_app/features/social/presentation/pages/community_activity_feed.dart';
import 'package:flixie_app/models/activity_list_item.dart';

class _CommunityFixture extends CommunityService
    implements FriendActivityService {
  @override
  Future<bool> follows(String path) async => false;
  @override
  Future<Map<String, dynamic>> replies(ActivityListItem item,
          {String? cursor, String? parent}) async =>
      {'items': [], 'nextCursor': null, 'repliesEnabled': true};

  bool enabled = false, bookmarked = false;
  final entries = <ActivityComment>[
    const ActivityComment(
        id: 'fixture-spoiler',
        author:
            FriendshipUser(id: 'fixture-reader', username: 'Another reader'),
        body: 'A surprise ending.',
        containsSpoilers: true),
  ];
  @override
  Future<void> deleteComment(ActivityListItem item, String id) async {
    entries.removeWhere((entry) => entry.id == id);
  }

  @override
  Future<CommunityProfile> profile(String id) async => const CommunityProfile(
      user: FriendshipUser(
          id: 'fixture-author',
          username: 'Fixture reviewer',
          profileBadges: ['founder']),
      bio: 'I love thoughtful films.');
  @override
  Future<ActivityListItem> post(String owner, String type, String id) async =>
      (await load()).items.single;
  @override
  Future<ActivityCommentPage> comments(ActivityListItem item,
          {String? cursor}) async =>
      ActivityCommentPage(List.of(entries), null);
  @override
  Future<void> comment(ActivityListItem item,
      {required String id,
      required String body,
      required bool spoilers}) async {
    entries.add(ActivityComment(
        id: id,
        author: const FriendshipUser(id: 'fixture-viewer', username: 'Me'),
        body: body,
        containsSpoilers: spoilers));
  }

  @override
  Future<Map<String, dynamic>> settings() async => {
        'communitySharing': enabled,
        'communityProfileDetails': false,
        'communityReplyNotifications': true,
        'communityReactionNotifications': true
      };
  @override
  Future<void> updateSettings(Map<String, bool> values) async {}
  @override
  Future<bool> isSaved(ActivityListItem item) async => bookmarked;
  @override
  Future<void> save(ActivityListItem item, bool saved) async {
    bookmarked = saved;
  }

  @override
  Future<bool> sharing() async => enabled;
  @override
  Future<void> setSharing(bool value) async {
    enabled = value;
  }

  @override
  Future<CommunityPage> load(
          {String? cursor,
          String filter = 'all',
          String sort = 'latest',
          int? limit,
          String? owner,
          bool saved = false}) async =>
      CommunityPage([
        ActivityListItem.fromJson({
          'id': 'review',
          'userId': 'fixture-author',
          'username': 'Fixture reviewer',
          'type': 'movie-review',
          'movieId': 101,
          'movie': {'title': 'Fixture film'},
          'rating': 9,
          'body': 'A community recommendation.',
          'createdAt': '2026-09-24T12:00:00Z',
          'updatedAt': '2026-09-24T12:00:00Z'
        })
      ], null);
}

class _CommunityAuth extends FixtureAuth {
  @override
  void updateCachedFriends(FriendsData friends) {}
}

class _CommunityFriends extends FriendActionsController {
  bool sent = false;
  @override
  Future<FriendsData> getFriends(String userId) async =>
      FriendsData(friendships: [], pendingFriends: [], requestedFriends: [
        if (sent)
          const Friendship(
              id: 'fixture-request',
              friend: FriendshipUser(
                  id: 'fixture-author', username: 'Fixture reviewer'),
              createdAt: '',
              updatedAt: ''),
      ]);
  @override
  Future<void> sendFriendRequest(Map<String, dynamic> body) async {
    expect(body['recipientId'], 'fixture-author');
    expect(body['type'], 'FRIEND_REQUEST');
    sent = true;
  }
}

void main() {
  patrolTest('Home Community opens a post and the public feed', ($) async {
    final service = _CommunityFixture();
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
              body: SafeArea(
                  child: SingleChildScrollView(
                      child: HomeCommunitySection(
                          userId: 'fixture-viewer', service: service))))),
      GoRoute(
          path: '/community/posts/:ownerId/:type/:id',
          pageBuilder: (_, state) => InstantSwipePage<void>(
              key: state.pageKey,
              child: CommunityPostScreen(
                  ownerId: 'fixture-author',
                  type: 'movie-review',
                  postId: 'review',
                  service: service))),
      GoRoute(
          path: '/friends-activity',
          builder: (_, state) => Scaffold(
              body: Text('Activity tab: ${state.uri.queryParameters['tab']}'))),
    ]);
    addTearDown(router.dispose);
    await $.pumpWidgetAndSettle(
        MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router));
    await $('View post').scrollTo().tap();
    await $('Post').waitUntilVisible();
    await $(find.byTooltip('Save post')).scrollTo().tap();
    expect(service.bookmarked, true);
    await $.tester.dragFrom(const Offset(1, 250), const Offset(350, 0));
    await $.pumpAndSettle();
    await $('See all').scrollTo().tap();
    await $('Activity tab: community').waitUntilVisible();
  });

  patrolTest('Public replies and Friends comments have separate composers',
      ($) async {
    final service = _CommunityFixture();
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => CommunityProfileScreen(
              userId: 'fixture-author', service: service)),
      GoRoute(
          path: '/community/posts/:ownerId/:type/:id',
          builder: (_, __) => CommunityPostScreen(
              ownerId: 'fixture-author',
              type: 'movie-review',
              postId: 'review',
              service: service)),
      GoRoute(
          path: '/friends/activity/:ownerId/:type/:id',
          builder: (_, __) => FriendActivityScreen(
              ownerId: 'fixture-author',
              type: 'movie-review',
              postId: 'review',
              service: service)),
    ]);
    addTearDown(router.dispose);
    await $.pumpWidgetAndSettle(
        MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router));
    await $('I love thoughtful films.').waitUntilVisible();
    await $('View post').scrollTo().tap();
    await $(find.byTooltip('Save post')).scrollTo().tap();
    expect(service.bookmarked, true);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Comments'), findsNothing);
    router.go('/friends/activity/fixture-author/movie-review/review');
    await $.pumpAndSettle();
    await $('Show comment · contains spoilers').scrollTo().tap();
    await $('A surprise ending.').waitUntilVisible();
    await $(TextField).scrollTo().enterText('Loved this review!');
    await $(find.byTooltip('Post comment')).scrollTo().tap();
    expect(service.entries.last.body, 'Loved this review!');
    await $.platform.mobile.pressHome();
    await $.platform.mobile.openApp();
    await $('Loved this review!').scrollTo();
  });

  patrolTest('add a friend directly from a Community post', ($) async {
    final auth = _CommunityAuth();
    final friends = _CommunityFriends();
    addTearDown(auth.dispose);
    await http.runWithClient(() async {
      await $.pumpWidgetAndSettle(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                  body: SafeArea(
                      child: CommunityActivityFeed(
                          service: _CommunityFixture(),
                          friendActions: friends))))));
      await $('Add friend').scrollTo().tap();
      await $('Request sent').waitUntilVisible();
      expect(friends.sent, true);
      await $.platform.mobile.pressHome();
      await $.platform.mobile.openApp();
      await $('Request sent').waitUntilVisible();
      await $.pumpWidgetAndSettle(const SizedBox());
    }, () => MockClient((_) async => http.Response('{}', 200)));
  });

  patrolTest('community consent persists and a review opens its film',
      ($) async {
    final service = _CommunityFixture();
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
              body: SafeArea(child: CommunityActivityFeed(service: service)))),
      GoRoute(
          path: '/movies/:id',
          builder: (_, __) =>
              const Scaffold(body: Text('Community film destination'))),
    ]);
    addTearDown(router.dispose);
    await $.pumpWidgetAndSettle(
        MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router));
    await $(find.byTooltip('Around Flixie sharing')).tap();
    await $(find.descendant(
            of: find.widgetWithText(SwitchListTile, 'Share on Around Flixie'),
            matching: find.byType(Switch)))
        .tap();
    expect(service.enabled, true);
    await $(find.byTooltip('Close settings')).tap();
    await $('Fixture film').scrollTo().tap();
    await $('Community film destination').waitUntilVisible();
    await $.platform.mobile.pressHome();
    await $.platform.mobile.openApp();
    await $('Community film destination').waitUntilVisible();
  });
}
