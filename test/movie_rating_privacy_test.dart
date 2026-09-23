import 'package:flixie_app/features/social/presentation/widgets/chat_bubble.dart';
import 'package:flixie_app/features/social/presentation/utils/activity_reply_payload.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'package:flixie_app/features/settings/presentation/widgets/movie_rating_privacy_setting.dart';
import 'package:flixie_app/core/widgets/movie_search_result_tile.dart';
import 'package:flixie_app/models/movie_short.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('opt in persists per account; only rated movies and own scores unlock',
      () async {
    final privacy = MovieRatingPrivacy(loadRatings: (_) async => {12});
    addTearDown(privacy.dispose);
    privacy.syncUser('alice');
    expect(privacy.hides(12), isTrue);
    await settle();
    expect(privacy.hides(13), isFalse);
    await privacy.setEnabled(true);
    expect(privacy.hides(12), isFalse);
    expect(privacy.hides(13), isTrue);
    expect(privacy.hides(null), isTrue);
    expect(privacy.hides(13, isShow: true), isFalse);
    expect(privacy.hides(13, ownerId: 'alice'), isFalse);
    expect(privacy.hides(13, ownerId: 'bob'), isTrue);
    final restored = MovieRatingPrivacy(loadRatings: (_) async => {12});
    addTearDown(restored.dispose);
    restored.syncUser('alice');
    await settle();
    expect(restored.enabled, isTrue);
    restored.syncUser('bob');
    await settle();
    expect(restored.enabled, isFalse);
    expect(restored.hides(13), isFalse);
  });

  test('late previous account response cannot expose movie scores', () async {
    SharedPreferences.setMockInitialValues({
      MovieRatingPrivacy.storageKey('alice'): true,
      MovieRatingPrivacy.storageKey('bob'): true,
    });
    final alice = Completer<Set<int>>();
    final privacy = MovieRatingPrivacy(
        loadRatings: (id) => id == 'alice' ? alice.future : Future.value({2}));
    addTearDown(privacy.dispose);
    privacy.syncUser('alice');
    await settle();
    privacy.syncUser('bob');
    await settle();
    alice.complete({1});
    await settle();
    expect(privacy.hides(1), isTrue);
    expect(privacy.hides(2), isFalse);
  });

  test(
      'failed loads hide unknown scores; confirmed saves survive an older response',
      () async {
    var fail = true;
    final pending = Completer<Set<int>>();
    final privacy = MovieRatingPrivacy(loadRatings: (_) async {
      if (fail) throw Exception('offline');
      return pending.future;
    });
    addTearDown(privacy.dispose);
    privacy.syncUser('alice');
    await settle();
    await privacy.setEnabled(true);
    expect(privacy.ratingsFailed, isTrue);
    expect(privacy.hides(1), isTrue);
    privacy.ratingSaved('bob', 1, 8);
    privacy.ratingSaved('alice', 1, null);
    privacy.ratingSaved('alice', 1, 0);
    expect(privacy.hides(1), isTrue);
    fail = false;
    final refresh = privacy.refreshRatings();
    privacy.ratingSaved('alice', 1, 8);
    pending.complete({2});
    await refresh;
    expect(privacy.hides(1), isFalse);
    expect(privacy.hides(2), isFalse);
    expect(privacy.hides(3), isTrue);
    await privacy.setEnabled(false);
    expect(privacy.hides(3), isFalse);
  });

  testWidgets('public score updates immediately after saving a personal rating',
      (tester) async {
    final privacy = MovieRatingPrivacy(loadRatings: (_) async => {});
    privacy.syncUser('alice');
    await tester.runAsync(settle);
    await tester.runAsync(() => privacy.setEnabled(true));
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: privacy,
        child: const MaterialApp(
            home: Scaffold(
                body: MovieSearchResultTile(
          movie: MovieShort(id: 1, name: 'Test movie', voteAverage: 8.4),
        )))));
    expect(find.text('8.4'), findsNothing);
    privacy.ratingSaved('alice', 1, 6);
    await tester.pump();
    expect(find.text('8.4'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    privacy.dispose();
  });

  testWidgets('settings toggle remains usable on a small phone with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final privacy = MovieRatingPrivacy(loadRatings: (_) async => {});
    privacy.syncUser('alice');
    await tester.runAsync(settle);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: privacy,
        child: const MaterialApp(
            home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(2)),
                child: Scaffold(
                    body: SingleChildScrollView(
                        child: MovieRatingPrivacySetting()))))));
    expect(find.text('Rate movies first'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.byType(Divider), findsOneWidget);
    await tester.tap(find.text('Rate movies first'));
    await tester.runAsync(settle);
    await tester.pumpAndSettle();
    expect(privacy.enabled, isTrue);
    await tester.pumpWidget(const SizedBox());
    privacy.dispose();
  });
  testWidgets(
      'chat hides friends movie ratings but preserves TV and your own scores',
      (tester) async {
    final privacy = MovieRatingPrivacy(loadRatings: (_) async => {});
    privacy.syncUser('alice');
    await tester.runAsync(settle);
    await tester.runAsync(() => privacy.setEnabled(true));
    for (final scenario in [
      ('movies', 'bob', false),
      ('shows', 'bob', true),
      ('movies', 'alice', true),
    ]) {
      final payload = ActivityReplyPayload(
          userId: scenario.$2,
          username: scenario.$2,
          activityLabel: 'rating',
          title: 'A title',
          link: 'flixie://${scenario.$1}/77',
          posterUrl: '',
          rating: 9);
      await tester.pumpWidget(ChangeNotifierProvider.value(
          value: privacy,
          child: MaterialApp(
              home: Scaffold(
                  body: SingleChildScrollView(
                      child: ChatBubble(
            message: payload.withMessage('Have you seen this?'),
            senderUsername: 'bob',
            currentUserId: 'alice',
            currentUsername: 'alice',
            isMe: false,
            sentAt: DateTime(2026),
          ))))));
      expect(find.text('9/10'), scenario.$3 ? findsOneWidget : findsNothing);
      expect(find.text('A title'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    privacy.dispose();
  });
}
