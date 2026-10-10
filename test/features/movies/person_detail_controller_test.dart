import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/person.dart';
import 'package:flixie_app/features/movies/data/person_detail_service.dart';
import 'package:flixie_app/features/movies/presentation/controllers/person_detail_controller.dart';
import '../../../patrol_test/support/person_detail_fixture.dart';

class _Service extends PersonDetailService {
  int reads = 0, imageReads = 0;
  final writes = <String>[];
  Future<(Person, PersonCredits)> Function(int)? detail;
  Future<List<PersonImage>> Function(int)? photo;
  Future<void> Function()? write;
  @override
  Future<(Person, PersonCredits)> details(int id) {
    reads++;
    return detail?.call(id) ?? Future.value(_data(id));
  }

  @override
  Future<List<PersonImage>> images(int id) {
    imageReads++;
    return photo?.call(id) ?? Future.value([]);
  }

  @override
  Future<void> setFavorite(int id, String viewerId,
      {required bool favorite}) async {
    writes.add('$viewerId:$id:$favorite');
    await write?.call();
  }
}

(Person, PersonCredits) _data(int id) => (
      Person.fromJson(personFixtureData(id)),
      PersonCredits.fromJson(personFixtureCredits())
    );
Future<void> _flush() => Future<void>.delayed(Duration.zero);
void main() {
  test(
      'public data loads in parallel boundary; merged credits are retained once',
      () async {
    final service = _Service();
    final c = PersonDetailController(
        personId: '42', service: service, viewer: personFixtureViewer('one'));
    addTearDown(c.dispose);
    await c.load();
    await _flush();
    expect(c.person?.name, 'Casey Fixture 42');
    expect(c.allCredits.length, 25);
    expect(c.allCredits.where((v) => v.id == 1).length, 2);
    expect(service.reads, 1);
    expect(service.imageReads, 1);
    final projection = c.allCredits;
    c.selectViewer(personFixtureViewer('two'));
    expect(identical(c.allCredits, projection), isTrue);
    expect(service.reads, 1);
    expect(c.library.watched, {1});
    expect(c.library.watchlist, {2});
    expect(() => c.allCredits.clear(), throwsUnsupportedError);
  });
  for (final id in ['bad', '0', '-1']) {
    test('invalid person $id performs no reads or writes', () async {
      final service = _Service();
      final c = PersonDetailController(
          personId: id, service: service, viewer: personFixtureViewer('one'));
      addTearDown(c.dispose);
      await c.load();
      expect(await c.toggleFavorite(), isNull);
      expect(c.error, 'Invalid person ID.');
      expect(c.loading, isFalse);
      expect(service.reads, 0);
      expect(service.writes, isEmpty);
    });
  }
  test(
      'Retry clears failure and loads content; images failure retains bundled photos',
      () async {
    final service = _Service()
      ..detail = (_) async => throw StateError('offline');
    final c = PersonDetailController(personId: '42', service: service);
    addTearDown(c.dispose);
    await c.load();
    expect(c.error, contains('offline'));
    expect(c.loading, isFalse);
    service.detail = (id) async => (
          Person(
              id: id,
              name: 'Recovered',
              images: const [PersonImage(personId: 42, imageUrl: '/bundled')]),
          _data(id).$2
        );
    service.photo = (_) async => throw StateError('images offline');
    await c.load();
    await _flush();
    expect(c.error, isNull);
    expect(c.person?.name, 'Recovered');
    expect(c.images.single.imageUrl, '/bundled');
    expect(c.imagesLoading, isFalse);
  });
  test('new load wins over late core and image results', () async {
    final first = Completer<(Person, PersonCredits)>();
    final service = _Service();
    service.detail =
        (id) => service.reads == 1 ? first.future : Future.value(_data(43));
    final c = PersonDetailController(personId: '42', service: service);
    addTearDown(c.dispose);
    final old = c.load();
    await c.load();
    first.complete(_data(42));
    await old;
    await _flush();
    expect(c.person?.id, 43);
    expect(service.imageReads, 1);
    final photos = Completer<List<PersonImage>>();
    service.photo = (_) => service.imageReads == 2
        ? photos.future
        : Future.value([const PersonImage(personId: 43, imageUrl: '/new')]);
    await c.load();
    await c.load();
    await _flush();
    photos.complete([const PersonImage(personId: 42, imageUrl: '/old')]);
    await _flush();
    expect(c.images.single.imageUrl, '/new');
  });
  test('viewer switch during public load uses new account without refetch',
      () async {
    final held = Completer<(Person, PersonCredits)>();
    final service = _Service()..detail = (_) => held.future;
    final c = PersonDetailController(
        personId: '42', service: service, viewer: personFixtureViewer('one'));
    addTearDown(c.dispose);
    final load = c.load();
    c.selectViewer(personFixtureViewer('two', favorites: [42]));
    held.complete(_data(42));
    await load;
    expect(c.viewerId, 'two');
    expect(c.favorite, isTrue);
    expect(service.reads, 1);
  });
  test(
      'double favourite tap shares the busy guard and successful change preserves edits',
      () async {
    final held = Completer<void>();
    final service = _Service()..write = () => held.future;
    final c = PersonDetailController(
        personId: '42', service: service, viewer: personFixtureViewer('one'));
    addTearDown(c.dispose);
    final save = c.toggleFavorite();
    expect(await c.toggleFavorite(), isNull);
    expect(service.writes, ['one:42:true']);
    held.complete();
    final change = await save;
    expect(change?.favorite, isTrue);
    expect(c.favorite, isTrue);
    expect(c.saving, isFalse);
    expect(
        change!.applyTo([
          99,
          {'id': 42},
          42
        ]),
        [99, 42]);
    final remove = await c.toggleFavorite();
    expect(
        remove!.applyTo([
          99,
          {'personId': 42},
          42
        ]),
        [99]);
  });
  test('failed favourite leaves local state unchanged and allows retry',
      () async {
    final service = _Service()
      ..write = () async => throw StateError('save failed');
    final c = PersonDetailController(
        personId: '42', service: service, viewer: personFixtureViewer('one'));
    addTearDown(c.dispose);
    await expectLater(c.toggleFavorite(), throwsStateError);
    expect(c.favorite, isFalse);
    expect(c.saving, isFalse);
    service.write = () async {};
    expect((await c.toggleFavorite())?.favorite, isTrue);
  });
  test('old account write cannot publish or clear the new account busy state',
      () async {
    final oldGate = Completer<void>();
    final newGate = Completer<void>();
    final service = _Service();
    service.write =
        () => service.writes.length == 1 ? oldGate.future : newGate.future;
    final c = PersonDetailController(
        personId: '42', service: service, viewer: personFixtureViewer('one'));
    addTearDown(c.dispose);
    final old = c.toggleFavorite();
    c.selectViewer(personFixtureViewer('two'));
    final next = c.toggleFavorite();
    oldGate.complete();
    expect(await old, isNull);
    expect(c.saving, isTrue);
    newGate.complete();
    final result = await next;
    expect(result?.viewerId, 'two');
    expect(c.favorite, isTrue);
  });
  test('disposed core/image/save work cannot notify or publish', () async {
    for (final phase in ['core', 'images', 'save']) {
      final details = Completer<(Person, PersonCredits)>();
      final images = Completer<List<PersonImage>>();
      final write = Completer<void>();
      final service = _Service();
      service.detail = (_) => details.future;
      service.photo = (_) => images.future;
      service.write = () => write.future;
      final c = PersonDetailController(
          personId: '42', service: service, viewer: personFixtureViewer('one'));
      final load = c.load();
      if (phase != 'core') {
        details.complete(_data(42));
        await load;
      }
      final save = phase == 'save' ? c.toggleFavorite() : null;
      var notifications = 0;
      c.addListener(() => notifications++);
      c.dispose();
      if (!details.isCompleted) details.complete(_data(42));
      images.complete([]);
      write.complete();
      await load;
      await _flush();
      if (save != null) expect(await save, isNull);
      expect(notifications, 0);
    }
  });
}
