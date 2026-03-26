import 'genre.dart';
import 'movie_video.dart';

class Movie {
  final int id;
  final String title;
  final String? releaseDate;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final double? popularity;
  final double? voteAverage;
  final int? voteCount;
  final int? runtime;
  final String? tagline;
  final String? status;
  final int? budget;
  final List<Genre>? genres;
  final List<MovieVideo>? videos;
  final String? imdbId;
  final String? homepage;
  final String? instagramId;
  final String? twitterId;

  const Movie({
    required this.id,
    required this.title,
    this.releaseDate,
    this.overview,
    this.posterPath,
    this.backdropPath,
    this.popularity,
    this.voteAverage,
    this.voteCount,
    this.runtime,
    this.tagline,
    this.status,
    this.budget,
    this.genres,
    this.videos,
    this.imdbId,
    this.homepage,
    this.instagramId,
    this.twitterId,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'] as int,
      title: json['title'] as String,
      releaseDate: json['releaseDate'] as String?,
      overview: json['overview'] as String?,
      posterPath: json['posterPath'] as String?,
      backdropPath: json['backdropPath'] as String?,
      popularity: _parseDouble(json['popularity']),
      voteAverage: _parseDouble(json['voteAverage']),
      voteCount: _parseInt(json['voteCount']),
      runtime: _parseInt(json['runtime']),
      tagline: json['tagline'] as String?,
      status: json['status'] as String?,
      budget: _parseInt(json['budget']),
      genres: json['genres'] != null
          ? (json['genres'] as List<dynamic>)
              .map((e) => Genre.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      videos: json['videos'] != null
          ? (json['videos'] as List<dynamic>)
              .map((e) => MovieVideo.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      imdbId: json['imdbId'] as String?,
      homepage: json['homepage'] as String?,
      instagramId: json['instagramId'] as String?,
      twitterId: json['twitterId'] as String?,
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'releaseDate': releaseDate,
      'overview': overview,
      'posterPath': posterPath,
      'backdropPath': backdropPath,
      'popularity': popularity,
      'voteAverage': voteAverage,
      'voteCount': voteCount,
      'runtime': runtime,
      'tagline': tagline,
      'status': status,
      'genres': genres?.map((e) => e.toJson()).toList(),
      'videos': videos?.map((e) => e.toJson()).toList(),
    };
  }
}
