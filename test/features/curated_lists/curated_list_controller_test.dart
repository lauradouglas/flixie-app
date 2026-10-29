import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/curated_lists/models/curated_list.dart';
import 'package:flixie_app/features/curated_lists/presentation/controllers/curated_list_controller.dart';
import 'package:flixie_app/features/pip/models/pip_collection.dart';
import 'curated_list_fixtures.dart';

void main() {
  test(
      'joins explicitly, reconciles distinct-film target and offers completion once',
      () async {
    final service = CuratedFixtureService();
    final c = CuratedListController(
        id: fixtureId, currentUserId: () => 'viewer', service: service);
    addTearDown(c.dispose);
    await c.load();
    expect(c.progress!.joined, false);
    expect(service.reconciles, 0);
    await c.join();
    expect(service.joins, 1);
    expect(c.progress!.joined, true);
    service.watched.addAll([71, 71]);
    await c.refreshProgress();
    expect(c.progress!.watched, 1);
    expect(c.takeCompletion(), true);
    expect(c.takeCompletion(), false);
    await c.load();
    expect(c.takeCompletion(), false);
  });
  test(
      'ignores an old account progress response and keeps guest browsing public',
      () async {
    String? owner = 'a';
    final service = CuratedFixtureService();
    final gate = Completer<CuratedProgress>();
    service.pendingProgress = gate;
    final c = CuratedListController(
        id: fixtureId, currentUserId: () => owner, service: service);
    addTearDown(c.dispose);
    final old = c.load();
    await Future<void>.delayed(Duration.zero);
    owner = 'b';
    c.resetOwner();
    await c.load();
    gate.complete(const CuratedProgress(watched: 2, required: 1, joined: true));
    await old;
    expect(c.progress!.watched, 0);
    owner = null;
    c.resetOwner();
    await c.load();
    expect(c.list!.title, isNotEmpty);
    expect(c.progress, isNull);
  });
  test('retains saved progress on refresh failure and recovers by retry',
      () async {
    final service = CuratedFixtureService()..joined = true;
    final c = CuratedListController(
        id: fixtureId, currentUserId: () => 'viewer', service: service);
    addTearDown(c.dispose);
    await c.load();
    service.watched.add(71);
    service.failProgress = true;
    await c.refreshProgress();
    expect(c.error, isNotNull);
    expect(c.progress!.completedAt, isNull);
    service.failProgress = false;
    await c.load();
    expect(c.progress!.completedAt, isNotNull);
    expect(c.takeCompletion(), true);
  });
  test('seasonal Pip choices require the specific unlock and survive caching',
      () {
    expect(PipCollection.fromJson({'activePip': 'christmasLights'}).activePip,
        'classic');
    final owned = PipCollection.fromJson({
      'activePip': 'christmasLights',
      'unlockedPips': [
        {'key': 'christmasLights'}
      ]
    });
    expect(owned.owns('christmasLights'), true);
    expect(PipCollection.fromJson(owned.toJson()).activePip, 'christmasLights');
    expect(PipCollection.asset('christmasLights'),
        contains('christmas_lights.png'));
  });
  test('UK calendar labels retain seasonal dates through daylight saving', () {
    final list = CuratedList(
        id: 'date',
        title: 'October',
        startsAt: DateTime.parse('2026-09-30T23:00:00Z'),
        endsAt: DateTime.parse('2026-11-01T00:00:00Z'));
    expect(list.dates, '1 Oct – 31 Oct');
  });
}
