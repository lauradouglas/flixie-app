import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/auth/setup_destination.dart';

void main() {
  test(
      'game signup returns to the game without carrying arbitrary query values',
      () {
    expect(setupDestination('/play/popcorn-catch?next=https://example.com'),
        '/play/popcorn-catch');
    expect(setupDestination('/play/unknown'), isNull);
  });
  test('Watchlist shortcut survives setup', () {
    expect(setupDestination('/watchlist'), '/watchlist');
    expect(
        setupDestination('/watchlist?next=https://example.com'), '/watchlist');
    expect(setupDestination('https://example.com/watchlist'), isNull);
  });
  test('keeps exact supported invitation and thread destinations', () {
    for (final route in [
      '/groups/group-1?tab=requests&requestId=plan-1',
      '/watch-requests/plan-1',
      '/friends/ellis',
      '/genre-communities/-1/discussions/thread-1?reply=reply-2',
      '/private-communities',
      '/community-invites/${'a' * 43}',
      '/notifications'
    ]) {
      expect(setupDestination(route), route);
    }
  });
  test('Social shortcut survives setup with a canonical internal destination',
      () {
    expect(setupDestination('/social'), '/social');
    expect(setupDestination('/social?next=https://example.com'), '/social');
    expect(setupDestination('flixie:///social'), isNull);
    expect(setupDestination('https://example.com/social'), isNull);
  });
  test('rejects external, auth and unrelated destinations', () {
    for (final route in [
      'https://example.com/groups/a',
      '//example.com/groups/a',
      '/auth/signup',
      '/onboarding',
      '/settings',
      'groups/a',
      ''
    ]) {
      expect(setupDestination(route), isNull);
    }
  });
}
