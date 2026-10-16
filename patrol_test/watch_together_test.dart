import 'package:flixie_app/features/movies/presentation/widgets/watch_companion_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/auth/pending_watch_invite_store.dart';
import 'package:flixie_app/features/movies/presentation/pages/external_watch_invite_screen.dart';
import 'package:flixie_app/features/movies/presentation/pages/watch_invite_saved_screen.dart';
import 'package:flixie_app/features/social/presentation/pages/watch_requests_screen.dart';
import 'package:flixie_app/models/user.dart';
import 'support/watch_plan_fixture.dart';
import 'package:flixie_app/features/movies/presentation/widgets/external_watch_invite_sheet.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patrol/patrol.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uuid/uuid.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import 'package:flixie_app/features/movies/models/watch_log_details.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/features/social/data/starred_people.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/models/friendship.dart';
import '../test/support/api_fixture.dart';
import 'support/store_screenshot_fixture.dart';

class JoinedWatchAuth extends StoreScreenshotAuth {
  @override
  User get dbUser => super.dbUser.copyWith(completedSetup: false);
}

void main() {
  patrolTest(
      'favourite-first companions can be logged together without a plan or rating',
      ($) async {
    final writes = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path == '/watch-requests/log-watch') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        writes.add(body);
        return http.Response(
            jsonEncode({
              'id': 'fixture-watch',
              'userId': 'store-viewer',
              'movieId': 348,
              'watchedAt': body['watchedAt'],
              'rating': body['rating'],
              'removed': false
            }),
            200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response(jsonEncode([]), 200,
          headers: {'content-type': 'application/json'});
    });
    useApiFixture(client);
    StarredPeople.instance.selectAccount('store-viewer');
    StarredPeople.instance.ids = {'sophie'};
    StarredPeople.instance.loaded = true;
    final auth = StoreScreenshotAuth();
    var saved = false;
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
              body: Center(
                  child: FilledButton(
                      onPressed: () async {
                        var details = const WatchLogDetails();
                        final draft = const Uuid().v4();
                        await showMovieWatchLogSheet(
                            context: context,
                            builder: (_) => RewatchLogSheet(
                                movieTitle: 'Alien',
                                loadFriends: () async => [
                                      for (final name in ['Casey', 'Sophie'])
                                        Friendship(
                                            id: name,
                                            createdAt: '',
                                            updatedAt: '',
                                            friend: FriendshipUser(
                                                id: name.toLowerCase(),
                                                username: name,
                                                profileBadges: const [
                                                  'EARLY_ADOPTER'
                                                ]))
                                    ],
                                onDetailsChanged: (value) => details = value,
                                onSubmit: (
                                    {required watchedAt,
                                    required rating,
                                    required recommended,
                                    required notes}) async {
                                  await UserService.logMovieWatch(
                                      'store-viewer',
                                      LogMovieWatchRequest(
                                          movieId: 348,
                                          draftId: draft,
                                          companionId: details.companion?.id,
                                          companionIds: details.companions
                                              .map((friend) => friend.id)
                                              .toList(),
                                          watchedAt: watchedAt,
                                          rating: rating,
                                          recommended: recommended,
                                          notes: notes));
                                  saved = true;
                                }));
                      },
                      child: const Text('Log Alien')))))
    ]);
    addTearDown(auth.dispose);
    addTearDown(router.dispose);
    addTearDown(() => StarredPeople.instance.selectAccount(null));
    await $.pumpWidgetAndSettle(storeScreenshotApp(auth, router));
    await $('Log Alien').tap();
    await $('Add someone').tap();
    await $('Sophie').waitUntilVisible();
    final sophie = $.tester.getTopLeft(find.text('Sophie')),
        casey = $.tester.getTopLeft(find.text('Casey'));
    expect(sophie.dy, lessThan(casey.dy));
    await $('Sophie').tap();
    await $('Casey').tap();
    await $('Done · 2 selected').tap();
    await $('Save watch').tap();
    await $('Log Alien').waitUntilVisible();
    expect(saved, isTrue);
    expect(writes, hasLength(1));
    expect(writes.single['companionId'], 'sophie');
    expect(writes.single['companionIds'], ['sophie', 'casey']);
    expect(writes.single['rating'], isNull);
    expect(writes.single['draftId'], isNotEmpty);
  });
  patrolTest('external companion gets a watch-specific invite after saving',
      ($) async {
    final writes = <Map<String, dynamic>>[];
    final calls = <String>[];
    useApiFixture(MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      if (request.method == 'POST') {
        writes.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
            jsonEncode({
              'id': 'watch',
              'userId': 'store-viewer',
              'movieId': 348,
              'removed': false,
              'externalInvite': {
                'id': 'external-invite',
                'displayName': 'Sophie',
                'expiresAt': DateTime.now()
                    .add(const Duration(days: 30))
                    .toIso8601String()
              }
            }),
            200);
      }
      return http.Response(
          jsonEncode(
              {'url': 'https://www.flixie.co.uk/invite?watch=${'a' * 43}'}),
          200);
    }));
    StarredPeople.instance.loaded = true;
    final auth = StoreScreenshotAuth();
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
              body: Center(
                  child: FilledButton(
                      onPressed: () async {
                        var details = const WatchLogDetails();
                        MovieWatchEntry? saved;
                        await showMovieWatchLogSheet(
                            context: context,
                            builder: (_) => RewatchLogSheet(
                                movieTitle: 'Alien',
                                loadFriends: () async => [],
                                onDetailsChanged: (value) => details = value,
                                onSubmit: (
                                    {required watchedAt,
                                    required rating,
                                    required recommended,
                                    required notes}) async {
                                  saved = await UserService.logMovieWatch(
                                      'store-viewer',
                                      LogMovieWatchRequest(
                                          movieId: 348,
                                          draftId: const Uuid().v4(),
                                          externalCompanionName:
                                              details.externalCompanionName,
                                          watchedAt: watchedAt,
                                          rating: rating,
                                          recommended: recommended,
                                          notes: notes));
                                }));
                        if (context.mounted && saved?.externalInvite != null) {
                          await showExternalWatchInviteSheet(
                              context, saved!.externalInvite!, 'Alien');
                        }
                      },
                      child: const Text('Log Alien')))))
    ]);
    addTearDown(auth.dispose);
    addTearDown(router.dispose);
    await $.pumpWidgetAndSettle(storeScreenshotApp(auth, router));
    await $('Log Alien').tap();
    await $('Add someone').tap();
    await $('Someone who isn’t on Flixie').tap();
    await $(find.descendant(
            of: find.byType(WatchCompanionPicker),
            matching: find.byType(TextField)))
        .enterText('Sophie');
    await $.tester.testTextInput.receiveAction(TextInputAction.done);
    await $.tester
        .ensureVisible(find.widgetWithText(FilledButton, 'Add to my watch'));
    await $.pumpAndSettle();
    await $('Add to my watch').tap();
    await $('Save watch').tap();
    await $('Invite Sophie').waitUntilVisible();
    expect(writes, hasLength(1));
    expect(writes.single['externalCompanionName'], 'Sophie');
    expect(writes.single['companionId'], isNull);
    await $('Copy invite').tap();
    await $('Invite copied').waitUntilVisible();
    expect(calls,
        contains('GET /watch-requests/external-invites/external-invite/share'));
  });
  patrolTest(
      'joined member resumes Interstellar invite, rates and saves before optional setup',
      ($) async {
    // Isolated authentication boundary: no live accounts or signup requests.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final token = 'c' * 43;
    await PendingWatchInviteStore.readyToLog(token);
    final api = WatchPlanFixture(status: 'ACCEPTED');
    api.plan.addAll({
      'lightweight': true,
      'movieId': 157336,
      'movie': {'id': 157336, 'title': 'Interstellar'},
      'requester': {
        'id': 'fixture-robin',
        'username': 'Dougasaur',
        'profileBadges': []
      },
      'selectedCandidateId': 'interstellar',
      'candidates': [
        {
          'id': 'interstellar',
          'movieId': 157336,
          'movie': {'id': 157336, 'title': 'Interstellar'},
          'addedByUserId': 'fixture-robin',
          'choices': []
        }
      ],
      'watchConfirmations': [
        {
          'id': 'owner',
          'userId': 'fixture-robin',
          'watched': true,
          'rating': null,
          'watchEntryId': 'owner-viewing',
          'watchEntry': {'watchedAt': null}
        }
      ]
    });
    useApiFixture(MockClient((request) async {
      final path = request.url.path;
      if (path == '/watch-requests/external-invites/$token') {
        return api.json({
          'movie': {'id': 157336, 'title': 'Interstellar'},
          'owner': {
            'id': 'fixture-robin',
            'username': 'Dougasaur',
            'profileBadges': []
          }
        });
      }
      if (path == '/watch-requests/external-invites/$token/claim') {
        return api.json({'requestId': 'patrol-plan'});
      }
      if (path == '/movies/157336/GB/watch/providers') return api.json([]);
      if (path == '/movies/157336/user/rating') {
        return api.json({'rating': 8, 'recommended': null});
      }
      return api.handle(request);
    }));
    final auth = JoinedWatchAuth();
    final router = GoRouter(initialLocation: '/invite', routes: [
      GoRoute(
          path: '/invite',
          builder: (_, __) => ExternalWatchInviteScreen(token: token)),
      GoRoute(
          path: '/watch-requests/:id',
          builder: (_, state) => WatchRequestsScreen(
              initialRequestId: state.pathParameters['id'], logOnOpen: true)),
      GoRoute(
          path: '/watch-entry-saved/:id',
          builder: (_, state) {
            final data = state.extra as Map;
            return WatchInviteSavedScreen(
                requestId: state.pathParameters['id']!,
                movieTitle: data['movieTitle'] as String?,
                rating: data['rating'] as int?);
          }),
      GoRoute(
          path: '/onboarding',
          builder: (_, __) => const Scaffold(body: Text('Optional setup'))),
    ]);
    addTearDown(auth.dispose);
    addTearDown(router.dispose);
    addTearDown(() => expect(api.unexpected, isEmpty));
    await $.pumpWidgetAndSettle(storeScreenshotApp(auth, router));
    await $('Log your watch').waitUntilVisible();
    final score = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Rate 8 out of 10');
    await $.tester.ensureVisible(score);
    await $(score).tap();
    await $('Save watch').tap();
    await $('That one’s in your diary.').waitUntilVisible();
    await $('8 / 10').waitUntilVisible();
    expect(api.diary, hasLength(1));
    expect(api.diary.values.single['rating'], 8);
    expect(auth.dbUser.completedSetup, isFalse);
    await $('View my watch').tap();
    await $('Your recap').waitUntilVisible();
    await $(find.byTooltip('Home')).tap();
    await $('Optional setup').waitUntilVisible();
    expect(await PendingWatchInviteStore.readLog('store-viewer'), isNull);
  });
}
