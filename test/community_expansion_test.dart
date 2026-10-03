import 'package:go_router/go_router.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_tile.dart';
import 'package:flixie_app/features/social/data/community_service.dart';
import 'package:flixie_app/core/auth/notification_deep_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/activity_reaction.dart';
import 'package:flixie_app/features/profile/presentation/widgets/compact_activity_post.dart';
import 'package:flixie_app/features/social/presentation/widgets/community_replies.dart';
import 'package:flixie_app/features/social/presentation/widgets/community_follow_button.dart';
import 'package:flixie_app/features/social/presentation/pages/community_activity_feed.dart';
import 'package:flixie_app/features/social/presentation/pages/community_people_screen.dart';
import 'community_activity_feed_test.dart' as fixtures;

class ExpansionFixture extends fixtures.FixtureCommunity {
  int followingLoads = 0;
  bool newPost = false, hasInvitation = false;
  String? invitationAction;
  @override
  Future<CommunityPage> load(
          {String? cursor,
          String filter = "all",
          String sort = "latest",
          String? owner,
          bool saved = false,
          int? limit}) async =>
      newPost
          ? CommunityPage([fixtures.fixture("new")], null)
          : await super.load(
              cursor: cursor,
              filter: filter,
              sort: sort,
              owner: owner,
              saved: saved);
  bool followValue = false, repliesEnabled = true, failReply = true;
  String? preference;
  final sent = <String>[];
  final publicReplies = <Map<String, dynamic>>[];
  @override
  Future<CommunityPage> following(
      {String? cursor, String filter = 'all', String sort = 'latest'}) async {
    followingLoads++;
    return const CommunityPage([], null);
  }

  @override
  Future<bool> follows(String path) async => followValue;
  @override
  Future<void> follow(String path, bool value) async {
    followValue = value;
  }

  @override
  Future<Map<String, dynamic>> replies(ActivityListItem item,
          {String? cursor, String? parent}) async =>
      {
        'items': publicReplies.where((r) => r['parentId'] == parent).toList(),
        'nextCursor': null,
        'repliesEnabled': repliesEnabled
      };
  @override
  Future<void> reply(ActivityListItem item,
      {required String id,
      required String body,
      required bool spoilers,
      String? parent}) async {
    sent.add(id);
    if (failReply) throw Exception('offline');
    publicReplies.add({
      'id': id,
      'body': body,
      'containsSpoilers': spoilers,
      'parentId': parent,
      'user': {
        'id': 'reader',
        'username': 'Reader',
        'profileBadges': ['founder']
      }
    });
  }

  @override
  Future<void> feedPreference(ActivityListItem item, String action) async {
    preference = action;
  }

  @override
  Future<List<Map<String, dynamic>>> people() async => [
        {
          'user': {
            'id': 'reader',
            'username': 'Reader',
            'profileBadges': ['founder']
          },
          'sharedFavourites': [
            {'id': 1, 'title': 'Arrival'}
          ]
        }
      ];
  @override
  Future<List<Map<String, dynamic>>> invitations() async => hasInvitation
      ? [
          {
            'listId': 'list',
            'userId': 'viewer',
            'name': 'Weekend picks',
            'owner': {'id': 'owner', 'username': 'Owner'}
          }
        ]
      : [];
  @override
  Future<void> invitation(String listId, String userId, String action) async {
    invitationAction = action;
    hasInvitation = false;
  }
}

