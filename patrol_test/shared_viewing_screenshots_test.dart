import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/testing.dart';
import 'package:patrol/patrol.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import 'package:flixie_app/features/social/data/starred_people.dart';
import 'package:flixie_app/features/social/presentation/pages/watch_requests_screen.dart';
import 'package:flixie_app/models/friendship.dart';
import '../test/support/api_fixture.dart';
import 'support/store_screenshot_fixture.dart';
import 'support/watch_plan_fixture.dart';

void main() {
  const host = String.fromEnvironment('SCREENSHOT_HOST');
  patrolTest(
      'capture selecting, rating progress, complete and missed shared viewing',
      ($) async {
    // ignore: invalid_use_of_protected_member
    ($.tester.binding as LiveTestWidgetsFlutterBinding).setLabel('');
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    final auth = StoreScreenshotAuth();
    addTearDown(auth.dispose);
    StarredPeople.instance.selectAccount('store-viewer');
    StarredPeople.instance.loaded = true;
    addTearDown(() => StarredPeople.instance.selectAccount(null));
    final friends = [
      for (final name in ['Robin', 'Ellis', 'Sophie'])
        Friendship(
            id: name,
            createdAt: '',
            updatedAt: '',
            friend: FriendshipUser(
                id: 'fixture-${name.toLowerCase()}',
                username: name,
                profileBadges: const ['EARLY_ADOPTER']))
    ];
    final api = WatchPlanFixture(status: 'ACCEPTED');
    final people = [
      screenshotPerson,
      for (final friend in friends)
        {
          'id': friend.friend!.id,
          'username': friend.friend!.username,
          'profileBadges': ['EARLY_ADOPTER']
        }
    ];
    api.plan.addAll({
      'requesterId': 'store-viewer',
      'requester': screenshotPerson,
      'recipientId': 'fixture-robin',
      'recipient': people[1],
      'participants': [
        for (final person in people) {'userId': person['id'], 'user': person}
      ],
      'lightweight': true,
      'groupId': null,
      'watchedStatus': 'PARTIAL',
      'movie': screenshotMovies.firstWhere((m) => m['id'] == 348),
      'message': '',
      'watchConfirmations': <Map<String, dynamic>>[],
    });
    useApiFixture(MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path.endsWith('/watch-confirmations')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        api.writes.add(body);
        api.plan['watchConfirmations'] = [
          ...(api.plan['watchConfirmations'] as List),
          {...body, 'id': 'my-response'}
        ];
        api.plan['watchedStatus'] = 'NOT_WATCHED';
        return api.json(api.state);
      }
      return api.handle(request);
    }));
    Future<void> capture(String name) async {
      await $.pumpAndSettle();
      expect($.tester.takeException(), isNull);
      final client = HttpClient();
      try {
        final request = await client.postUrl(Uri.parse('$host/capture/$name'));
        request.headers.set('X-Flixie-Capture-Token',
            const String.fromEnvironment('SCREENSHOT_TOKEN'));
        final response =
            await request.close().timeout(const Duration(seconds: 60));
        final body = await utf8.decoder.bind(response).join();
        expect(response.statusCode, 200, reason: body);
      } finally {
        client.close(force: true);
      }
    }

    Future<void> mount(Widget page) async {
      await $.pumpWidgetAndSettle(const SizedBox.shrink());
      final router =
          GoRouter(routes: [GoRoute(path: '/', builder: (_, __) => page)]);
      addTearDown(router.dispose);
      await $.pumpWidgetAndSettle(storeScreenshotApp(auth, router));
    }

    Map<String, dynamic> response(String id, int rating) => {
          'id': '$id-log',
          'userId': id,
          'watched': true,
          'rating': rating,
          'recommended': true,
          'watchEntry': {'watchedAt': '2026-10-16T12:00:00.000Z', 'notes': null}
        };
    await mount(Scaffold(
        body: Builder(
            builder: (context) => Center(
                child: FilledButton(
                    onPressed: () => showMovieWatchLogSheet(
                        context: context,
                        builder: (_) => RewatchLogSheet(
                            movieTitle: 'Alien',
                            loadFriends: () async => friends,
                            onSubmit: (
                                {required watchedAt,
                                required rating,
                                required recommended,
                                required notes}) async {})),
                    child: const Text('Log Alien'))))));
    await $('Log Alien').tap();
    await $('Add someone').tap();
    for (final name in ['Robin', 'Ellis', 'Sophie']) {
      await $(name).tap();
    }
    await capture('01-select-three');
    await $('Done · 3 selected').tap();
    await capture('02-watch-editor');
    api.plan['watchConfirmations'] = [response('store-viewer', 8)];
    await mount(const WatchRequestsScreen());
    await $('With Robin, Ellis, Sophie').waitUntilVisible();
    await capture('03-one-rating-card');
    await mount(const WatchRequestsScreen(initialRequestId: 'patrol-plan'));
    await $('1 of 4 rated').waitUntilVisible();
    await $('Shared viewing · 4 people').waitUntilVisible();
    await capture('04-one-rating-detail');
    await $.tester.ensureVisible(find.text('Sophie').last);
    await capture('05-one-rating-people');
    api.plan['watchConfirmations'] = [
      response('store-viewer', 8),
      response('fixture-robin', 9),
      response('fixture-ellis', 7),
      response('fixture-sophie', 6)
    ];
    api.plan['watchedStatus'] = 'WATCHED';
    await mount(const WatchRequestsScreen(initialRequestId: 'patrol-plan'));
    await $('Everyone has rated').waitUntilVisible();
    await capture('06-everyone-rated');
    await $.tester.ensureVisible(find.text('Sophie').last);
    await capture('07-everyone-rated-people');
    api.plan['watchConfirmations'] = [
      response('fixture-robin', 9),
      response('fixture-ellis', 7),
      response('fixture-sophie', 8)
    ];
    api.plan['watchedStatus'] = 'PARTIAL';
    await mount(const WatchRequestsScreen(initialRequestId: 'patrol-plan'));
    await $('I wasn’t there').waitUntilVisible();
    await capture('08-wasnt-there-choice');
    await $('I wasn’t there').tap();
    await $('Everyone who watched has rated').waitUntilVisible();
    expect(api.writes.single['watched'], false);
    expect(api.diary, isEmpty);
    await capture('09-missed-complete');
    await $.tester.ensureVisible(find.text('Sophie').last);
    await capture('10-missed-people');
    expect(api.unexpected, isEmpty);
  }, skip: host.isEmpty, timeout: const Timeout(Duration(minutes: 10)));
}
