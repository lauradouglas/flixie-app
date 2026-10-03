import 'package:flixie_app/features/social/data/friend_activity_service.dart';
import 'package:flixie_app/features/social/presentation/pages/friend_activity_screen.dart';
import 'package:flixie_app/features/social/presentation/pages/community_profile_screen.dart';
import 'package:flixie_app/core/utils/notification_destination.dart';
import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/features/profile/presentation/widgets/notification_inbox_card.dart';
import 'package:flixie_app/features/social/presentation/widgets/community_bookmark_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/features/social/data/community_service.dart';
import 'package:flixie_app/features/social/presentation/pages/community_post_screen.dart';
import 'package:flixie_app/features/social/presentation/widgets/community_preferences.dart';
import 'community_activity_feed_test.dart' as fixtures;

class DiscussionFixture extends fixtures.FixtureCommunity
    implements FriendActivityService {
  final ids = <String>[];
  final bodies = <String>[];
  bool rejectReply = true;
  bool? submittedSpoilers;
  final entries = <ActivityComment>[
    const ActivityComment(
        id: 'spoiler',
        author: FriendshipUser(
            id: 'reader', username: 'Reader', profileBadges: ['founder']),
        body: 'The ending reveals everything.',
        containsSpoilers: true),
  ];
  @override
  Future<void> deleteComment(ActivityListItem item, String id) async {
    entries.removeWhere((entry) => entry.id == id);
  }

  @override
  Future<CommunityProfile> profile(String id) async => const CommunityProfile(
          user: FriendshipUser(
              id: 'friend',
              username: 'A friend with a long name',
              profileBadges: ['founder']),
          bio: 'I love thoughtful films and sharing recommendations.',
          favourites: [
            {
              'id': 1,
              'title': 'A favourite film with a meaningful and lengthy title'
            }
          ]);
  @override
  Future<ActivityListItem> post(String owner, String type, String id) async =>
      fixtures.fixture(id);
  @override
  Future<ActivityCommentPage> comments(ActivityListItem item,
          {String? cursor}) async =>
      ActivityCommentPage(List.of(entries), null);
  @override
  Future<void> comment(ActivityListItem item,
      {required String id,
      required String body,
      required bool spoilers}) async {
    ids.add(id);
    bodies.add(body);
    submittedSpoilers = spoilers;
    if (rejectReply) throw Exception('offline');
    entries.add(ActivityComment(
        id: id,
        author: const FriendshipUser(id: 'me', username: 'Me'),
        body: body,
        containsSpoilers: spoilers));
  }
}

