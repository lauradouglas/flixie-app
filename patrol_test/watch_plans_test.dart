import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/features/social/presentation/pages/watch_requests_screen.dart';
import '../test/support/api_fixture.dart';
import 'package:flixie_app/features/movies/presentation/widgets/watch_request_sheet.dart';
import 'package:flixie_app/features/watch_plans/presentation/pages/group_watch_plan_v2_screen.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/features/authentication/presentation/pages/auth_ui.dart';
import 'package:flixie_app/core/widgets/movie_search_result_tile.dart';
import 'package:flixie_app/models/watch_request.dart';
import 'package:flixie_app/core/auth/watch_plan_reminder_policy.dart';
import 'package:flixie_app/core/calendar/watch_calendar_service.dart';
import 'support/store_screenshot_fixture.dart';
import 'support/watch_plan_fixture.dart';

Future<void> openPlan(PatrolIntegrationTester $, WatchPlanFixture api) async {
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  useApiFixture(api.client);
  final auth = StoreScreenshotAuth();
  final router = GoRouter(routes: [
    GoRoute(
        path: '/',
        builder: (_, __) =>
            const WatchRequestsScreen(initialRequestId: 'patrol-plan'))
  ]);
  addTearDown(auth.dispose);
  addTearDown(router.dispose);
  addTearDown(() => expect(api.unexpected, isEmpty));
  await $.pumpWidgetAndSettle(storeScreenshotApp(auth, router));
  await $('Alien').waitUntilVisible();
}

Future<void> tapVisible(PatrolIntegrationTester $, String text) async {
  final buttons = find.ancestor(
      of: find.text(text),
      matching:
          find.byWidgetPredicate((widget) => widget is ButtonStyleButton));
  // Status rows can repeat action text (e.g. Works for me). Target the actual
  // control rather than accidentally tapping a participant's static label.
  final target =
      buttons.evaluate().isNotEmpty ? buttons.first : find.text(text).first;
  await $.tester.ensureVisible(target);
  await $(target).tap();
  await $.pumpAndSettle();
}

void verifyScheduleEffects(WatchPlanFixture api, {required bool dateOnly}) {
  final loaded = WatchRequest.fromJson(api.plan);
  final scheduled = loaded.scheduledFor!;
  expect(loaded.scheduledDateOnly, dateOnly);
  final reminders = watchPlanReminderTimes(scheduled,
      now: DateTime.now(), dateOnly: loaded.scheduledDateOnly);
  expect(reminders.morning!.hour, 9);
  final event = WatchCalendarService.eventForScheduledWatch(
      title: loaded.watchPlanTitle,
      scheduledFor: scheduled,
      dateOnly: loaded.scheduledDateOnly,
      runtimeMinutes: 117);
  expect(event.allDay, dateOnly);
  if (dateOnly) {
    expect(reminders.beforeWatch, isNull);
    expect(reminders.followUp, isNull);
    expect(event.startDate.hour, 0);
    expect(event.endDate.difference(event.startDate), const Duration(days: 1));
  } else {
    expect(event.startDate, scheduled.toLocal());
    expect(reminders.beforeWatch,
        scheduled.toLocal().subtract(const Duration(hours: 1)));
    expect(
        reminders.followUp, scheduled.toLocal().add(const Duration(hours: 2)));
  }
}

