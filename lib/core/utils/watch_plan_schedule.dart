/// Calendar dates are stored in UTC components and never converted to a watch time.
DateTime watchPlanCalendarDate(DateTime value, {bool dateOnly = false}) {
  final date = dateOnly ? value.toUtc() : value.toLocal();
  return DateTime(date.year, date.month, date.day);
}

DateTime encodeWatchPlanDate(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day, 12);

bool watchPlanScheduleHasPassed(DateTime value,
    {bool dateOnly = false, DateTime? now}) {
  final current = now ?? DateTime.now();
  if (!dateOnly) return !value.isAfter(current);
  final date = watchPlanCalendarDate(value, dateOnly: true);
  return !current.isBefore(DateTime(date.year, date.month, date.day + 1));
}
