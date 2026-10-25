import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/features/watchlist/data/guest_watchlist_store.dart';
import 'package:flixie_app/features/authentication/data/setup_service.dart';

class RejectingPreferences extends InMemorySharedPreferencesStore {
  RejectingPreferences(super.data) : super.withData();
  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const alien = SetupTitle(348, 'Alien', '/alien.jpg');
  const show = SetupTitle(348, 'A show', '/show.jpg', isShow: true);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('picks survive store recreation, distinguish movie/show, and remove',
      () async {
    final store = GuestWatchlistStore();
    await store.toggle(alien);
    await store.toggle(show);
    expect((await GuestWatchlistStore().read()).map((p) => p.key),
        ['movie:348', 'show:348']);
    expect(await store.toggle(alien), false);
    expect((await store.read()).single.name, 'A show');
  });
  test('partial save retains unacknowledged picks for retry', () async {
    final store = GuestWatchlistStore();
    await store.toggle(alien);
    await store.toggle(show);
    final saved = <String>[];
    await expectLater(
        store.merge(
            active: () => true,
            save: (p) async {
              if (p.isShow) throw StateError('offline');
              saved.add(p.key);
            }),
        throwsStateError);
    expect((await store.read()).single.key, show.key);
    await store.merge(active: () => true, save: (p) async => saved.add(p.key));
    expect(await store.read(), isEmpty);
    expect(saved, [alien.key, show.key]);
  });
  test('account switch retains pick even after late successful response',
      () async {
    final store = GuestWatchlistStore();
    await store.toggle(alien);
    var active = true;
    await expectLater(
        store.merge(
            active: () => active,
            save: (_) async {
              active = false;
            }),
        throwsStateError);
    expect((await store.read()).single.key, alien.key);
  });
  test('cancelled signup never changes durable picks', () async {
    final store = GuestWatchlistStore();
    await store.toggle(alien);
    expect((await GuestWatchlistStore().read()).single.key, alien.key);
  });
  test('concurrent additions are serialized without losing a pick', () async {
    final store = GuestWatchlistStore();
    await Future.wait([store.toggle(alien), store.toggle(show)]);
    expect(await store.read(), hasLength(2));
  });
  test('failed disk removal preserves pick in the preferences cache', () async {
    final store = GuestWatchlistStore();
    await store.toggle(alien);
    final prefs = await SharedPreferences.getInstance();
    final platform = SharedPreferencesStorePlatform.instance;
    SharedPreferencesStorePlatform.instance = RejectingPreferences({
      'flutter.${GuestWatchlistStore.storageKey}':
          prefs.getString(GuestWatchlistStore.storageKey)!,
    });
    addTearDown(() => SharedPreferencesStorePlatform.instance = platform);
    await expectLater(store.remove(alien.key), throwsStateError);
    expect((await store.read()).single.key, alien.key);
  });
  test('repeated remove cannot add a title back', () async {
    final store = GuestWatchlistStore();
    await store.toggle(alien);
    await Future.wait([store.remove(alien.key), store.remove(alien.key)]);
    expect(await store.read(), isEmpty);
  });
}
