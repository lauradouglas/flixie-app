import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/auth/setup_destination.dart';

void main() {
  test('keeps exact supported invitation and thread destinations', () {
    for (final route in [
      '/groups/group-1?tab=requests&requestId=plan-1',
      '/watch-requests/plan-1',
      '/friends/ellis',
      '/genre-communities/-1/discussions/thread-1?reply=reply-2',
      '/notifications'
    ]) {
      expect(setupDestination(route), route);
    }
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
