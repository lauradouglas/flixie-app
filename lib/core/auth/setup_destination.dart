/// Only supported internal destinations can survive setup.
/// This is navigation state, never an authorization decision.
String? setupDestination(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !value.startsWith('/')) {
    return null;
  }
  final path = uri.path;
  if (path == '/watchlist') return '/watchlist';
  if (path == '/social') return '/social';
  if (path == '/search' && uri.queryParameters['focus'] == '1') {
    return '/search?focus=1';
  }
  if (RegExp(r'^/(groups|watch-requests|friends|movie-lists)/[^/]+$')
          .hasMatch(path) ||
      RegExp(r'^/genre-communities/-?[0-9]+(?:/discussions/[^/]+)?$')
          .hasMatch(path) ||
      path == '/notifications') {
    return uri.toString();
  }
  return null;
}
