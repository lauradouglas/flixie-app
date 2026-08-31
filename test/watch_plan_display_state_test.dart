import 'package:flixie_app/features/watch_plans/presentation/utils/watch_plan_display_state.dart';
import 'package:flixie_app/features/watch_plans/presentation/utils/watch_plan_formatters.dart';
import 'package:flixie_app/features/watch_plans/presentation/utils/watch_plan_section_builder.dart';
import 'package:flixie_app/models/watch_request.dart';
import 'package:flutter_test/flutter_test.dart';

WatchRequest plan(String id, Map<String, Object?> values) =>
    WatchRequest.fromJson({'id': id, ...values});

void main() {
  final now = DateTime.utc(2026, 9, 1, 12);

  group('WatchPlanDisplayState filters', () {
    final incoming = plan('incoming', {
      'requesterId': 'friend',
      'recipientId': 'me',
      'status': 'PENDING',
    });
    final planning = plan('planning', {
      'requesterId': 'me',
      'recipientId': 'friend',
      'status': 'ACCEPTED',
    });
    final upcoming = plan('upcoming', {
      'status': 'SCHEDULED',
      'scheduleStatus': 'AGREED',
      'scheduledFor': '2026-09-02T12:00:00.000Z',
    });
    final past = plan('past', {
      'status': 'SCHEDULED',
      'scheduleStatus': 'AGREED',
      'scheduledFor': '2026-08-31T12:00:00.000Z',
    });
    final completed = plan('completed', {'status': 'COMPLETED'});
    final declined = plan('declined', {'status': 'DECLINED'});
    final cancelled = plan('cancelled', {'status': 'CANCELLED'});
    final expired = plan('expired', {'status': 'EXPIRED'});

    test('matches every list filter', () {
      expect(
          WatchPlanDisplayState.matchesFilter(
              incoming, WatchPlanFilter.needsResponse, 'me',
              now: now),
          isTrue);
      expect(
          WatchPlanDisplayState.matchesFilter(
              planning, WatchPlanFilter.planning, 'me',
              now: now),
          isTrue);
      expect(
          WatchPlanDisplayState.matchesFilter(
              upcoming, WatchPlanFilter.scheduled, 'me',
              now: now),
          isTrue);
      expect(
          WatchPlanDisplayState.matchesFilter(
              past, WatchPlanFilter.completed, 'me',
              now: now),
          isTrue);
      expect(
          WatchPlanDisplayState.matchesFilter(
              completed, WatchPlanFilter.completed, 'me',
              now: now),
          isTrue);
      expect(
          WatchPlanDisplayState.matchesFilter(
              declined, WatchPlanFilter.declined, 'me',
              now: now),
          isTrue);
      expect(
          WatchPlanDisplayState.matchesFilter(
              cancelled, WatchPlanFilter.cancelled, 'me',
              now: now),
          isTrue);
      expect(
          WatchPlanDisplayState.matchesFilter(
              expired, WatchPlanFilter.expired, 'me',
              now: now),
          isTrue);
    });

    test('builds mutually exclusive active sections', () {
      final sections = WatchPlanSectionBuilder.friendSections(
        [incoming, planning, upcoming, past],
        'me',
        now: now,
      );
      expect(sections.needsReply.map((item) => item.id), ['incoming']);
      expect(sections.planning.map((item) => item.id), ['planning']);
      expect(sections.upcoming.map((item) => item.id), ['upcoming']);
      expect(sections.readyToWrapUp.map((item) => item.id), ['past']);
    });
  });

  group('friend post-watch display state', () {
    WatchRequest withConfirmations(List<Map<String, Object?>> entries) =>
        plan('post-watch', {
          'status': 'SCHEDULED',
          'watchConfirmations': entries,
        });

    test('distinguishes nobody, me, other, and everyone logged', () {
      expect(
        WatchPlanDisplayState.postWatchState(withConfirmations([]), 'me'),
        FriendPostWatchState.nobodyLogged,
      );
      expect(
        WatchPlanDisplayState.postWatchState(
            withConfirmations([
              {'userId': 'me', 'watched': true}
            ]),
            'me'),
        FriendPostWatchState.waitingForOthers,
      );
      expect(
        WatchPlanDisplayState.postWatchState(
            withConfirmations([
              {'userId': 'friend', 'watched': true, 'rating': 8}
            ]),
            'me'),
        FriendPostWatchState.waitingForMe,
      );
      expect(
        WatchPlanDisplayState.postWatchState(
            withConfirmations([
              {'userId': 'me', 'watched': true},
              {'userId': 'friend', 'watched': true},
            ]),
            'me'),
        FriendPostWatchState.recap,
      );
    });

    test('keeps the other rating hidden until I log a watched response', () {
      final otherOnly = withConfirmations([
        {'userId': 'friend', 'watched': true, 'rating': 8}
      ]);
      final both = withConfirmations([
        {'userId': 'me', 'watched': true, 'rating': 6},
        {'userId': 'friend', 'watched': true, 'rating': 8},
      ]);
      expect(WatchPlanDisplayState.canRevealOtherRatings(otherOnly, 'me'),
          isFalse);
      expect(WatchPlanDisplayState.canRevealOtherRatings(both, 'me'), isTrue);
    });
  });

  test('formats schedule and undecided location consistently', () {
    expect(
      formatWatchPlanDateTime(
        DateTime(2026, 9, 2, 20, 5),
        now: DateTime(2026, 9, 1, 10),
      ),
      'Tomorrow at 8:05pm',
    );
    expect(formatWatchPlanLocation(null), 'Location undecided');
    expect(formatWatchPlanLocation('  Cinema  '), 'Cinema');
  });
}
