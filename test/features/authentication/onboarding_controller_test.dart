import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/authentication/data/setup_service.dart';
import 'package:flixie_app/features/authentication/presentation/controllers/onboarding_controller.dart';
import 'package:flixie_app/models/watch_provider.dart';
import '../../setup_flow_test.dart' show SetupFixture;

class _Fixture extends SetupFixture {
  final searches = <String>[];
  final searchGates = <String, Completer<List<SetupTitle>>>{};
  final offerGates = <Completer<List<WatchProvider>>>[];
  final offerCalls = <int>[];
  Completer<void>? addGate;
  Completer<void>? tasteGate;
  Completer<List<SetupTitle>>? loadGate;
  int saveCalls = 0;
  int addCalls = 0;
  @override
  Future<List<SetupTitle>> search(String query, bool shows) {
    searches.add('$query:$shows');
    return (searchGates[query] ??= Completer()).future;
  }

  @override
  Future<List<SetupTitle>> loadTaste(String id) async =>
      loadGate == null ? [] : await loadGate!.future;
  @override
  Future<void> saveTaste(
      String id, List<SetupTitle> titles, Set<int> genres) async {
    saveCalls++;
    await tasteGate?.future;
    await super.saveTaste(id, titles, genres);
  }

  @override
  Future<void> addToWatchlist(String id, SetupTitle title) async {
    addCalls++;
    await addGate?.future;
    await super.addToWatchlist(id, title);
  }

  @override
  Future<List<SetupTitle>> recommendations(List<SetupTitle> seeds) async =>
      List.generate(6, (i) => SetupTitle(i, 'Pick $i', null));
  @override
  Future<List<WatchProvider>> availability(SetupTitle title, String region) {
    offerCalls.add(title.id);
    final gate = Completer<List<WatchProvider>>();
    offerGates.add(gate);
    return gate.future;
  }
}

void main() {
  OnboardingController make(_Fixture f, {bool Function()? current}) =>
      OnboardingController(
          service: f,
          userId: 'viewer',
          countryId: 1,
          isCurrentUser: current ?? () => true);
  testWidgets('mode change cancels the pending search debounce', (t) async {
    final f = _Fixture();
    final c = make(f);
    addTearDown(c.dispose);
    c.changeQuery('Alien');
    c.changeMode(true);
    expect(f.searches, ['Alien:true']);
    f.searchGates['Alien']!
        .complete([const SetupTitle(1, 'Alien show', null, isShow: true)]);
    await t.pump(const Duration(milliseconds: 500));
    expect(f.searches, ['Alien:true']);
    expect(c.browse.single.isShow, isTrue);
  });
  testWidgets('older search completion cannot replace a newer query',
      (t) async {
    final f = _Fixture();
    final c = make(f);
    addTearDown(c.dispose);
    c.changeQuery('old');
    await t.pump(const Duration(milliseconds: 350));
    c.changeQuery('new');
    await t.pump(const Duration(milliseconds: 350));
    f.searchGates['new']!.complete([const SetupTitle(2, 'New', null)]);
    await t.pump();
    f.searchGates['old']!.complete([const SetupTitle(1, 'Old', null)]);
    await t.pump();
    expect(c.browse.single.name, 'New');
    expect(c.searching, isFalse);
  });
  testWidgets('leaving taste cancels a scheduled query', (t) async {
    final f = _Fixture();
    final c = make(f);
    addTearDown(c.dispose);
    c.changeQuery('Alien');
    c.move(1);
    await t.pump(const Duration(milliseconds: 500));
    expect(f.searches, isEmpty);
    expect(c.step, 1);
  });
  testWidgets('disposed controller cancels a scheduled query', (t) async {
    final f = _Fixture();
    final c = make(f);
    c.changeQuery('Alien');
    c.dispose();
    await t.pump(const Duration(milliseconds: 500));
    expect(f.searches, isEmpty);
  });
  test('account change rejects pending saved taste', () async {
    var current = true;
    final f = _Fixture()..loadGate = Completer();
    final c = make(f, current: () => current);
    addTearDown(c.dispose);
    final load = c.load();
    await Future<void>.delayed(Duration.zero);
    current = false;
    f.loadGate!.complete([const SetupTitle(1, 'Other account', null)]);
    await load;
    expect(c.taste, isEmpty);
  });
  test('duplicate save tap persists once and advances after completion',
      () async {
    final f = _Fixture()..tasteGate = Completer();
    final c = make(f);
    addTearDown(c.dispose);
    c.toggleTaste(const SetupTitle(348, 'Alien', null));
    final save = c.saveTaste();
    await c.saveTaste();
    expect(f.saveCalls, 1);
    expect(c.step, 0);
    f.tasteGate!.complete();
    await save;
    expect(c.step, 1);
    expect(f.taste.single.id, 348);
  });
  test('duplicate add shares pending outcome without a second write', () async {
    final f = _Fixture()..addGate = Completer();
    final c = make(f);
    addTearDown(c.dispose);
    const title = SetupTitle(348, 'Alien', null);
    final add = c.add(title);
    expect(await c.add(title), isFalse);
    expect(f.addCalls, 1);
    f.addGate!.complete();
    expect(await add, isTrue);
    expect(c.added, contains('movie:348'));
    expect(await c.add(title), isFalse);
    expect(f.addCalls, 1);
  });
  test('availability stops after current batch when leaving picks', () async {
    final f = _Fixture();
    final c = make(f);
    addTearDown(c.dispose);
    await c.load();
    final load = c.loadPicks();
    await Future<void>.delayed(Duration.zero);
    expect(f.offerCalls, [0, 1, 2]);
    c.move(3);
    for (final gate in f.offerGates) {
      gate.complete([]);
    }
    await load;
    expect(f.offerCalls, [0, 1, 2]);
    expect(c.searching, isFalse);
  });
  test('disposed availability work does not start another batch', () async {
    final f = _Fixture();
    final c = make(f);
    await c.load();
    final load = c.loadPicks();
    await Future<void>.delayed(Duration.zero);
    c.dispose();
    for (final gate in f.offerGates) {
      gate.complete([]);
    }
    await load;
    expect(f.offerCalls, [0, 1, 2]);
  });
  test('taste limit, skip and read-only selections preserve private intent',
      () async {
    final f = _Fixture();
    final c = make(f);
    addTearDown(c.dispose);
    for (var i = 0; i < 3; i++) {
      expect(c.toggleTaste(SetupTitle(i, 'Title $i', null)), isTrue);
    }
    expect(c.toggleTaste(const SetupTitle(4, 'Fourth', null)), isFalse);
    expect(() => c.taste.clear(), throwsUnsupportedError);
    await c.saveTaste(skip: true);
    expect(f.taste, isEmpty);
    expect(c.taste, isEmpty);
    expect(c.step, 1);
  });
  test('late saved taste cannot overwrite choices made while loading',
      () async {
    final f = _Fixture()..loadGate = Completer();
    final c = make(f);
    addTearDown(c.dispose);
    final load = c.load();
    await Future<void>.delayed(Duration.zero);
    c.toggleTaste(const SetupTitle(348, 'Alien', null));
    f.loadGate!.complete([const SetupTitle(99, 'Previously saved', null)]);
    await load;
    expect(c.taste.keys, ['movie:348']);
  });
  test('account change during a save does not advance the old flow', () async {
    var current = true;
    final f = _Fixture()..tasteGate = Completer();
    final c = make(f, current: () => current);
    addTearDown(c.dispose);
    final save = c.saveTaste();
    current = false;
    f.tasteGate!.complete();
    await save;
    expect(c.step, 0);
  });
}
