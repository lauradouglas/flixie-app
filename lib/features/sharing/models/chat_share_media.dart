class ChatShareMedia {
  const ChatShareMedia(
      {required this.id,
      required this.title,
      this.posterPath,
      this.isShow = false});
  final int id;
  final String title;
  final String? posterPath;
  final bool isShow;
}

String mediaDeepLink(ChatShareMedia movie) {
  return Uri(
    scheme: 'flixie',
    host: movie.isShow ? 'shows' : 'movies',
    pathSegments: [movie.id.toString()],
    queryParameters: const {'source': 'share'},
  ).toString();
}

String buildMediaSharePayload({
  required ChatShareMedia movie,
  required String message,
}) {
  final posterUrl = movie.posterPath == null
      ? ''
      : 'https://image.tmdb.org/t/p/w342${movie.posterPath}';
  final title = Uri.encodeComponent(movie.title);
  final deepLink = Uri.encodeComponent(mediaDeepLink(movie));
  final poster = Uri.encodeComponent(posterUrl);
  final prompt = Uri.encodeComponent(message.trim());

  final tag = movie.isShow ? 'FLIXIE_SHOW_SHARE' : 'FLIXIE_MOVIE_SHARE';
  return '[$tag]\n'
      'title=$title\n'
      'link=$deepLink\n'
      'poster=$poster\n'
      'message=$prompt\n'
      '[/$tag]';
}
