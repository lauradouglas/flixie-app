import 'recommendation_attribution.dart';

enum DetailSource {
  search('search'),
  trending('trending'),
  justForYou('just_for_you'),
  friendsWatching('friends_watching'),
  friendActivity('friend_activity'),
  watchlist('watchlist'),
  watchHistory('watch_history'),
  list('list'),
  group('group'),
  watchPlan('watch_plan'),
  personCredits('person_credits'),
  sharedLink('shared_link'),
  notification('notification'),
  unknown('unknown');

  const DetailSource(this.value);

  final String value;

  static DetailSource fromValue(String? value) => values.firstWhere(
        (source) => source.value == value,
        orElse: () => DetailSource.unknown,
      );
}

String movieDetailPath(
  Object movieId, {
  DetailSource source = DetailSource.unknown,
  bool fromMovieMatch = false,
  RecommendationAttribution? recommendation,
}) =>
    _detailPath(
      'movies',
      movieId,
      source,
      extra: fromMovieMatch ? const {'movieMatch': '1'} : null,
      recommendation: recommendation,
    );

String showDetailPath(
  Object showId, {
  DetailSource source = DetailSource.unknown,
}) =>
    _detailPath('shows', showId, source);

String personDetailPath(
  Object personId, {
  DetailSource source = DetailSource.unknown,
  int? parentContentId,
  String? parentContentType,
}) =>
    _detailPath(
      'people',
      personId,
      source,
      extra: {
        if (parentContentId != null)
          'parentContentId': parentContentId.toString(),
        if (parentContentType == 'movie' || parentContentType == 'show')
          'parentContentType': parentContentType!,
      },
    );

String _detailPath(
  String entity,
  Object id,
  DetailSource source, {
  Map<String, String>? extra,
  RecommendationAttribution? recommendation,
}) {
  return Uri(
    path: '/$entity/$id',
    queryParameters: {
      'source': source.value,
      ...?extra,
      ...?recommendation?.routeParameters,
    },
  ).toString();
}
