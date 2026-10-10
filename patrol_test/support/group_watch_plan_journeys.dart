import 'package:flixie_app/core/navigation/tab_refresh_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patrol_finders/patrol_finders.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/core/auth/watch_plan_reminder_policy.dart';
import 'package:flixie_app/core/widgets/movie_search_result_tile.dart';
import 'package:flixie_app/features/authentication/presentation/pages/auth_ui.dart';
import 'package:flixie_app/features/watch_plans/presentation/pages/group_watch_plan_v2_screen.dart';
import '../../test/support/api_fixture.dart';
import 'store_screenshot_fixture.dart';
import 'group_watch_plan_fixture.dart';

typedef GroupJourney = Future<void> Function(PatrolTester tester);
Future<void> openGroup(PatrolTester $, GroupWatchPlanFixture api,
    {StoreScreenshotAuth? viewer}) async {
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  useApiFixture(api.client);
  final auth = viewer ?? StoreScreenshotAuth();
  final router = GoRouter(routes: [
    GoRoute(
        path: '/',
        builder: (_, __) => const GroupWatchPlanV2Screen(
            groupId: 'fixture-group',
            groupName: 'Four Film Friends',
            initialRequestId: 'patrol-plan'))
  ]);
  addTearDown(auth.dispose);
  addTearDown(router.dispose);
  addTearDown(() => expect(api.unexpected, isEmpty));
  await $.pumpWidgetAndSettle(storeScreenshotApp(auth, router));
}

class _SwitchableGroupAuth extends StoreScreenshotAuth {
  String viewerId = GroupWatchPlanFixture.viewer;
  @override
  User get dbUser => super.dbUser.copyWith(id: viewerId);
  void switchMember() {
    viewerId = GroupWatchPlanFixture.ellis;
    notifyListeners();
  }
}

