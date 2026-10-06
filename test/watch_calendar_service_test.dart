import 'package:flixie_app/core/calendar/watch_calendar_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'a date-only watch exports an all-day calendar event without a start time',
      () {
    final event = WatchCalendarService.eventForScheduledWatch(
      title: 'Alien',
      scheduledFor: DateTime.utc(2026, 10, 8, 12),
      dateOnly: true,
      runtimeMinutes: 117,
    );
    expect(event.allDay, isTrue);
    expect(event.startDate, DateTime(2026, 10, 8));
    expect(event.endDate, DateTime(2026, 10, 9));
  });

  test('calendar duration rounds a movie runtime up to a half hour', () {
    expect(
      WatchCalendarService.calendarDurationForRuntime(165),
      const Duration(hours: 3),
    );
    expect(
      WatchCalendarService.calendarDurationForRuntime(125),
      const Duration(hours: 2, minutes: 30),
    );
  });

  test('calendar duration keeps the two-hour fallback without a runtime', () {
    expect(
      WatchCalendarService.calendarDurationForRuntime(null),
      const Duration(hours: 2),
    );
  });
}
