import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/social/presentation/utils/movie_share_payload.dart';

void main() {
  for (final type in ['MOVIE', 'SHOW']) {
    test('$type shares retain title, link, poster and message', () {
      final host = type == 'SHOW' ? 'shows' : 'movies';
      final text = '[FLIXIE_${type}_SHARE]\n'
          'title=Title%20%26%20Friends\n'
          'link=${Uri.encodeComponent('flixie://$host/123?source=share')}\n'
          'poster=https%3A%2F%2Fexample.com%2Fposter.jpg\n'
          'message=Watch%20this%21\n[/FLIXIE_${type}_SHARE]';
      final result = parseMovieSharePayload(text)!;
      expect(result.title, 'Title & Friends');
      expect(result.isShow, type == 'SHOW');
      expect(result.link, 'flixie://$host/123?source=share');
      expect(result.prompt, 'Watch this!');
      expect(conversationMessagePreview(text), '🎬 Shared Title & Friends');
    });
  }
  test('mismatched share markers are not treated as a card', () {
    expect(
        parseMovieSharePayload(
            '[FLIXIE_SHOW_SHARE]\ntitle=A\nlink=B\n[/FLIXIE_MOVIE_SHARE]'),
        isNull);
  });
}
