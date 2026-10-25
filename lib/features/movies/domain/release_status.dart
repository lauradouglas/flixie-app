import 'package:flixie_app/models/show.dart';

/// Catalogue dates are calendar days, not precise regional release times.
DateTime? releaseCalendarDate(String? value) {
  if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return null;
  }
  final date = DateTime.tryParse(value);
  if (date == null || date.toIso8601String().substring(0, 10) != value) {
    return null;
  }
  return date;
}

bool isNotReleasedYet({String? date, String? status, DateTime? now}) {
  final release = releaseCalendarDate(date);
  final today = now ?? DateTime.now();
  if (release != null) {
    return release.isAfter(DateTime(today.year, today.month, today.day));
  }
  return const {
    'rumored',
    'planned',
    'in production',
    'post production',
    'pilot'
  }.contains(status?.trim().toLowerCase());
}

String expectedReleaseLabel(String? value) {
  final date = releaseCalendarDate(value);
  if (date == null) return 'Release date to be announced';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return 'Expected ${date.day} ${months[date.month - 1]} ${date.year}';
}

/// An upcoming episode or season does not make an existing series unreleased.
bool isShowNotReleasedYet(TvShow show, {DateTime? now}) {
  final today = now ?? DateTime.now();
  bool hasAired(String? value) {
    final date = releaseCalendarDate(value);
    return date != null &&
        !date.isAfter(DateTime(today.year, today.month, today.day));
  }

  if (hasAired(show.firstAirDate) ||
      hasAired(show.lastAirDate) ||
      show.episodes.any((episode) => hasAired(episode.airDate)) ||
      show.seasons.any((season) =>
          season.episodes.any((episode) => hasAired(episode.airDate)))) {
    return false;
  }
  return isNotReleasedYet(
      date: show.firstAirDate, status: show.status, now: today);
}
