import 'package:flixie_app/models/watchlist_movie.dart';

class StatsEntry {
  const StatsEntry({this.movie, this.watchedAt});
  final WatchlistMovieDetails? movie;
  final DateTime? watchedAt;
}
