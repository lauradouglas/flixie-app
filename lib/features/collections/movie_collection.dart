import 'package:flixie_app/core/api/api_client.dart';

class CollectionFilm {
  CollectionFilm(Map<String, dynamic> json)
      : id = json['id'] as int,
        title = json['title'] as String,
        posterPath = json['posterPath'] as String?,
        releaseDate = DateTime.tryParse(json['releaseDate'] ?? ''),
        watched = json['watched'] == true,
        onWatchlist = json['onWatchlist'] == true,
        rating = json['rating'] as int?;
  final int id;
  final String title;
  final String? posterPath;
  final DateTime? releaseDate;
  final bool watched;
  bool onWatchlist;
  final int? rating;
  bool get released =>
      releaseDate != null && !releaseDate!.isAfter(DateTime.now());
}

class MovieCollection {
  MovieCollection(Map<String, dynamic> json)
      : name = json['name'] as String,
        overview = json['overview'] as String? ?? '',
        backdropPath = json['backdropPath'] as String?,
        films = (json['films'] as List)
            .map((item) => CollectionFilm(Map<String, dynamic>.from(item)))
            .toList();
  final String name;
  final String overview;
  final String? backdropPath;
  final List<CollectionFilm> films;
  List<CollectionFilm> get released => films.where((f) => f.released).toList();
  int get watchedCount => released.where((f) => f.watched).length;
  List<CollectionFilm> get remaining => films.where((f) => !f.watched).toList();
  List<CollectionFilm> get toAdd =>
      remaining.where((f) => !f.onWatchlist).toList();
  static Future<MovieCollection> load(int id) async => MovieCollection(
      Map<String, dynamic>.from(await ApiClient.get('/movies/collections/$id',
          authenticated: ApiClient.getToken()?.isNotEmpty ?? false)));
}
