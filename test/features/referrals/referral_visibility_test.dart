import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/features/referrals/data/referral_prompt_store.dart';
import 'package:flixie_app/features/referrals/presentation/saved_film_invite_prompt.dart';
import 'package:flixie_app/features/referrals/presentation/social_invite_empty_state.dart';
import 'package:flixie_app/features/pip/presentation/controllers/pip_collection_controller.dart';
import 'package:flixie_app/features/pip/models/pip_collection.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import '../../support/api_fixture.dart';
import '../pip/pip_collection_test.dart' show FakePips;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
      'prompts are account-scoped, seven days apart, capped at three and concurrency-safe',
      () async {
    final now = DateTime(2026, 10, 25);
    expect(
        await Future.wait([
          ReferralPromptStore.reserve('casey', now: now),
          ReferralPromptStore.reserve('casey', now: now)
        ]),
        [true, false]);
    expect(
        await ReferralPromptStore.reserve('casey',
            now: now.add(const Duration(days: 6))),
        false);
    expect(await ReferralPromptStore.reserve('jamie', now: now), true);
    expect(
        await ReferralPromptStore.reserve('casey',
            now: now.add(const Duration(days: 7))),
        true);
    expect(
        await ReferralPromptStore.reserve('casey',
            now: now.add(const Duration(days: 14))),
        true);
    expect(
        await ReferralPromptStore.reserve('casey',
            now: now.add(const Duration(days: 30))),
        false);
  });
  testWidgets(
      'saved watch prompt retains companion on failure and retries existing entry',
      savedFilmInviteJourney);
  testWidgets('unlocked Cinema Club does not offer another promotion',
      (t) async {
    final c = PipCollectionController(service: FakePips());
    c.syncUser('casey', 0);
    await t.pumpAndSettle();
    bool? offered;
    await t.pumpWidget(ChangeNotifierProvider.value(
        value: c,
        child: MaterialApp(
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () async {
                          offered = await maybeOfferSavedFilmInvite(context,
                              entry: const MovieWatchEntry(
                                  id: 'watch',
                                  userId: 'casey',
                                  movieId: 348,
                                  removed: false),
                              title: 'Alien',
                              isCurrent: () => true);
                        },
                        child: const Text('Saved')))))));
    await t.tap(find.text('Saved'));
    await t.pumpAndSettle();
    expect(offered, false);
    await t.pumpWidget(const SizedBox.shrink());
    c.dispose();
  });
  testWidgets('Social invite opens the referral page', (t) async {
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: SocialInviteEmptyState())),
      GoRoute(
          path: '/invite-friend',
          builder: (_, state) => Scaffold(
              body: Text(
                  'Invite page from ${state.uri.queryParameters['from']}')))
    ]);
    addTearDown(router.dispose);
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.pumpAndSettle();
    expect(
        t.widgetList<Image>(find.byType(Image)).any((image) =>
            image.image is AssetImage &&
            (image.image as AssetImage).assetName.endsWith('cinema_club.png')),
        true);
    await t.tap(find.text('Invite a friend'));
    await t.pumpAndSettle();
    expect(find.text('Invite page from social-empty'), findsOneWidget);
  });

  testWidgets('Social invite empty state wraps at small phone double text',
      (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(const MaterialApp(
        home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
                body: SingleChildScrollView(
                    padding: EdgeInsets.all(24),
                    child: SocialInviteEmptyState())))));
    expect(find.text('Your film people belong here.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}

Future<void> savedFilmInviteJourney(WidgetTester t) async {
  SharedPreferences.setMockInitialValues({});
  final writes = <Map<String, dynamic>>[];
  var fail = true;
  useApiFixture(MockClient((r) async {
    if (r.url.path == '/watch-requests/log-watch') {
      final body = Map<String, dynamic>.from(jsonDecode(r.body));
      writes.add(body);
      if (fail) return http.Response('{"error":"Offline fixture"}', 503);
      return http.Response(
          jsonEncode({
            'id': 'saved-watch',
            'userId': 'casey',
            'movieId': 348,
            'rating': 8,
            'notes': 'Private note',
            'removed': false,
            'externalInvite': {'id': 'invite', 'displayName': 'Jamie'}
          }),
          200);
    }
    if (r.url.path == '/friends/casey') {
      return http.Response(
          '{"friendships":[],"pendingFriends":[],"requestedFriends":[]}', 200);
    }
    return http.Response('[]', 200);
  }));
  final c = PipCollectionController(
      service: FakePips()..value = const PipCollection());
  c.syncUser('casey', 0);
  await t.pumpAndSettle();
  const entry = MovieWatchEntry(
      id: 'saved-watch',
      userId: 'casey',
      movieId: 348,
      rating: 8,
      notes: 'Private note',
      removed: false);
  await t.pumpWidget(ChangeNotifierProvider.value(
      value: c,
      child: MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => maybeOfferSavedFilmInvite(context,
                          entry: entry, title: 'Alien', isCurrent: () => true),
                      child: const Text('Saved')))))));
  await t.tap(find.text('Saved'));
  await t.pumpAndSettle();
  expect(find.text('Watched Alien with someone?'), findsOneWidget);
  await t.tap(find.text('Add someone'));
  await t.pumpAndSettle();
  await t.enterText(find.byType(TextField), 'Jamie');
  await t.pump();
  await t.tap(find.text('Add to my watch'));
  await t.pumpAndSettle();
  expect(find.textContaining('your choice is still here'), findsOneWidget);
  fail = false;
  await t.tap(find.text('Try again'));
  await t.pumpAndSettle();
  expect(writes, hasLength(2));
  expect(writes[0], writes[1]);
  expect(writes.last['watchEntryId'], 'saved-watch');
  expect(writes.last['externalCompanionName'], 'Jamie');
  expect(writes.last['notes'], 'Private note');
  expect(writes.last['rating'], 8);
  expect(find.text('Invite Jamie'), findsOneWidget);
  await t.pumpWidget(const SizedBox.shrink());
  c.dispose();
}
