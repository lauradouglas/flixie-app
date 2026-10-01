/// Only existing, internal invitation/content routes can survive setup.
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
  if (RegExp(r'^/(groups|watch-requests|friends|movie-lists)/[^/]+$')
          .hasMatch(path) ||
      RegExp(r'^/genre-communities/-?[0-9]+(?:/discussions/[^/]+)?$')
          .hasMatch(path) ||
      path == '/notifications') {
    return uri.toString();
  }
  return null;
}
