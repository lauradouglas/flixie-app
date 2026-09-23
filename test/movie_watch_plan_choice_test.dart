import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/movies/data/movie_watch_plan_choice.dart';
import 'package:flixie_app/models/watch_request.dart';

void main() {
  WatchRequest plan([Map<String, dynamic> overrides = const {}]) =>
      WatchRequest.fromJson({
        'id': 'plan',
        'requesterId': 'friend',
        'recipientId': 'me',
        'type': 'MOVIE_WATCH_REQUEST',
        'movieId': 42,
        'status': 'ACCEPTED',
        'scheduleStatus': 'AGREED',
        'scheduledFor': '2099-09-23T20:00:00Z',
        'needsWatchConfirmation': false,
        'watchConfirmations': [],
        ...overrides,
      });
  test('agreed later plan is linkable before its due notification', () {
    final later = plan();
    expect(later.canConfirmWatchedFor('me'), isFalse);
    expect(MovieWatchPlanChoice.canLinkDirect(later, 'me', 42), isTrue);
    expect(MovieWatchPlanChoice.canLinkDirect(later, 'friend', 42), isTrue);
  });
  test('excludes unrelated, unconfirmed, closed and already logged plans', () {
    expect(MovieWatchPlanChoice.canLinkDirect(plan(), 'outsider', 42), isFalse);
    expect(MovieWatchPlanChoice.canLinkDirect(plan(), 'me', 43), isFalse);
    for (final override in <Map<String, dynamic>>[
      {'scheduleStatus': 'PROPOSED'},
      {'status': 'CANCELLED'},
      {'status': 'EXPIRED'},
      {'status': 'DECLINED'},
      {'hasCurrentUserLoggedWatch': true},
      {
        'watchConfirmations': [
          {'userId': 'me', 'watched': true}
        ]
      },
    ]) {
      expect(MovieWatchPlanChoice.canLinkDirect(plan(override), 'me', 42),
          isFalse);
    }
  });
}
