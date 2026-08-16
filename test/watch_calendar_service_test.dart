import 'package:flixie_app/core/calendar/watch_calendar_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
