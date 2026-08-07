class MovieImage {
  const MovieImage({
    required this.movieId,
    required this.aspectRatio,
    required this.height,
    required this.width,
    required this.path,
  });

  final int movieId;
  final double aspectRatio;
  final int height;
  final int width;
  final String path;

  factory MovieImage.fromJson(Map<String, dynamic> json) => MovieImage(
        movieId: _int(json['movieId']) ?? 0,
        aspectRatio: _double(json['aspectRatio']) ?? 1,
        height: _int(json['height']) ?? 0,
        width: _int(json['width']) ?? 0,
        path: json['imageUrl']?.toString().trim() ?? '',
      );

  String get originalUrl => path.startsWith('http')
      ? path
      : 'https://image.tmdb.org/t/p/original$path';

  String get thumbnailUrl =>
      path.startsWith('http') ? path : 'https://image.tmdb.org/t/p/w500$path';
}

class MovieImages {
  const MovieImages({
    this.posters = const [],
    this.backdrops = const [],
    this.logos = const [],
  });

  final List<MovieImage> posters;
  final List<MovieImage> backdrops;
  final List<MovieImage> logos;

  factory MovieImages.fromJson(Map<String, dynamic> json) => MovieImages(
        posters: _list(json['posters']),
        backdrops: _list(json['backdrops']),
        logos: _list(json['logos']),
      );

  List<MovieImage> get gallery => [...backdrops, ...posters];

  static List<MovieImage> _list(dynamic value) => value is Iterable
      ? value
          .whereType<Map<String, dynamic>>()
          .map(MovieImage.fromJson)
          .where((image) => image.path.isNotEmpty)
          .toList(growable: false)
      : const [];
}

int? _int(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

double? _double(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
