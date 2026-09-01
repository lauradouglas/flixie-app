import 'package:flixie_app/core/auth/watch_plan_reminder_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Watch Plan morning reminder policy', () {
    final now = DateTime(2026, 9, 1, 8);

    test('skips the morning reminder for plans before 11am', () {
      expect(
        shouldScheduleWatchPlanMorningReminder(
          DateTime(2026, 9, 1, 9, 30),
          now: now,
        ),
        isFalse,
      );
      expect(
        shouldScheduleWatchPlanMorningReminder(
          DateTime(2026, 9, 1, 10, 59),
          now: now,
        ),
        isFalse,
      );
    });

    test('allows the morning reminder from 11am onward', () {
      expect(
        shouldScheduleWatchPlanMorningReminder(
          DateTime(2026, 9, 1, 11),
          now: now,
        ),
        isTrue,
      );
    });

    test('does not schedule a morning reminder after 9am', () {
      expect(
        shouldScheduleWatchPlanMorningReminder(
          DateTime(2026, 9, 1, 20),
          now: DateTime(2026, 9, 1, 9, 1),
        ),
        isFalse,
      );
    });
  });

  test('group one-hour reminder identifies the group', () {
    expect(
      watchPlanOneHourReminderBody(
        title: 'Demon Slayer',
        withName: 'Union All',
        scope: 'GROUP',
      ),
      'Demon Slayer with Union All starts in one hour.',
    );
    expect(
      watchPlanOneHourReminderBody(
        title: 'Demon Slayer',
        withName: 'Laura',
        scope: 'DIRECT',
      ),
      'Demon Slayer starts in one hour.',
    );
  });
}
