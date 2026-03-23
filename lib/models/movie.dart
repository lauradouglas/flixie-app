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
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'] as int,
      title: json['title'] as String,
      releaseDate: json['releaseDate'] as String?,
      overview: json['overview'] as String?,
      posterPath: json['posterPath'] as String?,
      backdropPath: json['backdropPath'] as String?,
      popularity: (json['popularity'] as num?)?.toDouble(),
      voteAverage: (json['voteAverage'] as num?)?.toDouble(),
      voteCount: json['voteCount'] as int?,
      runtime: json['runtime'] as int?,
      tagline: json['tagline'] as String?,
      status: json['status'] as String?,
    );
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
    };
  }
}
