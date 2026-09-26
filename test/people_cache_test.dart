import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/social/data/people_cache.dart';
import 'package:flixie_app/models/friendship.dart';

void main() {
  const person = FriendshipUser(id: 'a', username: 'Avery');
  test('preload is shared and repeated tab reads do not reload', () async {
    final cache = PeopleCache()..selectAccount('me');
    final response = Completer<List<FriendshipUser>>();
    var calls = 0;
    Future<List<FriendshipUser>> load() {
      calls++;
      return response.future;
    }

    final first = cache.load(load);
    final second = cache.load(load);
    response.complete([person]);
    await Future.wait([first, second]);
    await cache.load(load);
    expect(calls, 1);
    expect(cache.following!.single.id, 'a');
  });
  test(
      'unfollow cannot be undone by a stale read; account switch clears people',
      () async {
    final cache = PeopleCache()..selectAccount('me');
    await cache.load(() async => [person]);
    final response = Completer<List<FriendshipUser>>();
    final pending = cache.load(() => response.future, refresh: true);
    cache.remove('a');
    response.complete([person]);
    await pending;
    expect(cache.following, isEmpty);
    final other = Completer<List<FriendshipUser>>();
    final old = cache.load(() => other.future, refresh: true);
    cache.selectAccount('other');
    other.complete([person]);
    await old;
    expect(cache.following, isNull);
  });
  test('failed refresh preserves visible people', () async {
    final cache = PeopleCache()..selectAccount('me');
    await cache.load(() async => [person]);
    await cache.load(() async => throw StateError('offline'), refresh: true);
    expect(cache.following!.single.id, 'a');
  });
}
