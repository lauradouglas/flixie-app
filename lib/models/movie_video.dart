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
      id: json['id'] as int,
      movieId: json['movieId'] as int,
      name: json['name'] as String,
      key: json['key'] as String,
      size: json['size'] as int,
      official: json['official'] as bool,
      languageAbr: json['languageAbr'] as String,
      countryAbr: json['countryAbr'] as String,
      publishedAt: json['publishedAt'] as String,
      videoTypeName: json['videoTypeName'] as String,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
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
