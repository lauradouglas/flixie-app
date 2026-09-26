/// Editorial content supplied by Flixie's curated creator registry.
/// Never inferred from ordinary profile badges or editable biography text.
class CreatorProfile {
  const CreatorProfile(
      {required this.role,
      required this.answers,
      this.credits = const [],
      this.coverUrl});
  final String role;
  final List<CreatorAnswer> credits;
  final String? coverUrl;
  final List<CreatorAnswer> answers;

  static CreatorProfile? parse(dynamic value) {
    if (value is! Map || value['verified'] != true) return null;
    final role = value['role'];
    if (role is! String || role.trim().isEmpty) return null;
    return CreatorProfile(
        role: role,
        coverUrl: value['coverUrl'] is String &&
                Uri.tryParse(value['coverUrl'])?.scheme == 'https'
            ? value['coverUrl']
            : null,
        credits: [
          for (final row
              in value['credits'] is List ? value['credits'] : const [])
            if (row is Map &&
                row['movieId'] is int &&
                row['title'] is String &&
                row['role'] is String)
              CreatorAnswer(
                  question: role.toLowerCase().startsWith('actor')
                      ? 'On screen'
                      : 'Behind the camera',
                  answer: row['role'],
                  movieId: row['movieId'],
                  title: row['title'],
                  posterPath:
                      row['posterPath'] is String ? row['posterPath'] : null),
        ],
        answers: [
          for (final row
              in value['answers'] is List ? value['answers'] : const [])
            if (row is Map &&
                row['question'] is String &&
                row['answer'] is String &&
                (row['answer'] as String).trim().isNotEmpty)
              CreatorAnswer(
                  question: row['question'],
                  answer: row['answer'],
                  movieId: row['movieId'] is int ? row['movieId'] : null,
                  title: row['title'] is String ? row['title'] : null,
                  posterPath:
                      row['posterPath'] is String ? row['posterPath'] : null),
        ]);
  }
}

class CreatorAnswer {
  const CreatorAnswer(
      {required this.question,
      required this.answer,
      this.movieId,
      this.title,
      this.posterPath});
  final String question, answer;
  final int? movieId;
  final String? title, posterPath;
}
