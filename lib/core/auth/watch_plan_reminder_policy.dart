import 'package:flixie_app/core/utils/watch_plan_schedule.dart';

const int watchPlanMorningReminderHour = 9;
const int watchPlanMorningReminderCutoffHour = 11;

bool shouldScheduleWatchPlanMorningReminder(
  DateTime scheduledFor, {
  required DateTime now,
  bool dateOnly = false,
}) {
  final localScheduledFor = dateOnly
      ? watchPlanCalendarDate(scheduledFor, dateOnly: true)
      : scheduledFor.toLocal();
  if (!dateOnly &&
      localScheduledFor.hour < watchPlanMorningReminderCutoffHour) {
    return false;
  }
  final morning = DateTime(
    localScheduledFor.year,
    localScheduledFor.month,
    localScheduledFor.day,
    watchPlanMorningReminderHour,
  );
  return morning.isAfter(now);
}

String watchPlanOneHourReminderBody({
  required String title,
  required String withName,
  required String scope,
}) {
  return scope.toUpperCase() == 'GROUP'
      ? '$title with $withName starts in one hour.'
      : '$title starts in one hour.';
}

({DateTime? morning, DateTime? beforeWatch, DateTime? followUp})
    watchPlanReminderTimes(DateTime scheduledFor,
        {required DateTime now, bool dateOnly = false}) {
  final date = dateOnly
      ? watchPlanCalendarDate(scheduledFor, dateOnly: true)
      : scheduledFor.toLocal();
  final morning =
      DateTime(date.year, date.month, date.day, watchPlanMorningReminderHour);
  final before = date.subtract(const Duration(hours: 1));
  final after = date.add(const Duration(hours: 2));
  return (
    morning: shouldScheduleWatchPlanMorningReminder(scheduledFor,
            now: now, dateOnly: dateOnly)
        ? morning
        : null,
    beforeWatch: !dateOnly && before.isAfter(now) ? before : null,
    followUp: !dateOnly && after.isAfter(now) ? after : null,
  );
}
