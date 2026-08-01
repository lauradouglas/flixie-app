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
      title: _stringOrFallback(json['title'] ?? json['name']),
      posterPath: _nullableString(json['poster'] ?? json['posterPath']),
    );
  }

  static String _stringOrFallback(dynamic value) {
    final text = _nullableString(value);
    return text ?? 'Untitled';
  }

  static String? _nullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'poster': posterPath,
    };
  }
}
