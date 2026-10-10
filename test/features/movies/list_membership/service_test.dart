import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/models/movie_list.dart';
import '../../../support/api_fixture.dart';

void main() {
  test('TV lookup uses the show endpoint even for the same numeric movie ID',
      () async {
    useApiFixture(MockClient((request) async {
      expect(request.url.path, endsWith('/lists/containing/show/11'));
      return http.Response('{"listIds":["tv"]}', 200);
    }));
    const tv = MovieList(id: 'tv', name: 'Alien Earth', removed: false);
    expect(
        await UserService.getMyListsContainingMedia('viewer', 11,
            isShow: true, lists: [tv]),
        [tv]);
  });
  const lists = [
    MovieList(id: 'alien', name: 'Alien', removed: false),
    MovieList(id: 'removed', name: 'Removed', removed: true)
  ];
  test('one ID lookup preserves list metadata and reads fresh after writes',
      () async {
    var reads = 0;
    var ids = ['alien', 'removed', 'not-accessible'];
    useApiFixture(MockClient((request) async {
      reads++;
      expect(request.url.path,
          endsWith('/users/viewer/lists/containing/movie/11'));
      return http.Response(jsonEncode({'listIds': ids}), 200);
    }));
    expect(
        await UserService.getMyListsContainingMovie('viewer', 11, lists: lists),
        [lists.first]);
    ids = [];
    expect(
        await UserService.getMyListsContainingMovie('viewer', 11, lists: lists),
        isEmpty);
    ids = ['alien'];
    expect(
        await UserService.getMyListsContainingMovie('viewer', 11, lists: lists),
        [lists.first]);
    expect(reads, 3);
  });
  test('malformed or failed lookup is not empty membership', () async {
    var body = '{}';
    var status = 200;
    useApiFixture(MockClient((_) async => http.Response(body, status)));
    await expectLater(
        UserService.getMyListsContainingMovie('viewer', 11, lists: lists),
        throwsFormatException);
    body = '{"message":"offline"}';
    status = 503;
    await expectLater(
        UserService.getMyListsContainingMovie('viewer', 11, lists: lists),
        throwsException);
  });
  test('no available lists requires no membership request', () async {
    useApiFixture(
        MockClient((_) async => throw StateError('Unexpected request')));
    expect(await UserService.getMyListsContainingMovie('viewer', 11, lists: []),
        isEmpty);
  });
}
