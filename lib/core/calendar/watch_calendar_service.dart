import 'package:add_2_calendar/add_2_calendar.dart';

import 'package:flixie_app/core/utils/app_logger.dart';

class WatchCalendarService {
  const WatchCalendarService._();

  static Future<bool> addScheduledWatch({
    required String title,
    required DateTime scheduledFor,
    String? note,
  }) async {
    try {
      return await Add2Calendar.addEvent2Cal(
        Event(
          title: 'Watch $title',
          description: _description(note),
          startDate: scheduledFor.toLocal(),
          endDate: scheduledFor.toLocal().add(const Duration(hours: 2)),
        ),
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

  static String _description(String? note) {
    final trimmedNote = note?.trim();
    if (trimmedNote == null || trimmedNote.isEmpty) {
      return 'Scheduled with Flixie';
    }
    return 'Scheduled with Flixie\n\n$trimmedNote';
  }
}
