import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/features/authentication/data/setup_service.dart';
import 'package:flixie_app/features/taste/data/taste_service.dart';
import 'package:flixie_app/features/taste/data/taste_setup_store.dart';
import 'package:flixie_app/features/taste/presentation/controllers/taste_controller.dart';

class TasteFixture extends TasteService {
  Set<int> saved = {};
  bool fail = false;
  final calls = <String>[];
  Completer<void>? gate;
  @override
  Future<List<SetupTitle>> titles(String q) async => const [
        SetupTitle(348, 'Alien', null),
        SetupTitle(157336, 'Interstellar', null)
      ];
  @override
  Future<Set<int>> favourites(String id) async => Set.of(saved);
  @override
  Future<void> favourite(String id, SetupTitle title, bool add) async {
    if (gate != null) await gate!.future;
    if (fail) throw StateError('offline');
    calls.add('$id:${title.id}:$add');
    if (add) {
      saved.add(title.id);
    } else {
      saved.remove(title.id);
    }
  }

  @override
  Future<({int? rating, bool? recommended})> rating(
          String id, int movie) async =>
      (rating: 7, recommended: false);
  @override
  Future<void> rate(
      String id, int movie, int score, String? recommendation) async {
    if (fail) throw StateError('offline');
    calls.add('$id:$movie:$score:$recommendation');
  }

  @override
  void invalidate(String id) {
    calls.add('invalidate:$id');
  }
}

class SearchTasteFixture extends TasteFixture {
  final requests = <String, Completer<List<SetupTitle>>>{};
  @override
  Future<List<SetupTitle>> titles(String query) {
    if (query.isEmpty) return super.titles(query);
    return (requests[query] = Completer<List<SetupTitle>>()).future;
  }
}

class SlowProgressStore extends TasteSetupStore {
  final gate = Completer<void>();
  @override
  Future<void> saveStep(String id, String step) => gate.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('account scoped dismissal and resume do not affect another account',
      () async {
    const store = TasteSetupStore();
    await store.enable('a');
    await store.hide('a');
    await store.saveStep('a', 'rating');
    expect(await store.eligible('a'), true);
    expect(await store.hidden('a'), true);
    expect(await store.hidden('b'), false);
    expect(await store.eligible('b'), false);
    expect(await store.step('a'), 'rating');
    expect(await store.step('b'), 'favourites');
  });
  test(
      'favourites persist before success, remove explicitly, and retry failure',
      () async {
    final service = TasteFixture();
    var changed = 0;
    final c = TasteController(
        userId: 'a',
        isCurrent: () => true,
        service: service,
        onSaved: () => changed++);
    await c.load();
    service.fail = true;
    await c.toggle(c.titles.first);
    expect(c.favourites, isEmpty);
    expect(changed, 0);
    expect(c.error, isNotNull);
    service.fail = false;
    await c.toggle(c.titles.first);
    expect(c.favourites, {348});
    expect(changed, 1);
    await c.toggle(c.titles.first);
    expect(c.favourites, isEmpty);
    expect(changed, 2);
    c.dispose();
  });
  test('loads an existing rating and only publishes summary after a real save',
      () async {
    final service = TasteFixture();
    final c = TasteController(
        userId: 'a', isCurrent: () => true, service: service, onSaved: () {});
    await c.load();
    await c.move('rating');
    await c.choose(c.titles.first);
    expect(c.initialRating, 7);
    expect(c.initialRecommendation, 'avoid');
    service.fail = true;
    await expectLater(c.rate(3, 'avoid'), throwsStateError);
    expect(c.step, 'rating');
    expect(c.ratings, isEmpty);
    service.fail = false;
    await c.rate(3, 'avoid');
    expect(c.step, 'summary');
    expect(c.ratings[348]!.score, 3);
    expect(service.calls, contains('a:348:3:avoid'));
    c.dispose();
  });
  test('late save after account switch cannot update new account UI', () async {
    var active = true;
    var changed = 0;
    final service = TasteFixture()..gate = Completer<void>();
    final c = TasteController(
        userId: 'a',
        isCurrent: () => active,
        service: service,
        onSaved: () => changed++);
    await c.load();
    final save = c.toggle(c.titles.first);
    active = false;
    service.gate!.complete();
    await save;
    expect(c.favourites, isEmpty);
    expect(changed, 0);
    c.dispose();
  });
  test(
      'existing ten favourites prevent an eleventh while removal stays available',
      () async {
    final service = TasteFixture()..saved = {for (var i = 1; i <= 10; i++) i};
    final c = TasteController(
        userId: 'a', isCurrent: () => true, service: service, onSaved: () {});
    await c.load();
    await c.toggle(c.titles.first);
    expect(service.calls, isEmpty);
    expect(c.error, contains('ten'));
    await c.toggle(const SetupTitle(1, 'Existing', null));
    expect(c.favourites, hasLength(9));
    c.dispose();
  });
  test(
      'skip both steps writes no ratings or favourites and leaves Profile resume',
      () async {
    final service = TasteFixture();
    final c = TasteController(
        userId: 'a', isCurrent: () => true, service: service, onSaved: () {});
    await c.load();
    await c.move('rating');
    await c.move('summary');
    await c.dismiss();
    expect(service.calls, isEmpty);
    expect(await c.store.hidden('a'), true);
    expect(await c.store.step('a'), 'summary');
    c.dispose();
  });
  test('new search results win over a slower earlier query', () async {
    final service = SearchTasteFixture();
    final c = TasteController(
        userId: 'a', isCurrent: () => true, service: service, onSaved: () {});
    await c.load();
    final earlier = c.search('Alien');
    final later = c.search('Interstellar');
    service.requests['Interstellar']!
        .complete([const SetupTitle(157336, 'Interstellar', null)]);
    await later;
    service.requests['Alien']!.complete([const SetupTitle(348, 'Alien', null)]);
    await earlier;
    expect(c.titles.single.id, 157336);
    c.dispose();
  });
  test('double tapping a favourite does not issue two in-flight writes',
      () async {
    final service = TasteFixture()..gate = Completer<void>();
    var changes = 0;
    final c = TasteController(
        userId: 'a',
        isCurrent: () => true,
        service: service,
        onSaved: () => changes++);
    await c.load();
    final first = c.toggle(c.titles.first);
    final second = c.toggle(c.titles.first);
    service.gate!.complete();
    await Future.wait([first, second]);
    expect(changes, 1);
    expect(service.calls.where((s) => s == 'a:348:true'), hasLength(1));
    c.dispose();
  });
  test('typing immediately after changing step survives a slow progress write',
      () async {
    final service = SearchTasteFixture();
    final store = SlowProgressStore();
    final c = TasteController(
        userId: 'a',
        isCurrent: () => true,
        service: service,
        store: store,
        onSaved: () {});
    await c.load();
    final moving = c.move('rating');
    final query = c.search('Interstellar');
    service.requests['Interstellar']!
        .complete([const SetupTitle(157336, 'Interstellar', null)]);
    await query;
    store.gate.complete();
    await moving;
    expect(c.titles.map((t) => t.id), [157336]);
    c.dispose();
  });
}
