class MovieShort {
  final int id;
  final String name;
  final String? originalLanguage;
  final String? poster;
  final String? releaseDate;
  final String? overview;
  final Trailer? trailer;
  final String? mediaType;
  final double? voteAverage;

  const MovieShort({
    required this.id,
    required this.name,
    this.originalLanguage,
    this.poster,
    this.releaseDate,
    this.overview,
    this.trailer,
    this.mediaType,
    this.voteAverage,
  });

  factory MovieShort.fromJson(Map<String, dynamic> json) {
    return MovieShort(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: (json['name'] ?? json['title']) as String,
      originalLanguage: json['originalLanguage'] as String?,
      poster: json['poster'] as String?,
      releaseDate: json['releaseDate'] as String?,
      overview: json['overview'] as String?,
      trailer: json['trailer'] != null
          ? Trailer.fromJson(json['trailer'] as Map<String, dynamic>)
          : null,
      mediaType: json['mediaType'] as String?,
      voteAverage: (json['voteAverage'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'originalLanguage': originalLanguage,
      'poster': poster,
      'releaseDate': releaseDate,
      'overview': overview,
      'trailer': trailer?.toJson(),
      'mediaType': mediaType,
      'voteAverage': voteAverage,
    };
  }
}

class Trailer {
  final String? iso6391;
  final String? iso31661;
  final String? name;
  final String? key;
  final String? site;
  final int? size;
  final String? type;
  final bool? official;
  final String? publishedAt;
  final String? id;

  const Trailer({
    this.iso6391,
    this.iso31661,
    this.name,
    this.key,
    this.site,
    this.size,
    this.type,
    this.official,
    this.publishedAt,
    this.id,
  });

  factory Trailer.fromJson(Map<String, dynamic> json) {
    return Trailer(
      iso6391: json['iso_639_1'] as String?,
      iso31661: json['iso_3166_1'] as String?,
      name: json['name'] as String?,
      key: json['key'] as String?,
      site: json['site'] as String?,
      size: json['size'] as int?,
      type: json['type'] as String?,
      official: json['official'] as bool?,
      publishedAt: json['published_at'] as String?,
      id: json['id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'iso_639_1': iso6391,
      'iso_3166_1': iso31661,
      'name': name,
      'key': key,
      'site': site,
      'size': size,
      'type': type,
      'official': official,
      'published_at': publishedAt,
      'id': id,
    };
  }
}
