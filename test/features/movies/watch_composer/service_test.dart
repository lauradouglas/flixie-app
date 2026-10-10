import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/features/movies/data/watch_composer_service.dart';
import '../../../support/api_fixture.dart';

void main() {
  test(
      'friend send identifies the current first candidate and preserves schedule payload',
      () async {
    final requests = <http.Request>[];
    useApiFixture(MockClient((r) async {
      requests.add(r);
      return http.Response('{"request":{"id":"friend-plan"}}', 200);
    }));
    final result = await const WatchComposerService().send(
        userId: 'fixture-viewer',
        recipientId: 'fixture-friend',
        group: false,
        movies: [1368337, 348],
        message: 'Movie night',
        proposedDate: '2099-07-10T12:00:00.000Z',
        dateOnly: true,
        location: 'Cinema');
    expect(result, 'friend-plan');
    expect(requests.single.url.path, '/requests');
    expect(jsonDecode(requests.single.body), {
      'requesterId': 'fixture-viewer',
      'recipientId': 'fixture-friend',
      'movieId': 1368337,
      'candidateMovieIds': [1368337, 348],
      'message': 'Movie night',
      'type': 'MOVIE_WATCH_REQUEST',
      'proposedDate': '2099-07-10T12:00:00.000Z',
      'proposedDateOnly': true,
      'location': 'Cinema'
    });
  });
  test(
      'group send resolves returned database plan and preserves candidate list',
      () async {
    final requests = <http.Request>[];
    useApiFixture(MockClient((r) async {
      requests.add(r);
      return http.Response(
          '{"watchRequest":{"id":"chat-plan","pgGroupRequestId":"database-plan"}}',
          200);
    }));
    final result = await const WatchComposerService().send(
        userId: 'fixture-viewer',
        recipientId: 'fixture-group',
        group: true,
        movies: [348, 1368337],
        message: 'Alien?',
        dateOnly: false);
    expect(result, 'database-plan');
    expect(requests.single.url.path, '/groups/fixture-group/send-request');
    final body = jsonDecode(requests.single.body);
    expect(body['candidateMovieIds'], [348, 1368337]);
    expect(body['mediaId'], 348);
    expect(body['userId'], 'fixture-viewer');
  });
  test('failed send propagates so UI can retain the draft and offer retry',
      () async {
    useApiFixture(MockClient(
        (_) async => http.Response('{"message":"Unavailable"}', 503)));
    await expectLater(
        const WatchComposerService().send(
            userId: 'fixture-viewer',
            recipientId: 'fixture-friend',
            group: false,
            movies: [348],
            message: '',
            dateOnly: false),
        throwsException);
  });
}
