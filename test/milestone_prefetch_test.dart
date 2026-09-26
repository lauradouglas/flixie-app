import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/profile/data/milestone_cache.dart';
import 'package:flixie_app/features/profile/presentation/pages/milestones_screen.dart';
import 'home_startup_recovery_test.dart' show Session;
import 'auth_recovery_test.dart' show Prefetch, profile;

http.Response result() =>
    http.Response('{"visibility":"owner","items":[]}', 200);
void main() {
  setUp(() => MilestoneCache.instance.clear());
  tearDown(() {
    MilestoneCache.instance.clear();
    ApiClient.useClientForTesting(null);
  });
  testWidgets(
      'boot proceeds before milestones finish and page reuses warm result',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final pending = Completer<http.Response>();
    var calls = 0;
    ApiClient.useClientForTesting(MockClient((request) {
      calls++;
      return pending.future;
    }));
    final session = Session();
    final auth = AuthProvider(session, MovieService(),
        prefetchCoordinator: Prefetch(),
        profileLoader: (id) async => profile(id),
        termsStatusLoader: () async => true);
    session.events.add(session.identity);
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(auth.status, AuthStatus.authenticated);
    expect(auth.isPrefetching, isFalse);
    expect(calls, 1);
    expect(pending.isCompleted, isFalse);
    pending.complete(result());
    await tester.pump();
    await tester.pumpWidget(
        MaterialApp(home: MilestonesScreen(userId: session.identity.uid)));
    await tester.pumpAndSettle();
    expect(find.text('Your story so far'), findsOneWidget);
    expect(calls, 1);
    auth.markActivityChanged();
    expect(MilestoneCache.instance.peek(session.identity.uid), isNull);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
    await session.events.close();
  });
  test('in-flight reuse, forced refresh and invalidation', () async {
    final cache = MilestoneCache();
    final pending = Completer<http.Response>();
    var calls = 0;
    ApiClient.useClientForTesting(MockClient((_) {
      calls++;
      return calls == 1 ? pending.future : Future.value(result());
    }));
    final warm = cache.warm('owner');
    final open = cache.load('owner');
    pending.complete(result());
    await warm;
    await open;
    expect(calls, 1);
    await cache.load('owner');
    expect(calls, 1);
    await cache.load('owner', refresh: true);
    expect(calls, 2);
    cache.invalidate();
    await cache.load('owner');
    expect(calls, 3);
  });
  test('logout and account switching discard late responses', () async {
    final cache = MilestoneCache();
    final first = Completer<http.Response>();
    ApiClient.useClientForTesting(MockClient((r) =>
        r.url.path.contains('/first/')
            ? first.future
            : Future.value(result())));
    final old = cache.warm('first');
    cache.clear();
    await cache.warm('second');
    first.complete(result());
    await old;
    expect(cache.peek('first'), isNull);
    expect(cache.peek('second'), isNotNull);
    cache.clear();
    expect(cache.peek('second'), isNull);
  });
  test('background failures are silent and opening retries', () async {
    final cache = MilestoneCache();
    var calls = 0;
    ApiClient.useClientForTesting(MockClient(
        (_) async => ++calls == 1 ? http.Response('{}', 400) : result()));
    await cache.warm('owner');
    expect(cache.peek('owner'), isNull);
    await cache.load('owner');
    expect(calls, 2);
    expect(cache.peek('owner'), isNotNull);
  });
}
