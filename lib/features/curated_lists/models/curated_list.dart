import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

tz.Location? _london;
DateTime londonDate(DateTime date) {
  if (_london == null) {
    try {
      _london = tz.getLocation('Europe/London');
    } catch (_) {
      tzdata.initializeTimeZones();
      _london = tz.getLocation('Europe/London');
    }
  }
  return tz.TZDateTime.from(date, _london!);
}

class CuratedFilm {
  const CuratedFilm(
      {required this.id, required this.title, this.poster, this.releaseDate});
  final int id;
  final String title;
  final String? poster, releaseDate;
  String get year => releaseDate?.split('-').first ?? '';
  factory CuratedFilm.fromJson(Map<String, dynamic> json) => CuratedFilm(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? 'Film',
      poster: json['posterPath'] as String?,
      releaseDate: json['releaseDate'] as String?);
}

class CuratedReward {
  const CuratedReward(
      {required this.type, required this.key, required this.name});
  final String type, key, name;
  bool get isPip => type == 'PIP';
  String? get asset => isPip && key == 'christmasLights'
      ? 'assets/icon/pip_cosmetics/christmas_lights.png'
      : !isPip && key == 'christmasLightsSnow'
          ? 'assets/icon/christmas_lights_border.svg'
          : null;
  factory CuratedReward.fromJson(Map<String, dynamic> json) {
    final pip = json['pipKey'] as String?;
    final border = json['borderKey'] as String?;
    final meta = (pip != null ? json['pip'] : json['border']) as Map?;
    return CuratedReward(
        type: pip != null ? 'PIP' : 'AVATAR_BORDER',
        key: pip ?? border ?? '',
        name: meta?['displayName'] as String? ??
            (pip != null ? 'Pip' : 'Avatar border'));
  }
}

enum CuratedListTheme { standard, christmas }

class CuratedList {
  const CuratedList(
      {required this.id,
      required this.title,
      this.description = '',
      this.theme = CuratedListTheme.standard,
      this.coverUrl,
      this.films = const [],
      this.rewards = const [],
      this.filmCount = 0,
      this.completionTarget,
      this.startsAt,
      this.endsAt,
      this.watchRule = 'DURING_CHALLENGE'});
  final String id, title, description, watchRule;
  final String? coverUrl;
  final CuratedListTheme theme;
  final List<CuratedFilm> films;
  final List<CuratedReward> rewards;
  final int filmCount;
  final int? completionTarget;
  final DateTime? startsAt, endsAt;
  int get requiredCount => completionTarget ?? filmCount;
  String get goal => completionTarget == null
      ? 'Watch and rate all $filmCount films'
      : 'Watch and rate any $requiredCount of these $filmCount films';
  String get dates => startsAt == null || endsAt == null
      ? 'Dates to be announced'
      : '${DateFormat('d MMM').format(londonDate(startsAt!))} – ${DateFormat('d MMM').format(londonDate(endsAt!.subtract(const Duration(milliseconds: 1))))}';
  bool openAt(DateTime now) =>
      startsAt != null &&
      endsAt != null &&
      !now.isBefore(startsAt!) &&
      now.isBefore(endsAt!);

  /// Remaining eligible UK calendar dates, including the current day.
  int? daysLeftAt(DateTime now) {
    if (!openAt(now)) return null;
    final today = londonDate(now);
    final lastDay =
        londonDate(endsAt!.subtract(const Duration(milliseconds: 1)));
    return DateTime.utc(lastDay.year, lastDay.month, lastDay.day)
            .difference(DateTime.utc(today.year, today.month, today.day))
            .inDays +
        1;
  }

  String? timingLabelAt(DateTime now) {
    if (startsAt != null && now.isBefore(startsAt!)) {
      final today = londonDate(now);
      final start = londonDate(startsAt!);
      final days = DateTime.utc(start.year, start.month, start.day)
          .difference(DateTime.utc(today.year, today.month, today.day))
          .inDays;
      return days == 0
          ? 'Opens today'
          : 'Opens in $days ${days == 1 ? 'day' : 'days'}';
    }
    final days = daysLeftAt(now);
    return days == null ? null : '$days ${days == 1 ? 'day' : 'days'} left';
  }

  String get rules =>
      '${watchRule == 'ANY_WATCH' ? 'Previous watches count, including diary entries without a known date.' : 'Log each film with a watched date during the challenge to count.'} Each film needs a diary watch with your rating to count. Logs must be saved before the challenge closes. Rewatching the same title counts once. Dates use UK time. Earned rewards are yours to keep.';
  factory CuratedList.fromJson(Map<String, dynamic> json) {
    final films = (json['items'] as List? ?? [])
        .whereType<Map>()
        .map((row) => CuratedFilm.fromJson(
            Map<String, dynamic>.from(row['movie'] as Map)))
        .toList();
    return CuratedList(
        id: json['id'] as String,
        title: json['title'] as String? ?? 'Flixie List',
        description: json['description'] as String? ?? '',
        theme: json['theme'] == 'CHRISTMAS'
            ? CuratedListTheme.christmas
            : CuratedListTheme.standard,
        coverUrl: json['coverUrl'] as String?,
        films: films,
        rewards: (json['rewards'] as List? ?? [])
            .whereType<Map>()
            .map(
                (row) => CuratedReward.fromJson(Map<String, dynamic>.from(row)))
            .toList(),
        filmCount: ((json['_count'] as Map?)?['items'] as num?)?.toInt() ??
            films.length,
        completionTarget: (json['completionTarget'] as num?)?.toInt(),
        startsAt: DateTime.tryParse(json['challengeStartsAt'] as String? ?? ''),
        endsAt: DateTime.tryParse(json['challengeEndsAt'] as String? ?? ''),
        watchRule: json['watchRule'] as String? ?? 'DURING_CHALLENGE');
  }
}

class CuratedProgress {
  const CuratedProgress(
      {this.watched = 0,
      this.required = 0,
      this.total = 0,
      this.joined = false,
      this.completedAt,
      this.watchedIds = const {}});
  final int watched, required, total;
  final bool joined;
  final DateTime? completedAt;
  final Set<int> watchedIds;
  double get fraction =>
      required <= 0 ? 0 : (watched / required).clamp(0, 1).toDouble();
  String get label => '$watched of $required watched & rated';
  factory CuratedProgress.fromJson(Map<String, dynamic> json) =>
      CuratedProgress(
          watched: (json['watched'] as num?)?.toInt() ?? 0,
          required: (json['required'] as num?)?.toInt() ?? 0,
          total: (json['total'] as num?)?.toInt() ?? 0,
          joined: json['joined'] == true,
          completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
          watchedIds: {
            for (final row in (json['items'] as List? ?? []).whereType<Map>())
              if (row['watched'] == true) (row['movieId'] as num).toInt()
          });
}