void main() {
  for (final timed in [false, true]) {
    patrolTest(
        'creation sends a ${timed ? 'timed' : 'date-only'} invitation and closes only after save',
        ($) async {
      final api = WatchPlanFixture()..failNextPath = '/requests';
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({});
      useApiFixture(api.client);
      final auth = StoreScreenshotAuth();
      var created = 0;
      var errors = 0;
      final router = GoRouter(routes: [
        GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
                    body: Center(
                        child: FilledButton(
                  child: const Text('Create plan'),
                  onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      useRootNavigator: true,
                      useSafeArea: true,
                      isScrollControlled: true,
                      builder: (_) => MovieWatchRequestSheet(
                          movieId: 348,
                          movieTitle: 'Alien',
                          requesterId: 'store-viewer',
                          initialFriendId: 'fixture-robin',
                          initialCinema: true,
                          friends: const [
                            Friendship(
                                id: 'fictional-friendship',
                                createdAt: '',
                                updatedAt: '',
                                friend: FriendshipUser(
                                    id: 'fixture-robin', username: 'Robin'))
                          ],
                          onSuccess: () => created++,
                          onError: () => errors++)),
                ))))
      ]);
      addTearDown(auth.dispose);
      addTearDown(router.dispose);
      addTearDown(() => expect(api.unexpected, isEmpty));
      await $.pumpWidgetAndSettle(storeScreenshotApp(auth, router));
      await $('Create plan').tap();
      await tapVisible($, 'Choose when to watch');
      if (timed) await tapVisible($, 'Date & time');
      await tapVisible($, 'Tomorrow');
      await tapVisible($, 'Save schedule');
      await tapVisible($, 'Send watch plan');
      expect(created, 0);
      expect(errors, 1);
      expect(api.writes, isEmpty);
      expect(find.byType(MovieWatchRequestSheet), findsOneWidget);
      await tapVisible($, 'Send watch plan');
      await $('Create plan').waitUntilVisible();
      expect(created, 1);
      expect(api.writes.single['proposedDateOnly'], !timed);
      expect(api.writes.single['recipientId'], 'fixture-robin');
      expect(api.writes.single['candidateMovieIds'], [348]);
      final saved = DateTime.parse(api.writes.single['proposedDate'] as String);
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(
          saved,
          timed
              ? DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 19, 30)
                  .toUtc()
              : DateTime.utc(tomorrow.year, tomorrow.month, tomorrow.day, 12));
    });
  }

  patrolTest('group invitation retry saves only this member’s response',
      ($) async {
    final api = WatchPlanFixture()
      ..failNextPath = '/groups/request/patrol-plan/response';
    api.plan.addAll({
      'groupId': 'fixture-group',
      'userId': 'fixture-robin',
      'hasCurrentUserAccepted': false,
      'memberStatuses': [
        {'memberId': 'store-viewer', 'status': 'PENDING'}
      ]
    });
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    useApiFixture(api.client);
    final auth = StoreScreenshotAuth();
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => const GroupWatchPlanV2Screen(
              groupId: 'fixture-group',
              groupName: 'Date Club',
              initialRequestId: 'patrol-plan'))
    ]);
    addTearDown(auth.dispose);
    addTearDown(router.dispose);
    addTearDown(() => expect(api.unexpected, isEmpty));
    await $.pumpWidgetAndSettle(storeScreenshotApp(auth, router));
    await $('Will you join?').waitUntilVisible();
    await tapVisible($, 'I’m in');
    expect(api.writes, isEmpty);
    await tapVisible($, 'I’m in');
    expect(api.writes.single['memberId'], 'store-viewer');
    expect(api.writes.single['status'], 'ACCEPTED');
    expect(find.text('Will you join?'), findsNothing);
  });

  patrolTest(
      'invite failure keeps the invitation actionable; retry joins once and survives resume',
      ($) async {
    final api = WatchPlanFixture()..failNextPath = '/requests/update';
    await openPlan($, api);
    await tapVisible($, 'I’m in');
    expect(api.plan['status'], 'PENDING');
    expect(api.writes, isEmpty);
    await $('I’m in').waitUntilVisible();
    await tapVisible($, 'I’m in');
    expect(api.plan['status'], 'ACCEPTED');
    expect(api.writes.single['status'], 'ACCEPTED');
    await $.platform.mobile.pressHome();
    await $.platform.mobile.openApp();
    await $('Suggest a date').waitUntilVisible();
    await $.tester.pumpWidget(const SizedBox.shrink());
    await openPlan($, api);
    expect(api.calls.where((c) => c.endsWith('/state')).length, greaterThan(1));
    expect(find.text('I’m in'), findsNothing);
  });

  for (final timed in [false, true]) {
    patrolTest(
        'schedule proposal preserves ${timed ? 'an optional time' : 'date-only intent'} across resume',
        ($) async {
      final api = WatchPlanFixture(status: 'ACCEPTED');
      await openPlan($, api);
      await tapVisible($, 'Suggest a date');
      await $('Plan date').waitUntilVisible();
      if (timed) await tapVisible($, 'Date & time');
      await tapVisible($, 'Tomorrow');
      await tapVisible($, 'Save schedule');
      expect(api.writes.single['dateOnly'], !timed);
      final timestamp =
          DateTime.parse(api.writes.single['proposedFor'] as String);
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(
          timestamp,
          timed
              ? DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 19, 30)
                  .toUtc()
              : DateTime.utc(tomorrow.year, tomorrow.month, tomorrow.day, 12));
      expect(api.plan['scheduledFor'], isNull,
          reason: 'A proposal must not confirm the schedule before agreement');
      await $.platform.mobile.pressHome();
      await $.platform.mobile.openApp();
      await $('Alien').waitUntilVisible();
      expect(
          (api.plan['scheduleProposals'] as List).single['dateOnly'], !timed);
      expect(find.text('Save schedule'), findsNothing);
    });
  }

  patrolTest(
      'accepting a date-only replacement persists the date without an invented time',
      ($) async {
    final api = WatchPlanFixture(status: 'ACCEPTED', scheduled: true)
      ..proposeByRobin();
    await openPlan($, api);
    await tapVisible($, 'Works for me');
    await $('Time agreed').waitUntilVisible();
    await tapVisible($, 'Not now');
    expect(api.plan['scheduledFor'], '2099-10-09T12:00:00.000Z');
    expect(api.plan['scheduledDateOnly'], true);
    expect(api.writes.single['decision'], 'accepted');
    verifyScheduleEffects(api, dateOnly: true);
    expect(find.textContaining('Time optional'), findsWidgets);
    expect(find.textContaining('13:00'), findsNothing);
  });

  patrolTest(
      'timed reschedule keeps the current time until the other person agrees',
      ($) async {
    final api = WatchPlanFixture(status: 'ACCEPTED', scheduled: true);
    api.plan['scheduledDateOnly'] = false;
    api.plan['scheduledFor'] = '2099-10-08T18:15:00.000Z';
    await openPlan($, api);
    final original = api.plan['scheduledFor'];
    await tapVisible($, 'Reschedule');
    await tapVisible($, 'Tomorrow');
    await tapVisible($, 'Save schedule');
    expect(api.plan['scheduledFor'], original);
    expect(api.plan['scheduledDateOnly'], false);
    final proposal = (api.plan['scheduleProposals'] as List).single;
    final requested =
        DateTime.parse(proposal['proposedFor'] as String).toLocal();
    expect(requested.hour, 19);
    expect(requested.minute, 30);
    expect(proposal['dateOnly'], false);
    // Robin proposes the replacement back. Agreement still requires a response
    // through the production screen, and must survive a fresh detail load.
    proposal['proposerId'] = 'fixture-robin';
    await $.tester.pumpWidget(const SizedBox.shrink());
    await openPlan($, api);
    expect(api.plan['scheduledFor'], original);
    await tapVisible($, 'Works for me');
    await $('Time agreed').waitUntilVisible();
    await tapVisible($, 'Not now');
    expect(DateTime.parse(api.plan['scheduledFor'] as String).toLocal(),
        requested);
    expect(api.plan['scheduledDateOnly'], false);
    await $.tester.pumpWidget(const SizedBox.shrink());
    await openPlan($, api);
    expect(find.textContaining('7:30pm'), findsWidgets);
    expect(find.text('Reschedule'), findsOneWidget);
    verifyScheduleEffects(api, dateOnly: false);
  });

  patrolTest(
      'multiple movies preserve member picks and the creator chooses one final film',
      ($) async {
    final api = WatchPlanFixture(status: 'ACCEPTED');
    api.plan.addAll({
      'groupId': 'fixture-group',
      'requesterId': 'store-viewer',
      'userId': 'store-viewer',
      'selectedCandidateId': null,
      'movieId': null,
      'movie': null,
      'memberStatuses': [
        {'memberId': 'store-viewer', 'status': 'ACCEPTED'},
        {'memberId': 'fixture-robin', 'status': 'ACCEPTED'}
      ],
      'candidates': [
        for (final (id, movieId, title) in [
          ('alien', 348, 'Alien'),
          ('odyssey', 1368337, 'The Odyssey')
        ])
          {
            'id': id,
            'movieId': movieId,
            'movie': {'id': movieId, 'title': title},
            'addedByUserId': 'store-viewer',
            'choices': [
              {'userId': 'fixture-robin'}
            ]
          },
      ]
    });
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    useApiFixture(api.client);
    final auth = StoreScreenshotAuth();
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => const GroupWatchPlanV2Screen(
              groupId: 'fixture-group',
              groupName: 'Date Club',
              initialRequestId: 'patrol-plan'))
    ]);
    addTearDown(auth.dispose);
    addTearDown(router.dispose);
    addTearDown(() => expect(api.unexpected, isEmpty));
    await $.pumpWidgetAndSettle(storeScreenshotApp(auth, router));
    await $('What could you watch?').waitUntilVisible();
    await tapVisible($, 'Alien');
    await tapVisible($, 'The Odyssey');
    await tapVisible($, 'Save my picks');
    expect(api.writes.single['candidateIds'],
        unorderedEquals(['alien', 'odyssey']));
    await $.tester.ensureVisible(find.text('Choose the final movie'));
    await $('Choose the final movie').waitUntilVisible();
    expect(find.text('Alien'), findsWidgets);
    expect(find.text('The Odyssey'), findsWidgets);
    await tapVisible($, 'Choose');
    expect(api.writes.last['candidateId'], 'alien');
    expect(api.plan['movieId'], 348);
    expect(api.plan['selectedCandidateId'], 'alien');
    expect((api.plan['candidates'] as List).length, 2);
    expect(find.text('Choose the final movie'), findsNothing);
    await $.tester.ensureVisible(find.text('Propose a date'));
    await $('Propose a date').waitUntilVisible();
  });

  patrolTest(
      'the invited user adds another film to a multiple-movie plan and saves their picks',
      ($) async {
    final api = WatchPlanFixture(status: 'ACCEPTED');
    api.plan.addAll({
      'selectedCandidateId': null,
      'movieId': null,
      'movie': null,
      'candidates': [
        for (final (id, movieId, title) in [
          ('alien', 348, 'Alien'),
          ('odyssey', 1368337, 'The Odyssey')
        ])
          {
            'id': id,
            'movieId': movieId,
            'movie': {'id': movieId, 'title': title},
            'addedByUserId': 'fixture-robin',
            'choices': [
              {'userId': 'fixture-robin'}
            ]
          },
      ]
    });
    await openPlan($, api);
    expect(api.plan['requesterId'], isNot('store-viewer'));
    await tapVisible($, 'Add another option');
    final search = find.descendant(
        of: find.byType(MovieSearchSheet), matching: find.byType(TextField));
    await $(search).enterText('Obsession');
    // Finish typing before selecting a result, as a user does with Done.
    await $.tester.testTextInput.receiveAction(TextInputAction.done);
    await $.pumpAndSettle();
    final result = find.descendant(
        of: find.byType(MovieSearchResultTile),
        matching: find.text('Obsession'));
    // The query field also contains Obsession; tap the actual result tile.
    await $(result).waitUntilVisible();
    expect(api.searches.last['type'], 'movie');
    expect(api.searches.last['value'], 'Obsession');
    expect(
        find.descendant(
            of: find.byType(MovieSearchSheet), matching: find.text('Alien')),
        findsNothing,
        reason: 'Existing titles cannot be added twice');
    await $.tester.ensureVisible(result);
    await $(result).tap();
    await $.pumpAndSettle();
    expect(find.byType(MovieSearchSheet), findsNothing);
    expect(api.writes.single, {'userId': 'store-viewer', 'movieId': 1339713});
    final options = api.plan['candidates'] as List;
    expect(options.map((c) => c['movieId']), [348, 1368337, 1339713]);
    expect(options.last['addedByUserId'], 'store-viewer');
    expect(api.plan['selectedCandidateId'], isNull);
    await tapVisible($, 'Alien');
    await tapVisible($, 'Save my picks');
    expect(api.writes.last['candidateIds'],
        unorderedEquals(['alien', 'obsession']));
    expect((options.first['choices'] as List).map((choice) => choice['userId']),
        contains('fixture-robin'));
    await $.tester.pumpWidget(const SizedBox.shrink());
    await openPlan($, api);
    await $.tester.ensureVisible(find.text('Obsession'));
    await $('Obsession').waitUntilVisible();
    expect((api.plan['candidates'] as List).length, 3);
    expect(
        api.calls
            .where(
                (call) => call == 'POST /watch-requests/patrol-plan/candidates')
            .length,
        1);
  });

  patrolTest(
      'rating and review remain saved when the secondary rating sync fails',
      ($) async {
    final api = WatchPlanFixture(status: 'ACCEPTED', scheduled: true)
      ..failRatingSync = true;
    await openPlan($, api);
    await tapVisible($, 'Log watch');
    final rating = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Rate 8 out of 10');
    await $.tester.ensureVisible(rating);
    await $(rating).tap();
    final note = find.byType(TextField).last;
    await $.tester.ensureVisible(note);
    await $(note).enterText('Alien is perfect for movie night.');
    await $.tester.testTextInput.receiveAction(TextInputAction.done);
    await tapVisible($, 'Rate & mark watched');
    await $('Your recap').waitUntilVisible();
    expect(api.diary.length, 1);
    expect(api.diary.values.single['rating'], 8);
    expect(api.diary.values.single['reviewText'],
        'Alien is perfect for movie night.');
    expect(
        api.calls
            .where((c) =>
                c == 'POST /watch-requests/patrol-plan/watch-confirmations')
            .length,
        1);
    await $.platform.mobile.pressHome();
    await $.platform.mobile.openApp();
    await $('Your recap').waitUntilVisible();
    expect(api.diary.length, 1);
    expect(find.text('Rate & mark watched'), findsNothing);
  });
}
