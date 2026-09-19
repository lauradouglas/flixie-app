/// Release dates are calendar dates, independent of streaming availability.
enum ReleaseStatus { outNow, comingSoon, unknown }

ReleaseStatus releaseStatus(String? value, {DateTime? now}) {
  final match =
      RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:$|T)').firstMatch(value ?? '');
  if (match == null) return ReleaseStatus.unknown;
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return ReleaseStatus.unknown;
  }
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  return date.isAfter(today) ? ReleaseStatus.comingSoon : ReleaseStatus.outNow;
}
