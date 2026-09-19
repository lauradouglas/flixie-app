import 'package:flixie_app/models/watch_provider.dart';

enum WatchlistMood {
  any('Any experience', 'any', 'Keep your options open'),
  switchOff('Switch off', 'switch_off', 'Easy to follow, low tension'),
  cozy('Feel good', 'feel_good', 'Warm, uplifting, reassuring'),
  funny('Have a laugh', 'laugh', 'Comedy first; dark humour is flagged'),
  gripping('Get hooked', 'hooked', 'Suspense, intrigue and momentum'),
  moving('Feel something', 'feel_something',
      'Emotional depth, with weight made clear'),
  escape('Escape somewhere', 'escape', 'Adventure and immersive worlds'),
  challenged(
      'Be challenged', 'challenged', 'Complex or thought-provoking stories'),
  scared('Get scared', 'scared', 'Horror, with intensity made clear');

  const WatchlistMood(this.label, this.id, this.description);
  final String label, id, description;
}

class ExperienceFit {
  ExperienceFit.fromJson(Map<String, dynamic> json)
      : eligible = json['eligible'] == true,
        tier = json['tier'] as String? ?? 'unknown',
        source = json['source'] as String? ?? 'none',
        score = (json['score'] as num?)?.toDouble() ?? 0,
        personalScore = (json['personalScore'] as num?)?.toDouble() ?? 0,
        popularity = (json['popularity'] as num?)?.toDouble() ?? 0,
        reasons = (json['reasons'] as List? ?? []).whereType<String>().toList();
  final bool eligible;
  final String tier, source;
  final double score, personalScore, popularity;
  final List<String> reasons;
  String get label => tier == 'possible'
      ? 'Possible match'
      : source == 'reviewed'
          ? 'Reviewed match'
          : 'Experience not reviewed';
  int compareTo(ExperienceFit other) {
    final confidence = other.score.compareTo(score);
    if (confidence != 0) return confidence;
    final taste = other.personalScore.compareTo(personalScore);
    return taste != 0 ? taste : other.popularity.compareTo(popularity);
  }
}

bool fitsWatchTime(int? runtime, int? maximum) =>
    maximum == null || (runtime != null && runtime > 0 && runtime <= maximum);

bool matchesWatchServices(
  List<WatchProvider> offers, {
  required Set<int> selectedIds,
  Set<String> selectedNames = const {},
  required bool includeRentals,
}) =>
    offers.any((offer) =>
        (offer.isIncludedOffer &&
            (selectedIds.contains(offer.id) ||
                selectedNames.contains(offer.matchKey))) ||
        (includeRentals && offer.isRental));
