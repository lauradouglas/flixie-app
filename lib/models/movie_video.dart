class MovieVideo {
  final int id;
  final int movieId;
  final String name;
  final String key;
  final int size;
  final bool official;
  final String languageAbr;
  final String countryAbr;
  final String publishedAt;
  final String videoTypeName;
  final String createdAt;
  final String updatedAt;

  const MovieVideo({
    required this.id,
    required this.movieId,
    required this.name,
    required this.key,
    required this.size,
    required this.official,
    required this.languageAbr,
    required this.countryAbr,
    required this.publishedAt,
    required this.videoTypeName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MovieVideo.fromJson(Map<String, dynamic> json) {
    return MovieVideo(
      id: _intValue(json['id']) ?? 0,
      movieId: _intValue(json['movieId']) ?? 0,
      name: _stringOrFallback(json['name'], fallback: 'Trailer'),
      key: _stringOrFallback(json['key']),
      size: _intValue(json['size']) ?? 0,
      official: json['official'] as bool? ?? false,
      languageAbr: _stringOrFallback(json['languageAbr'], fallback: 'en'),
      countryAbr: _stringOrFallback(json['countryAbr'], fallback: 'US'),
      publishedAt: _stringOrFallback(json['publishedAt']),
      videoTypeName: _stringOrFallback(
        json['videoTypeName'],
        fallback: 'Trailer',
      ),
      createdAt: _stringOrFallback(json['createdAt']),
      updatedAt: _stringOrFallback(json['updatedAt']),
    );
  }

  static String? _nullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static String _stringOrFallback(dynamic value, {String fallback = ''}) {
    return _nullableString(value) ?? fallback;
  }

  static int? _intValue(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'movieId': movieId,
      'name': name,
      'key': key,
      'size': size,
      'official': official,
      'languageAbr': languageAbr,
      'countryAbr': countryAbr,
      'publishedAt': publishedAt,
      'videoTypeName': videoTypeName,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  /// Returns the YouTube URL for this video
  String get youtubeUrl => 'https://www.youtube.com/watch?v=$key';

  /// Returns the YouTube embed URL for this video
  String get youtubeEmbedUrl => 'https://www.youtube.com/embed/$key';

  /// Returns the YouTube thumbnail URL for this video
  String get thumbnailUrl => 'https://img.youtube.com/vi/$key/hqdefault.jpg';
}
