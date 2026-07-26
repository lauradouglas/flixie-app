import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/core/analytics/analytics_backend.dart';
import 'package:flixie_app/core/analytics/analytics_consent.dart';
import 'package:flixie_app/core/analytics/analytics_consent_prompt.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';

class _FakeBackend implements AnalyticsBackend {
  final List<bool> collectionStates = [];
  final List<({String name, Map<String, Object>? parameters})> events = [];
  bool throwOnOperation = false;

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    if (throwOnOperation) throw StateError('analytics unavailable');
    collectionStates.add(enabled);
  }

  @override
  Future<void> logEvent(
    String name,
    Map<String, Object>? parameters,
  ) async {
    if (throwOnOperation) throw StateError('analytics unavailable');
    events.add((name: name, parameters: parameters));
  }
}

class _FakeConsentStore implements AnalyticsConsentStore {
  _FakeConsentStore([this.value = AnalyticsConsent.unknown]);

  AnalyticsConsent value;
  bool throwOnWrite = false;

  @override
  Future<AnalyticsConsent> read() async => value;

  @override
  Future<void> write(AnalyticsConsent consent) async {
    if (throwOnWrite) throw StateError('storage unavailable');
    value = consent;
  }
}

AnalyticsController _controller(
  _FakeBackend backend,
  _FakeConsentStore store,
) =>
    AnalyticsController(backend: backend, consentStore: store);