Future<void> tapGroup(PatrolTester $, String text) async {
  final buttons = find.ancestor(
      of: find.text(text),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
  final target =
      buttons.evaluate().isNotEmpty ? buttons.first : find.text(text).first;
  await $.tester.ensureVisible(target);
  await $(target).tap();
  await $.pumpAndSettle();
}

void groupWatchPlanJourneys(void Function(String, GroupJourney) register) {
  register(
      'four members: account change closes a schedule sheet without a write',
      ($) async {
    final api = GroupWatchPlanFixture()..schedule();
    final auth = _SwitchableGroupAuth();
    await openGroup($, api, viewer: auth);
    await tapGroup($, 'Update date or time');
    expect(find.byType(BottomSheet), findsOneWidget);
    auth.switchMember();
    await $.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(api.writes, isEmpty);
  });
  register(
      'four members: simultaneous refresh signals fetch the collection once',
      ($) async {
    final api = GroupWatchPlanFixture();
    await openGroup($, api);
    api.calls.clear();
    TabRefreshController.social.value++;
    TabRefreshController.watchPlans.value++;
    await $.pumpAndSettle();
    expect(
        api.calls
            .where((call) => call == 'GET /groups/fixture-group/requests')
            .length,
        1);
    expect(
        api.calls
            .where((call) => call == 'GET /groups/fixture-group/members')
            .length,
        1);
    expect(find.text('Alien'), findsWidgets);
  });

  register(
      'four members: incoming update refreshes the open plan to the latest date',
      ($) async {
    final api = GroupWatchPlanFixture()..proposal();
    await openGroup($, api);
    expect(find.text('Does this time work?'), findsOneWidget);
    api.proposals.clear();
    api.proposal(dateOnly: true);
    TabRefreshController.watchPlans.value++;
    await $.pumpAndSettle();
    expect(find.text('Does this date work?'), findsOneWidget);
    expect(find.text('Does this time work?'), findsNothing);
    await tapGroup($, 'Works for me');
    expect(api.plan['scheduledDateOnly'], true);
  });
  register(
      'four members: declining an invite survives refresh and removes joining, voting and time actions',
      ($) async {
    final api = GroupWatchPlanFixture(invited: true);
    await openGroup($, api);
    await tapGroup($, 'Can’t make it');
    expect(
        api.statuses
            .where((s) => s['status'] == 'DECLINED')
            .map((s) => s['memberId']),
        [GroupWatchPlanFixture.viewer]);
    expect(find.text('You left this screening'), findsOneWidget);
    expect(find.text('I’m in'), findsNothing);
    expect(find.text('Save my picks'), findsNothing);
    expect(find.text('Works for me'), findsNothing);
    await $.tester.tap(find.byTooltip('Refresh'));
    await $.pumpAndSettle();
    expect(find.text('You left this screening'), findsOneWidget);
    expect(api.writes.length, 1);
  });
  register(
      'four members: a failed decline keeps the invitation actionable until retry succeeds',
      ($) async {
    final api = GroupWatchPlanFixture(invited: true)
      ..failNextPath = '/groups/request/patrol-plan/response';
    await openGroup($, api);
    await tapGroup($, 'Can’t make it');
    expect(api.writes, isEmpty);
    expect(find.text('Will you join?'), findsOneWidget);
    await tapGroup($, 'Can’t make it');
    expect(api.writes.length, 1);
    expect(find.text('You left this screening'), findsOneWidget);
  });
  register(
      'four members: leaving a scheduled screening hides calendar, reschedule and logging controls',
      ($) async {
    final api = GroupWatchPlanFixture()..schedule();
    await openGroup($, api);
    expect(find.text('Confirmed attendees (4)'), findsOneWidget);
    await tapGroup($, 'Leave this screening');
    expect(find.text('You left this screening'), findsOneWidget);
    expect(find.text('Add to calendar'), findsNothing);
    expect(find.text('Update date or time'), findsNothing);
    expect(find.text('Already watched? Log your watch'), findsNothing);
    expect(api.plan['status'], 'SCHEDULED');
    expect(api.statuses.where((s) => s['status'] == 'ACCEPTED').length, 3);
  });
  register(
      'four members: a declined member can explicitly rejoin without changing the other responses',
      ($) async {
    final api = GroupWatchPlanFixture(multiple: true)
      ..decline(GroupWatchPlanFixture.viewer);
    await openGroup($, api);
    await tapGroup($, 'Rejoin plan');
    expect(find.text('What could you watch?'), findsOneWidget);
    expect(api.statuses.every((s) => s['status'] == 'ACCEPTED'), isTrue);
    expect(api.writes.single['memberId'], GroupWatchPlanFixture.viewer);
  });
  register(
      'four members: another member adds Obsession, votes and preserves the other members’ picks',
      ($) async {
    final api = GroupWatchPlanFixture(multiple: true);
    await openGroup($, api);
    await tapGroup($, 'Add another option');
    final search = find.descendant(
        of: find.byType(MovieSearchSheet), matching: find.byType(TextField));
    await $(search).enterText('Obsession');
    await $.tester.testTextInput.receiveAction(TextInputAction.done);
    await $.pumpAndSettle();
    final result = find.descendant(
        of: find.byType(MovieSearchResultTile),
        matching: find.text('Obsession'));
    await $(result).waitUntilVisible();
    await $(result).tap();
    await $.pumpAndSettle();
    expect(api.options.length, 3);
    expect(api.options.last['addedByUserId'], GroupWatchPlanFixture.viewer);
    await tapGroup($, 'Alien');
    await tapGroup($, 'Save my picks');
    expect(api.writes.last['candidateIds'],
        unorderedEquals(['alien', 'obsession']));
    expect(
        (api.options.first['choices'] as List)
            .any((c) => c['userId'] == GroupWatchPlanFixture.robin),
        isTrue);
    await $.tester.tap(find.byTooltip('Refresh'));
    await $.pumpAndSettle();
    expect(api.options.length, 3);
    expect(api.plan['selectedCandidateId'], isNull);
  });
  register(
      'four members: the creator reopens a scheduled single-film plan and adds another option',
      ($) async {
    final api = GroupWatchPlanFixture(creator: true)..schedule(dateOnly: true);
    final original = api.plan['scheduledFor'];
    await openGroup($, api);
    await tapGroup($, 'Change movie options');
    expect(api.plan['selectedCandidateId'], isNull);
    await tapGroup($, 'Add another option');
    await $(find.descendant(
            of: find.byType(MovieSearchSheet),
            matching: find.byType(TextField)))
        .enterText('Obsession');
    await $.tester.testTextInput.receiveAction(TextInputAction.done);
    await $.pumpAndSettle();
    await $(find.descendant(
            of: find.byType(MovieSearchResultTile),
            matching: find.text('Obsession')))
        .tap();
    await $.pumpAndSettle();
    expect(api.options.length, 2);
    expect(api.plan['scheduledFor'], original);
    expect(api.plan['scheduledDateOnly'], true);
  });
  register(
      'four members: only three remaining voters are needed after one member declines',
      ($) async {
    final api = GroupWatchPlanFixture(creator: true, multiple: true)
      ..decline(GroupWatchPlanFixture.blair);
    for (final option in api.options) {
      option['choices'] = [
        for (final id in [
          GroupWatchPlanFixture.viewer,
          GroupWatchPlanFixture.robin,
          GroupWatchPlanFixture.ellis
        ])
          {'userId': id}
      ];
    }
    await openGroup($, api);
    await tapGroup($, 'Choose');
    expect(api.plan['selectedCandidateId'], 'alien');
    expect(api.options.length, 2);
    expect(find.text('Propose a date'), findsOneWidget);
  });
  for (final timed in [false, true]) {
    register(
        'four members: propose ${timed ? 'a time' : 'a date only'} and keep all four required approvals',
        ($) async {
      final api = GroupWatchPlanFixture(creator: true);
      await openGroup($, api);
      await tapGroup($, 'Propose a date');
      if (timed) await tapGroup($, 'Date & time');
      await tapGroup($, 'Tomorrow');
      await tapGroup($, 'Save schedule');
      final proposal = api.proposals.single;
      expect(proposal['dateOnly'], !timed);
      expect((proposal['responses'] as List).length, 4);
      expect(api.plan['scheduledFor'], isNull);
      final date = DateTime.parse(proposal['proposedFor'] as String);
      if (timed) {
        expect(date.toLocal().hour, 19);
        expect(date.toLocal().minute, 30);
      } else {
        expect(date.hour, 12);
        final reminders =
            watchPlanReminderTimes(date, now: DateTime.now(), dateOnly: true);
        expect(reminders.morning!.hour, 9);
        expect(reminders.beforeWatch, isNull);
        expect(reminders.followUp, isNull);
      }
    });
    register(
        'four members: final approval confirms ${timed ? 'the exact time' : 'the day without an invented time'}',
        ($) async {
      final api = GroupWatchPlanFixture()..proposal(dateOnly: !timed);
      await openGroup($, api);
      await tapGroup($, 'Works for me');
      expect(api.plan['status'], 'SCHEDULED');
      expect(api.plan['scheduledDateOnly'], !timed);
      expect(api.plan['scheduledFor'], api.proposals.single['proposedFor']);
      expect(find.text('Confirmed attendees (4)'), findsOneWidget);
      if (!timed) {
        expect(find.textContaining('Time optional'), findsWidgets);
        expect(find.textContaining('1:00pm'), findsNothing);
      }
      await $.tester.tap(find.byTooltip('Refresh'));
      await $.pumpAndSettle();
      expect(find.text('Confirmed attendees (4)'), findsOneWidget);
    });
  }
  register(
      'four members: rejecting a replacement keeps the original time and membership',
      ($) async {
    final api = GroupWatchPlanFixture()
      ..schedule()
      ..proposal(dateOnly: true, allOthersAccepted: false);
    final original = api.plan['scheduledFor'];
    await openGroup($, api);
    await tapGroup($, 'Keep current time');
    expect(api.plan['scheduledFor'], original);
    expect(api.plan['scheduledDateOnly'], false);
    expect(api.statuses.every((s) => s['status'] == 'ACCEPTED'), isTrue);
    expect(find.text('Confirmed attendees (4)'), findsOneWidget);
  });
  register(
      'four members: creator confirms the unanimously approved replacement date',
      ($) async {
    final api = GroupWatchPlanFixture(creator: true)
      ..schedule()
      ..proposal(dateOnly: true, allAccepted: true);
    await openGroup($, api);
    await tapGroup($, 'Confirm new time');
    expect(api.plan['scheduledDateOnly'], true);
    expect(api.plan['scheduledFor'], '2099-07-11T12:00:00.000Z');
    expect(api.writes.single['decision'], 'accept_new');
    expect(find.text('Confirmed attendees (4)'), findsOneWidget);
  });
}