void main() {
  for (final scenario in [
    (const Size(320, 700), 1.0),
    (const Size(900, 500), 2.0),
    (const Size(768, 1024), 1.5)
  ]) {
    testWidgets(
        'public profile and discussion reflow at ${scenario.$1} / ${scenario.$2}',
        (tester) async {
      tester.view.physicalSize = scenario.$1;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = DiscussionFixture();
      Widget shell(Widget page) => MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
              data: MediaQueryData(
                  size: scenario.$1,
                  textScaler: TextScaler.linear(scenario.$2)),
              child: page));
      await tester.pumpWidget(
          shell(CommunityProfileScreen(userId: 'friend', service: service)));
      await tester.pumpAndSettle();
      expect(find.text('I love thoughtful films and sharing recommendations.'),
          findsOneWidget);
      await tester.scrollUntilVisible(find.text('View post'), 250,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(shell(FriendActivityScreen(
          ownerId: 'friend',
          type: 'movie-review',
          postId: 'first',
          service: service)));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byTooltip('Post comment'), 250,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Community posts show public replies without private comments',
      (tester) async {
    final service = DiscussionFixture();
    await tester.pumpWidget(MaterialApp(
        home: CommunityPostScreen(
            ownerId: 'friend',
            type: 'movie-review',
            postId: 'first',
            service: service)));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Comments'), findsNothing);
    expect(find.text('The ending reveals everything.'), findsNothing);
    expect(find.text('Post'), findsOneWidget);
  });
  for (final type in [
    FlixieNotification.communityReply,
    FlixieNotification.communityReaction
  ]) {
    test('$type opens the exact discussion without a request action', () {
      final n = FlixieNotification(
          userId: 'me',
          type: type,
          message: '',
          data: const {'route': '/community/posts/me/movie-review/review-7'});
      expect(notificationDestination(n),
          '/community/posts/me/movie-review/review-7');
      expect(notificationNeedsResponse(n), false);
      expect(notificationHeadline(n), contains('your community post'));
    });
  }
  testWidgets(
      'bookmarks survive remount and failed removal keeps the saved state',
      (tester) async {
    final service = fixtures.FixtureCommunity();
    Widget bookmark() => MaterialApp(
        home: Scaffold(
            body: CommunityBookmarkButton(
                item: fixtures.fixture('first'), service: service)));
    await tester.pumpWidget(bookmark());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save post'));
    await tester.pumpAndSettle();
    expect(service.savedPosts, contains('first'));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(bookmark());
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);
    service.fail = true;
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(service.savedPosts, contains('first'));
    expect(find.text('Saved'), findsOneWidget);
    service.fail = false;
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(service.savedPosts, isEmpty);
    expect(find.text('Save post'), findsOneWidget);
  });

  testWidgets('filters restart paging and saved posts use their own feed',
      (tester) async {
    final service = fixtures.FixtureCommunity();
    await tester.pumpWidget(fixtures.app(service));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Films'));
    await tester.pumpAndSettle();
    expect(service.queries.last, 'films:for-you:false');
    expect(service.cursors.last, isNull);
    await tester.tap(find.text('For you'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Popular').last);
    await tester.pumpAndSettle();
    expect(service.queries.last, 'films:popular:false');
    await tester.tap(find.text('Saved').first);
    await tester.pumpAndSettle();
    expect(service.queries.last.endsWith(':true'), isTrue);
  });
  testWidgets(
      'profile consent and notification preferences persist independently and retain state on failure',
      (tester) async {
    final service = fixtures.FixtureCommunity();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: CommunityPreferences(service: service)))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show bio and favourites'));
    await tester.pumpAndSettle();
    expect(service.prefs['communityProfileDetails'], true);
    expect(find.text('Replies and mentions'), findsOneWidget);
    service.fail = true;
    await tester.ensureVisible(find.text('Reaction notifications'));
    await tester.tap(find.text('Reaction notifications'));
    await tester.pumpAndSettle();
    expect(service.prefs['communityReactionNotifications'], true);
    expect(find.text('Couldn’t save this preference. Please try again.'),
        findsOneWidget);
  });
  testWidgets(
      'spoilers are hidden and failed comment retries preserve draft and id',
      (tester) async {
    final service = DiscussionFixture();
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: FriendActivityScreen(
            ownerId: 'friend',
            type: 'movie-review',
            postId: 'first',
            service: service)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byTooltip('Post comment'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Post comment'))
            .onPressed,
        isNull);
    expect(find.text('The ending reveals everything.'), findsNothing);
    await tester.scrollUntilVisible(
        find.text('Show comment · contains spoilers').hitTestable(), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Show comment · contains spoilers'));
    await tester.pumpAndSettle();
    expect(find.text('The ending reveals everything.'), findsOneWidget);
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'My spoiler comment');
    await tester.ensureVisible(find.text('Contains spoilers'));
    await tester.tap(find.text('Contains spoilers'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Post comment'));
    await tester.tap(find.byTooltip('Post comment'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'My spoiler comment');
    expect(find.text('Couldn’t post. Your draft is still here; try again.'),
        findsOneWidget);
    service.rejectReply = false;
    await tester.ensureVisible(find.byTooltip('Post comment'));
    await tester.tap(find.byTooltip('Post comment'));
    await tester.pumpAndSettle();
    expect(service.ids.length, 2);
    expect(service.ids[0], service.ids[1]);
    expect(service.submittedSpoilers, true);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
    expect(service.entries.last.body, 'My spoiler comment');
    expect(tester.takeException(), isNull);
  });
}