void main() {
  test('collection stays disabled for unknown consent', () async {
    final backend = _FakeBackend();
    final controller = _controller(backend, _FakeConsentStore());

    await controller.initialize();

    expect(controller.consent, AnalyticsConsent.unknown);
    expect(backend.collectionStates, [false]);
  });

  test('accepting enables collection and persists the choice', () async {
    final backend = _FakeBackend();
    final store = _FakeConsentStore();
    final controller = _controller(backend, store);
    await controller.initialize();

    await controller.allow();

    expect(controller.isEnabled, isTrue);
    expect(store.value, AnalyticsConsent.accepted);
    expect(backend.collectionStates, [false, true]);
  });

  test('declining persists and keeps collection disabled', () async {
    final backend = _FakeBackend();
    final store = _FakeConsentStore();
    final controller = _controller(backend, store);
    await controller.initialize();

    await controller.decline();

    expect(store.value, AnalyticsConsent.declined);
    expect(backend.collectionStates.last, isFalse);
  });

  test('withdrawing accepted consent disables collection', () async {
    final backend = _FakeBackend();
    final controller =
        _controller(backend, _FakeConsentStore(AnalyticsConsent.accepted));
    await controller.initialize();

    await controller.decline();

    expect(controller.isEnabled, isFalse);
    expect(backend.collectionStates.last, isFalse);
  });

  test('saved choice is restored after restart', () async {
    final store = _FakeConsentStore(AnalyticsConsent.accepted);
    final backend = _FakeBackend();

    await _controller(backend, store).initialize();

    expect(backend.collectionStates, [false, true]);
  });

  test('events are ignored unless consent is accepted', () async {
    final backend = _FakeBackend();
    final controller = _controller(backend, _FakeConsentStore());
    await controller.initialize();

    await controller.friendRequestSent();

    expect(backend.events, isEmpty);
  });

  test('analytics and persistence errors never escape', () async {
    final backend = _FakeBackend()..throwOnOperation = true;
    final store = _FakeConsentStore()..throwOnWrite = true;
    final controller = _controller(backend, store);

    await expectLater(controller.initialize(), completes);
    await expectLater(controller.allow(), completes);
    await expectLater(controller.friendRequestSent(), completes);
  });

  test('approved events emit only controlled safe parameters', () async {
    final backend = _FakeBackend();
    final controller =
        _controller(backend, _FakeConsentStore(AnalyticsConsent.accepted));
    await controller.initialize();

    await controller.watchInvitationSent(recipientType: 'unexpected-value');
    await controller.watchlistItemAdded(source: 'free form text');
    await controller.watchlistItemRemoved(source: 'show_detail');
    await controller.favouriteSelected(favouriteCount: 500);

    expect(backend.events[0].parameters, {'recipient_type': 'friend'});
    expect(backend.events[1].parameters, {'source': 'home'});
    expect(backend.events[2].name, 'watchlist_item_removed');
    expect(backend.events[2].parameters, {'source': 'show_detail'});
    expect(backend.events[3].parameters, {'favourite_count': 5});
    for (final event in backend.events) {
      final approvedKeys = AnalyticsController.approvedEvents[event.name]!;
      expect(
        (event.parameters?.keys ?? const <String>[])
            .every(approvedKeys.contains),
        isTrue,
      );
    }
  });

  test('media collection events use identifier-free event types', () async {
    final backend = _FakeBackend();
    final controller =
        _controller(backend, _FakeConsentStore(AnalyticsConsent.accepted));
    await controller.initialize();

    await controller.movieFavourited();
    await controller.movieUnfavourited();
    await controller.showFavourited();
    await controller.showUnfavourited();
    await controller.movieAddedToWatchlist();
    await controller.movieRemovedFromWatchlist();
    await controller.showAddedToWatchlist();
    await controller.showRemovedFromWatchlist();
    await controller.movieAddedToList();
    await controller.movieRemovedFromList();
    await controller.showAddedToList();
    await controller.showRemovedFromList();

    expect(
      backend.events.map((event) => event.name),
      [
        'movie_favourited',
        'movie_unfavourited',
        'show_favourited',
        'show_unfavourited',
        'movie_added_to_watchlist',
        'movie_removed_from_watchlist',
        'show_added_to_watchlist',
        'show_removed_from_watchlist',
        'movie_added_to_list',
        'movie_removed_from_list',
        'show_added_to_list',
        'show_removed_from_list',
      ],
    );
    expect(backend.events.every((event) => event.parameters == null), isTrue);
  });

  test('referral reward events contain no identity or referral code', () async {
    final backend = _FakeBackend();
    final controller =
        _controller(backend, _FakeConsentStore(AnalyticsConsent.accepted));
    await controller.initialize();

    await controller.referralInviteShared();
    await controller.referralQualified();
    await controller.rewardUnlocked();
    await controller.tasteMatchViewed();
    await controller.matchedMovieInvitationSent();

    expect(
      backend.events.map((event) => event.name),
      [
        'referral_invite_shared',
        'referral_qualified',
        'reward_unlocked',
        'taste_match_viewed',
        'matched_movie_invitation_sent',
      ],
    );
    expect(backend.events.every((event) => event.parameters == null), isTrue);
  });

  test('signup and onboarding lifecycle events are not duplicated', () async {
    final backend = _FakeBackend();
    final controller =
        _controller(backend, _FakeConsentStore(AnalyticsConsent.accepted));
    await controller.initialize();

    await controller.signupStarted();
    await controller.signupStarted();
    await controller.signupCompleted();
    await controller.signupCompleted();
    await controller.onboardingStarted();
    await controller.onboardingStarted();
    await controller.onboardingCompleted(favouriteCount: 1);
    await controller.onboardingCompleted(favouriteCount: 1);

    expect(
      backend.events.map((event) => event.name),
      [
        'signup_started',
        'signup_completed',
        'onboarding_started',
        'onboarding_completed',
      ],
    );
  });

  test('a failed product operation does not emit its success event', () async {
    final backend = _FakeBackend();
    final controller =
        _controller(backend, _FakeConsentStore(AnalyticsConsent.accepted));
    await controller.initialize();

    Future<void> saveRating() async {
      await Future<void>.error(StateError('backend request failed'));
      await controller.ratingSaved(source: 'movie_detail');
    }

    await expectLater(saveRating(), throwsStateError);
    expect(backend.events, isEmpty);
  });

  testWidgets('unknown consent shows explicit equal choices once',
      (tester) async {
    final store = _FakeConsentStore();
    final controller = _controller(_FakeBackend(), store);
    await controller.initialize();

    await tester.pumpWidget(
      ChangeNotifierProvider<AnalyticsController>.value(
        value: controller,
        child: const MaterialApp(
          home: AnalyticsConsentPrompt(child: Scaffold()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Decline'), findsOneWidget);
    expect(find.text('Allow analytics'), findsOneWidget);
    final declineSize =
        tester.getSize(find.widgetWithText(OutlinedButton, 'Decline'));
    final allowSize =
        tester.getSize(find.widgetWithText(FilledButton, 'Allow analytics'));
    expect(declineSize.width, allowSize.width);

    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
    expect(store.value, AnalyticsConsent.declined);
    expect(find.text('Allow analytics'), findsNothing);
  });
}
