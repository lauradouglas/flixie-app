import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/features/sharing/presentation/media_share_session.dart';
import 'package:flixie_app/features/sharing/models/chat_share_media.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/features/social/presentation/utils/movie_share_payload.dart';
import '../../support/api_fixture.dart';
import 'fixture.dart';
import 'before_loaders.dart';

const movie = ChatShareMedia(
    id: 123, title: 'The Odyssey & Alien', posterPath: '/fixture.jpg');
final friend = FriendsData.fromJson(friendsPayload(1)).friendships.first;
final group = Group.fromJson(groupsPayload(1).first);
void main() {
  test('failed loading remains retryable and cleared empty cache reloads',
      () async {
    var reads = 0;
    useApiFixture(MockClient((r) async {
      reads++;
      return http.Response(reads == 1 ? '{}' : jsonEncode(friendsPayload(0)),
          reads == 1 ? 400 : 200);
    }));
    final auth = ShareAuth();
    final session = MediaShareSession(auth);
    addTearDown(auth.dispose);
    addTearDown(session.dispose);
    await expectLater(session.loadFriends(), throwsA(isA<Exception>()));
    expect(auth.cachedFriends, isNull);
    expect(await session.loadFriends(), isEmpty);
    expect(reads, 2);
    expect(await session.loadFriends(), isEmpty);
    expect(reads, 2);
    auth.friends = null;
    expect(await session.loadFriends(), isEmpty);
    expect(reads, 3);
  });

  for (final count in [0, 100]) {
    test(
        'three opens with $count recipients: original versus current HTTP reads',
        () async {
      var reads = 0;
      useApiFixture(MockClient((r) async {
        reads++;
        return http.Response(
            jsonEncode(r.url.path.startsWith('/friends')
                ? friendsPayload(count)
                : groupsPayload(count)),
            200);
      }));
      final old = ShareAuth();
      addTearDown(old.dispose);
      final before = BeforeShareLoaders(old);
      for (var i = 0; i < 3; i++) {
        await before.loadFriends(old.id!);
        await before.loadGroups(old.id!);
      }
      final beforeReads = reads;
      expect(beforeReads, count == 0 ? 6 : 2);
      reads = 0;
      final auth = ShareAuth();
      addTearDown(auth.dispose);
      for (var i = 0; i < 3; i++) {
        final s = MediaShareSession(auth);
        expect((await s.loadFriends()).length, count);
        expect((await s.loadGroups()).length, count);
        s.dispose();
      }
      expect(reads, 2);
      // ignore: avoid_print
      print(
          'MEDIA_SHARE_BASELINE count=$count opens=3 beforeReads=$beforeReads afterReads=$reads');
    });
  }
  for (final groups in [false, true]) {
    test(
        'late ${groups ? 'groups' : 'friends'} read cannot publish across account changes',
        () async {
      final pending = Completer<http.Response>();
      useApiFixture(MockClient((_) => pending.future));
      final auth = ShareAuth();
      final s = MediaShareSession(auth);
      addTearDown(auth.dispose);
      addTearDown(s.dispose);
      final load = groups ? s.loadGroups() : s.loadFriends();
      final check = expectLater(load, throwsStateError);
      auth.change('new');
      auth.change('fixture-viewer');
      pending.complete(http.Response(
          jsonEncode(groups ? groupsPayload(100) : friendsPayload(100)), 200));
      await check;
      expect(auth.publications, 0);
      expect(s.isCurrent, false);
    });
  }
  for (final phase in ['members', 'group', 'direct']) {
    test('account change during $phase stops subsequent send work', () async {
      final pending = Completer<http.Response>();
      final paths = <String>[];
      useApiFixture(MockClient((r) async {
        paths.add(r.url.path);
        if (r.url.path.endsWith('/members')) {
          if (phase == 'members') return pending.future;
          return http.Response('[]', 200);
        }
        return pending.future;
      }));
      final auth = ShareAuth();
      final s = MediaShareSession(auth);
      addTearDown(auth.dispose);
      addTearDown(s.dispose);
      final result = phase == 'direct'
          ? s.shareDirect(movie: movie, friend: friend, message: 'Hello')
          : s.shareGroup(movie: movie, group: group, message: 'Hello');
      final check = expectLater(result, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      auth.change(null);
      pending.complete(http.Response(
          phase == 'members' ? '[]' : '{"id":"conversation"}', 200));
      await check;
      expect(paths.any((p) => p.endsWith('/messages')), false);
      if (phase == 'members') expect(paths.length, 1);
    });
  }
  for (final isShow in [false, true]) {
    test(
        'successful ${isShow ? 'show' : 'movie'} send retains payload and accepted group members',
        () async {
      final requests = <http.Request>[];
      useApiFixture(MockClient((r) async {
        requests.add(r);
        if (r.method == 'GET') {
          return http.Response(
              '[{"memberId":"accepted","inviteStatus":"ACCEPTED"},{"memberId":"pending","inviteStatus":"PENDING"}]',
              200);
        }
        return http.Response('{"id":"conversation"}', 200);
      }));
      final auth = ShareAuth();
      final s = MediaShareSession(auth);
      addTearDown(auth.dispose);
      addTearDown(s.dispose);
      final media = ChatShareMedia(
          id: 123,
          title: movie.title,
          posterPath: movie.posterPath,
          isShow: isShow);
      await s.shareGroup(movie: media, group: group, message: 'Watch this!');
      expect(jsonDecode(requests[1].body)['memberIds'],
          ['accepted', 'fixture-viewer']);
      final sent = jsonDecode(requests.last.body);
      final parsed = parseMovieSharePayload(sent['text'])!;
      expect(parsed.isShow, isShow);
      expect(parsed.title, movie.title);
      expect(parsed.prompt, 'Watch this!');
      expect(parsed.link,
          'flixie://${isShow ? 'shows' : 'movies'}/123?source=share');
      await s.shareDirect(movie: media, friend: friend, message: '');
      expect(jsonDecode(requests[requests.length - 2].body)['otherUserId'],
          'friend-0');
      expect(
          parseMovieSharePayload(jsonDecode(requests.last.body)['text'])!
              .prompt,
          'You should watch this.');
    });
  }
  test('disposed flow rejects new work', () async {
    final auth = ShareAuth();
    addTearDown(auth.dispose);
    final s = MediaShareSession(auth)..dispose();
    await expectLater(s.loadFriends(), throwsStateError);
  });
}
