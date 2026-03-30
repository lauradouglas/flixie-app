class TopRatedMovie {
  final int id;
  final String title;
  final String? posterPath;
  final String? releaseDate;
  final double averageRating;
  final int ratingCount;

  const TopRatedMovie({
    required this.id,
    required this.title,
    this.posterPath,
    this.releaseDate,
    required this.averageRating,
    required this.ratingCount,
  });

  factory TopRatedMovie.fromJson(Map<String, dynamic> json) {
    return TopRatedMovie(
      id: json['id'] as int,
      title: json['title'] as String,
      posterPath: json['posterPath'] as String?,
      releaseDate: json['releaseDate'] as String?,
      averageRating: (json['averageRating'] as num).toDouble(),
      ratingCount: (json['ratingCount'] as num).toInt(),
    );
  }
}