void main() {
  testWidgets('new posts wait for the explicit load button', (tester) async {
    final service = ExpansionFixture();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CommunityActivityFeed(service: service))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('community:movie-review:first')),
        findsOneWidget);
    service.newPost = true;
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(find.text('New posts available'), findsOneWidget);
    expect(find.byKey(const ValueKey('community:movie-review:first')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('community:movie-review:new')), findsNothing);
    await tester.tap(find.text('New posts available'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('community:movie-review:new')),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('accepting a list invitation opens the editable list',
      (tester) async {
    final service = ExpansionFixture()..hasInvitation = true;
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => CommunityPeopleScreen(service: service)),
      GoRoute(
          path: '/movie-lists/:id',
          builder: (_, state) => Scaffold(
              body: Text('Editable: ${state.uri.queryParameters['canEdit']}')))
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept invitation'));
    await tester.pumpAndSettle();
    expect(service.invitationAction, 'accept');
    expect(find.text('Editable: true'), findsOneWidget);
  });

  test(
      'public reply and list invitation notifications open their community destination',
      () {
    expect(
        notificationDeepLinkPath({
          'type': 'COMMUNITY_REPLY',
          'route': '/movies/1',
          'communityRoute': '/community/posts/owner/movie-review/post'
        }),
        '/community/posts/owner/movie-review/post');
    expect(
        notificationDeepLinkPath({
          'type': 'LIST_SHARED',
          'category': 'community',
          'route': '/movie-lists/list',
          'communityRoute': '/community/people'
        }),
        '/community/people');
  });
  testWidgets(
      'following switches to followed authors without mixing Discover posts',
      (tester) async {
    final service = ExpansionFixture();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CommunityActivityFeed(service: service))));
    await tester.pumpAndSettle();
    expect(find.byType(ActivityTile), findsOneWidget);
    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();
    expect(service.followingLoads, 1);
    expect(find.byType(ActivityTile), findsNothing);
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
    expect(find.byType(ActivityTile), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reactions display individual emoji and counts', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: CompactActivityPost(
                    item: fixtures.fixture('post'),
                    label: 'Reviewed a film',
                    age: '1h',
                    reactions: const ActivityReactionSummary(
                        counts: {'❤️': 2, '🔥': 1}))))));
    expect(find.text('❤️'), findsOneWidget);
    expect(find.text('🔥'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });
  testWidgets('public replies preserve failed drafts and spoiler protection',
      (tester) async {
    final service = ExpansionFixture();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: CommunityReplies(
                    item: fixtures.fixture('post'), service: service)))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'A spoiler reply');
    await tester.tap(find.text('Contains spoilers'));
    await tester.pump();
    await tester.tap(find.text('Post reply'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'A spoiler reply');
    service.failReply = false;
    await tester.tap(find.text('Post reply'));
    await tester.pumpAndSettle();
    expect(service.sent[0], service.sent[1]);
    expect(find.text('Show reply · contains spoilers'), findsOneWidget);
    expect(find.text('A spoiler reply'), findsNothing);
    await tester.tap(find.text('Show reply · contains spoilers'));
    await tester.pump();
    expect(find.text('A spoiler reply'), findsOneWidget);
    await tester.tap(find.text('View thread / reply'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
  });
  testWidgets('disabled public replies have no composer', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CommunityReplies(
                item: fixtures.fixture('post'),
                service: ExpansionFixture()..repliesEnabled = false))));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('The author has turned off replies.'), findsOneWidget);
  });
  testWidgets('follow list toggles persisted follow state', (tester) async {
    final service = ExpansionFixture();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CommunityFollowButton(
                path: 'lists/list', service: service, list: true))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Follow list'));
    await tester.pumpAndSettle();
    expect(service.followValue, true);
    expect(find.text('Following list'), findsOneWidget);
    await tester.tap(find.text('Following list'));
    await tester.pumpAndSettle();
    expect(service.followValue, false);
  });
  testWidgets('taste suggestions explain actual shared favourites',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: CommunityPeopleScreen(service: ExpansionFixture())));
    await tester.pumpAndSettle();
    expect(find.text('You both love Arrival'), findsOneWidget);
  });
  testWidgets('hide post persists preference and removes the card',
      (tester) async {
    final service = ExpansionFixture();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CommunityActivityFeed(service: service))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Activity options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide this post'));
    await tester.pumpAndSettle();
    expect(service.preference, 'hide');
    expect(find.byType(ActivityTile), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
