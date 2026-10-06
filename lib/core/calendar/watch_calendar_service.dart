import 'package:flixie_app/core/utils/watch_plan_schedule.dart';
import 'package:add_2_calendar/add_2_calendar.dart';

import 'package:flixie_app/core/utils/app_logger.dart';

class WatchCalendarService {
  const WatchCalendarService._();

  static Future<bool> addScheduledWatch({
    required String title,
    required DateTime scheduledFor,
    bool dateOnly = false,
    int? runtimeMinutes,
    String? note,
    String? location,
  }) async {
    try {
      return await Add2Calendar.addEvent2Cal(
        eventForScheduledWatch(
            title: title,
            scheduledFor: scheduledFor,
            dateOnly: dateOnly,
            runtimeMinutes: runtimeMinutes,
            note: note,
            location: location),
      );
    } catch (error, stackTrace) {
      logger.w(
        '[WatchCalendar] Could not open the calendar event editor',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  static Event eventForScheduledWatch({
    required String title,
    required DateTime scheduledFor,
    bool dateOnly = false,
    int? runtimeMinutes,
    String? note,
    String? location,
  }) =>
      Event(
        title: 'Watch $title',
        description: _description(note),
        location: location?.trim() ?? '',
        allDay: dateOnly,
        startDate: dateOnly
            ? watchPlanCalendarDate(scheduledFor, dateOnly: true)
            : scheduledFor.toLocal(),
        endDate: dateOnly
            ? watchPlanCalendarDate(scheduledFor, dateOnly: true)
                .add(const Duration(days: 1))
            : scheduledFor
                .toLocal()
                .add(calendarDurationForRuntime(runtimeMinutes)),
      );

  /// Movies rarely start exactly on time, so calendar entries round their
  /// runtime up to the next half hour. This leaves practical time to settle
  /// in without exaggerating shorter films; unknown runtimes keep the
  /// established two-hour fallback.
  static Duration calendarDurationForRuntime(int? runtimeMinutes) {
    if (runtimeMinutes == null || runtimeMinutes <= 0) {
      return const Duration(hours: 2);
    }
    final roundedMinutes = ((runtimeMinutes + 29) ~/ 30) * 30;
    return Duration(minutes: roundedMinutes);
  }

  static String _description(String? note) {
    final trimmedNote = note?.trim();
    if (trimmedNote == null || trimmedNote.isEmpty) {
      return 'Scheduled with Flixie';
    }
    return 'Scheduled with Flixie\n\n$trimmedNote';
  }
}
