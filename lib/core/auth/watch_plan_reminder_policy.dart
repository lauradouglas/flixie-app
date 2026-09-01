const int watchPlanMorningReminderHour = 9;
const int watchPlanMorningReminderCutoffHour = 11;

bool shouldScheduleWatchPlanMorningReminder(
  DateTime scheduledFor, {
  required DateTime now,
}) {
  final localScheduledFor = scheduledFor.toLocal();
  if (localScheduledFor.hour < watchPlanMorningReminderCutoffHour) {
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
