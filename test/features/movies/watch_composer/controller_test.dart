import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/movies/presentation/controllers/watch_composer_controller.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'fixture.dart';

const alien = MovieShort(id: 348, name: 'Alien');
Future<void> settle() => Future<void>.delayed(Duration.zero);
WatchComposerController create(ComposerFixture api,
    {MovieShort? movie = alien}) {
  final c = WatchComposerController(
      requesterId: 'viewer', region: 'GB', service: api, movie: movie);
  addTearDown(c.dispose);
  c.start();
  return c;
}

void main() {
  test(
      'switching overlapping groups reuses user providers only within this sheet',
      () async {
    final api = ComposerFixture();
    final first = create(api);
    await settle();
    first.selectFriend('Robin');
    await settle();
    first.setGroupMode(true);
    first.selectGroup('Film friends');
    await settle();
    first.selectGroup('Alien fans');
    await settle();
    first.selectGroup('Film friends');
    await settle();
    expect(api.userReads, {'viewer': 1, 'Robin': 1, 'Ellis': 1, 'Blair': 1});
    expect(api.memberReads, 3);
    expect(first.providers.groupMemberCount, 3);
    expect(first.providers.groupCounts, {1: 2, 2: 1});
    first.dispose();
    final second = create(api);
    await settle();
    second.selectFriend('Robin');
    await settle();
    expect(api.userReads['viewer'], 2);
    expect(api.userReads['Robin'], 2);
  });
  test('late friend response cannot replace newer selection or group mode',
      () async {
    final api = ComposerFixture();
    final gate = Completer<List<WatchProvider>>();
    api.pendingUsers['Robin'] = gate;
    final c = create(api);
    await settle();
    c.selectFriend('Robin');
    c.selectFriend('Ellis');
    await settle();
    expect(c.providers.friendIds, {2});
    c.setGroupMode(true);
    gate.complete(ComposerFixture.offers(1));
    await settle();
    expect(c.providers.friendIds, isEmpty);
    expect(c.providers.loadingFriend, isFalse);
  });
  test('late group provider result cannot overwrite a newer group', () async {
    final api = ComposerFixture();
    final gate = Completer<List<WatchProvider>>();
    api.pendingUsers['Ellis'] = gate;
    final c = create(api);
    await settle();
    c.setGroupMode(true);
    c.selectGroup('Film friends');
    await settle();
    c.selectGroup('Alien fans');
    await settle();
    expect(c.providers.groupCounts, {1: 3});
    gate.complete(ComposerFixture.offers(2));
    await settle();
    expect(c.selectedGroupId, 'Alien fans');
    expect(c.providers.groupCounts, {1: 3});
    expect(c.providers.loadingGroup, isFalse);
  });
  test('closing while friends are loading cannot repopulate disposed state',
      () async {
    final api = ComposerFixture()..friendGate = Completer();
    final c = create(api);
    var changes = 0;
    c.addListener(() => changes++);
    await settle();
    c.dispose();
    final previous = changes;
    api.friendGate!.complete([]);
    await settle();
    expect(changes, previous);
    expect(c.friends, isEmpty);
    expect(c.groups, isEmpty);
  });
  test('failed provider reads are evicted and retry on recipient re-selection',
      () async {
    final api = ComposerFixture()..failUsers.add('Robin');
    final c = create(api);
    await settle();
    c.selectFriend('Robin');
    await settle();
    expect(c.providers.friendIds, isEmpty);
    c.selectFriend('Robin');
    await settle();
    expect(c.providers.friendIds, {1});
    expect(api.userReads['Robin'], 2);
  });
  test('in-flight provider reads are shared between friend and group',
      () async {
    final api = ComposerFixture();
    final gate = Completer<List<WatchProvider>>();
    api.pendingUsers['Robin'] = gate;
    final c = create(api);
    await settle();
    c.selectFriend('Robin');
    c.setGroupMode(true);
    c.selectGroup('Film friends');
    await settle();
    expect(api.userReads['Robin'], 1);
    gate.complete(ComposerFixture.offers(1));
    await settle();
    expect(c.providers.groupCounts, {1: 2, 2: 1});
  });
  test(
      'blank composer loads own services and added/removed movies select correct availability',
      () async {
    final api = ComposerFixture();
    final draft = create(api, movie: null);
    await settle();
    expect(draft.providers.myIds, {1});
    draft.addMovieChoice(alien);
    await settle();
    draft.addMovieChoice(const MovieShort(id: 2, name: 'The Odyssey'));
    await settle();
    expect(draft.providers.forMovie(draft.selectedMovieId).single.id, 2);
    draft.removeMovieChoice(const MovieShort(id: 2, name: 'The Odyssey'));
    await settle();
    expect(draft.selectedMovieId, 348);
    expect(draft.providers.forMovie(draft.selectedMovieId).single.id, 1);
    draft.selectMovieChoice(alien);
    await settle();
    expect(api.movieReads, {348: 1, 2: 1});
  });
  test(
      'group to friend switch enforces three-film limit without silently removing choices',
      () async {
    final c = create(ComposerFixture());
    await settle();
    c.setGroupMode(true);
    c.selectGroup('Film friends');
    for (var i = 1; i < 5; i++) {
      c.addMovieChoice(MovieShort(id: i, name: 'Film $i'));
    }
    await settle();
    expect(c.movieChoices.length, 5);
    c.setGroupMode(false);
    c.selectFriend('Robin');
    await settle();
    expect(c.canSend, isFalse);
    expect(c.validationError, contains('up to 3'));
    for (final m in c.movieChoices.skip(3).toList()) {
      c.removeMovieChoice(m);
    }
    expect(c.canSend, isTrue);
  });
  test(
      'duplicate taps share one write and a confirmed submission cannot be sent again',
      () async {
    final api = ComposerFixture()..writeGate = Completer<String?>();
    final c = create(api);
    await settle();
    c.selectFriend('Robin');
    final first = c.send(' hello ');
    expect(await c.send('second'), isNull);
    c.selectFriend('Ellis');
    expect(c.selectedFriendId, 'Robin');
    expect(api.writes.length, 1);
    expect(api.writes.single['message'], 'hello');
    api.writeGate!.complete('saved');
    expect((await first)?.id, 'saved');
    expect(await c.send('again'), isNull);
  });
  test('failed send remains retryable and payload uses the current first movie',
      () async {
    final api = ComposerFixture()..failSend = true;
    final c = create(api);
    await settle();
    c.selectFriend('Robin');
    c.addMovieChoice(const MovieShort(id: 2, name: 'The Odyssey'));
    c.removeMovieChoice(alien);
    await expectLater(c.send('hi'), throwsStateError);
    expect(c.canSend, isTrue);
    expect((await c.send('hi'))?.movieId, 2);
    expect(api.writes.single['movies'], [2]);
  });
  test('date-only schedule preserves noon UTC and past schedule cannot send',
      () async {
    final api = ComposerFixture();
    final c = create(api);
    await settle();
    c.selectFriend('Robin');
    c.setSchedule(DateTime(2000, 1, 1), true);
    expect(c.canSend, isFalse);
    c.setSchedule(DateTime(2099, 7, 10), true);
    await c.send('date');
    expect(api.writes.single['proposedDate'], '2099-07-10T12:00:00.000Z');
    expect(api.writes.single['dateOnly'], true);
  });
  test('disposal rejects delayed reads and write completion', () async {
    final api = ComposerFixture()..writeGate = Completer<String?>();
    final c = create(api);
    await settle();
    c.selectFriend('Robin');
    final result = c.send('hi');
    c.dispose();
    api.writeGate!.complete('saved');
    expect(await result, isNull);
    expect(c.friends, isEmpty);
    expect(c.movieChoices, isEmpty);
    expect(c.providers.myIds, isEmpty);
  });
  test('friend/group failure is explicit and retry loads recipients', () async {
    final api = ComposerFixture()
      ..failFriends = true
      ..failGroups = true;
    final c = create(api);
    await settle();
    expect(c.friendsLoadFailed, isTrue);
    expect(c.groupsLoadFailed, isTrue);
    api.failFriends = false;
    api.failGroups = false;
    await c.fetchFriends();
    await c.fetchGroups();
    expect(c.friends.length, 2);
    expect(c.groups.length, 2);
    expect(c.friendsLoadFailed, isFalse);
    expect(c.groupsLoadFailed, isFalse);
  });
}
