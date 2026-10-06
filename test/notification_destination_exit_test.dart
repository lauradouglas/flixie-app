import 'dart:async';
import 'package:flixie_app/features/social/data/community_space_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/features/profile/presentation/pages/notification_screen.dart';
import 'package:flixie_app/features/profile/presentation/pages/friend_profile_screen.dart';
import 'package:flixie_app/features/social/presentation/pages/group_detail_screen.dart';
import 'package:flixie_app/features/social/presentation/pages/direct_chat_screen.dart';
import 'package:flixie_app/features/social/presentation/pages/community_discussion_screen.dart';
import 'package:flixie_app/features/social/presentation/pages/community_space_screen.dart';
import 'package:flixie_app/features/social/presentation/pages/community_post_screen.dart';
import 'package:flixie_app/features/social/presentation/pages/community_people_screen.dart';
import 'package:flixie_app/features/social/presentation/pages/group_invitation_detail_screen.dart';
import 'package:flixie_app/features/social/presentation/pages/friend_activity_screen.dart';
import 'package:flixie_app/features/social/presentation/pages/watch_requests_screen.dart';
import 'package:flixie_app/features/movies/presentation/pages/movie_detail_screen.dart';
import 'package:flixie_app/features/movies/presentation/pages/show_detail_screen.dart';
import 'package:flixie_app/features/movies/presentation/pages/person_detail_screen.dart';
import 'package:flixie_app/features/movies/presentation/pages/movie_list_detail_screen.dart';
import '../patrol_test/support/store_screenshot_fixture.dart';
import 'support/api_fixture.dart';

const destinationScreens = <String, Widget>{
  'notifications': NotificationScreen(),
  'friend profile': FriendProfileScreen(userId: 'fixture-robin'),
  'group': GroupDetailScreen(groupId: 'fixture-group'),
  'chat': DirectChatScreen(otherUserId: 'fixture-robin'),
  'discussion': CommunityDiscussionScreen(
      communityId: 18,
      discussionId: 'fixture-discussion',
      service: CommunitySpaceService()),
  'community': CommunitySpaceScreen(communityId: 18),
  'community post': CommunityPostScreen(
      ownerId: 'fixture-robin', type: 'movie-review', postId: 'fixture-post'),
  'community people': CommunityPeopleScreen(),
  'group invitation': GroupInvitationDetailScreen(
      groupId: 'fixture-group', requestId: 'fixture-invite'),
  'friend activity': FriendActivityScreen(
      ownerId: 'fixture-robin', type: 'movie-review', postId: 'fixture-post'),
  'watch plan': WatchRequestDetailScreen(requestId: 'fixture-plan'),
  'movie': MovieDetailScreen(movieId: '101'),
  'show': ShowDetailScreen(showId: '202'),
  'person': PersonDetailScreen(personId: '303'),
  'shared list':
      MovieListDetailScreen(listId: 'fixture-list', listName: 'Movie night'),
};

void main() {
  for (final entry in destinationScreens.entries) {
    for (final pushed in [false, true]) {
      testWidgets(
          '${entry.key} actual screen ${pushed ? 'Back restores draft' : 'offers Home'} during loading and failure',
          (tester) async {
        SharedPreferences.setMockInitialValues({});
        final gate = Completer<http.Response>();
        useApiFixture(MockClient((_) => gate.future));
        final auth = StoreScreenshotAuth();
        final draft = TextEditingController();
        final router = GoRouter(
            initialLocation: pushed ? '/origin' : '/destination',
            routes: [
              GoRoute(
                  path: '/',
                  builder: (_, __) =>
                      const Scaffold(body: Text('Home destination'))),
              GoRoute(
                  path: '/origin',
                  builder: (_, __) =>
                      Scaffold(body: TextField(controller: draft))),
              GoRoute(path: '/destination', builder: (_, __) => entry.value),
            ]);
        addTearDown(auth.dispose);
        addTearDown(draft.dispose);
        addTearDown(router.dispose);
        await tester.pumpWidget(storeScreenshotApp(auth, router));
        if (pushed) {
          await tester.enterText(find.byType(TextField), 'Original draft');
          router.push('/destination');
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byTooltip(pushed ? 'Back' : 'Home'), findsOneWidget);
        // Resolve every request with a fictional failure; the exit stays usable.
        gate.complete(http.Response('{"message":"Fixture unavailable"}', 400,
            headers: {'content-type': 'application/json'}));
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byTooltip(pushed ? 'Back' : 'Home'), findsOneWidget);
        await tester.tap(find.byTooltip(pushed ? 'Back' : 'Home'));
        await tester.pumpAndSettle();
        if (pushed) {
          expect(find.byType(TextField), findsOneWidget);
          expect(draft.text, 'Original draft');
        } else {
          expect(find.text('Home destination'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
