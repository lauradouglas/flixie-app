class SimilarMovie {
  final int id;
  final String title;
  final String? posterPath;

  const SimilarMovie({
    required this.id,
    required this.title,
    this.posterPath,
  });

  factory SimilarMovie.fromJson(Map<String, dynamic> json) {
    return SimilarMovie(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      title: json['title'] as String,
      posterPath: json['poster'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'poster': posterPath,
    };
  }
}
