class MovieSharePayload {
  const MovieSharePayload({
    required this.title,
    required this.link,
    required this.posterUrl,
    required this.prompt,
  });

  final String title;
  final String link;
  final String posterUrl;
  final String prompt;
}

MovieSharePayload? parseMovieSharePayload(String text) {
  final match = RegExp(
    r'\[FLIXIE_MOVIE_SHARE\]([\s\S]*?)\[/FLIXIE_MOVIE_SHARE\]',
    multiLine: true,
  ).firstMatch(text);
  if (match == null) return null;

  final data = <String, String>{};
  for (final rawLine in (match.group(1) ?? '').split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    final separator = line.indexOf('=');
    if (separator <= 0) continue;
    final key = line.substring(0, separator).trim();
    final value = line.substring(separator + 1).trim();
    try {
      data[key] = Uri.decodeComponent(value);
    } on FormatException {
      data[key] = value;
    }
  }

  final title = data['title']?.trim() ?? '';
  final link = data['link']?.trim() ?? '';
  if (title.isEmpty || link.isEmpty) return null;

  return MovieSharePayload(
    title: title,
    link: link,
    posterUrl: data['poster']?.trim() ?? '',
    prompt: data['message']?.trim() ?? '',
  );
}

String conversationMessagePreview(String? message) {
  final value = message?.trim() ?? '';
  if (value.isEmpty) return 'Start the conversation';

  final movieShare = parseMovieSharePayload(value);
  if (movieShare != null) return '🎬 Shared ${movieShare.title}';

  return value;
}
