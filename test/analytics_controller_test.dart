import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/core/analytics/analytics_backend.dart';
import 'package:flixie_app/core/analytics/analytics_consent.dart';
import 'package:flixie_app/core/analytics/analytics_consent_prompt.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/core/analytics/recommendation_attribution.dart';

class _FakeBackend implements AnalyticsBackend {
  final List<bool> collectionStates = [];
  final List<({String name, Map<String, Object>? parameters})> events = [];
  bool throwOnOperation = false;
  final List<String> screens = [];

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

  @override
  Future<void> logScreenView(String screenName) async {
    if (throwOnOperation) throw StateError('analytics unavailable');
    screens.add(screenName);
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

  test('event contract keeps only approved parameters and normalises source',
      () async {
    final backend = _FakeBackend();
    final controller =
        _controller(backend, _FakeConsentStore(AnalyticsConsent.accepted));
    await controller.initialize();

    await controller.logEvent('content_opened', {
      'content_type': 'movie',
      'content_id': 42,
      'source': 'home',
      'email': 'private@example.com',
      'username': 'private_user',
      'review_text': 'private review',
    });
    await controller.watchlistAdded(
      contentType: 'show',
      contentId: 9,
      source: 'free form text',
    );

    expect(backend.events.first.name, 'content_opened');
    expect(backend.events.first.parameters, {
      'content_type': 'movie',
      'content_id': 42,
      'source': 'home',
    });
    expect(backend.events.last.parameters, {
      'content_type': 'show',
      'content_id': 9,
      'source': 'unknown',
    });
  });

  test('content events share canonical names and content parameters', () async {
    final backend = _FakeBackend();
    final controller =
        _controller(backend, _FakeConsentStore(AnalyticsConsent.accepted));
    await controller.initialize();

    await controller.contentOpened(
      contentType: 'movie',
      contentId: 123,
      genre: 'Adventure',
      source: 'search',
    );
    await controller.ratingAdded(
      contentType: 'show',
      contentId: 456,
      source: 'show_detail',
    );
    await controller.reviewCreated(
      contentType: 'movie',
      contentId: 123,
      source: 'movie_detail',
    );

    expect(
      backend.events.map((event) => event.name),
      ['content_opened', 'rating_added', 'review_created'],
    );
    expect(backend.events.first.parameters?['genre'], 'Adventure');
    expect(backend.events[1].parameters?['content_type'], 'show');
  });

  test('person opens include attribution without identity data', () async {
    final backend = _FakeBackend();
    final controller =
        _controller(backend, _FakeConsentStore(AnalyticsConsent.accepted));
    await controller.initialize();

    await controller.personOpened(
      personId: 88,
      source: 'person_credits',
      parentContentId: 42,
      parentContentType: 'movie',
    );

    expect(backend.events.single.name, 'person_opened');
    expect(backend.events.single.parameters, {
      'person_id': 88,
      'source': 'person_credits',
      'parent_content_id': 42,
      'parent_content_type': 'movie',
    });
  });

  test('recommendation impressions are deduplicated but actions are not',
      () async {
    final backend = _FakeBackend();
    final controller =
        _controller(backend, _FakeConsentStore(AnalyticsConsent.accepted));
    await controller.initialize();
    const attribution = RecommendationAttribution(
      contentId: 7,
      contentType: 'movie',
      source: 'just_for_you',
      position: 0,
      algorithm: 'weighted_taste_profile',
      version: 'v1',
      reason: 'taste_profile',
      predictedScore: .82,
    );

    Future<void> impression() => controller.recommendationImpression(
          attribution: attribution,
        );
    await impression();
    await impression();
    await controller.recommendationOpened(
      attribution: attribution,
    );

    expect(
      backend.events.map((event) => event.name),
      ['recommendation_impression', 'recommendation_opened'],
    );
    expect(backend.events.first.parameters, attribution.analyticsParameters);
  });

  test('rating can retain recommendation attribution', () async {
    final backend = _FakeBackend();
    final controller =
        _controller(backend, _FakeConsentStore(AnalyticsConsent.accepted));
    await controller.initialize();
    const attribution = RecommendationAttribution(
      contentId: 7,
      contentType: 'movie',
      source: 'just_for_you',
      position: 2,
      algorithm: 'weighted_taste_profile',
      version: 'v1',
      reason: 'rewatch',
      predictedScore: .7,
    );

    await controller.ratingAdded(
      contentType: 'movie',
      contentId: 7,
      source: 'just_for_you',
      recommendation: attribution,
    );

    expect(backend.events.single.name, 'rating_added');
    expect(
      backend.events.single.parameters,
      {'source': 'just_for_you', ...attribution.analyticsParameters},
    );
  });

  test('watch-plan lifecycle keeps stable funnel dimensions', () async {
    final backend = _FakeBackend();
    final controller =
        _controller(backend, _FakeConsentStore(AnalyticsConsent.accepted));
    await controller.initialize();

    await controller.watchPlanCreated(
      watchPlanId: 'plan-1',
      contentId: 42,
      contentType: 'movie',
      planType: 'group',
      participantCount: 4,
      source: 'movie_detail',
    );
    await controller.watchLogged(
      contentType: 'movie',
      contentId: 42,
      source: 'watch_plan',
      watchPlanId: 'plan-1',
      planType: 'group',
      participantCount: 4,
    );

    expect(backend.events.map((event) => event.name),
        ['watch_plan_created', 'watch_logged']);
    for (final event in backend.events) {
      expect(event.parameters, containsPair('watch_plan_id', 'plan-1'));
      expect(event.parameters, containsPair('plan_type', 'group'));
      expect(event.parameters, containsPair('participant_count', 4));
      expect(event.parameters, containsPair('content_id', 42));
    }
  });

  test('friend invite conversion and friendship remain distinct events',
      () async {
    final backend = _FakeBackend();
    final controller =
        _controller(backend, _FakeConsentStore(AnalyticsConsent.accepted));
    await controller.initialize();

    await controller.friendInviteConverted(
      inviteMethod: 'referral_link',
      source: 'shared_link',
    );
    await controller.friendConnected(source: 'shared_link');

    expect(backend.events.map((event) => event.name),
        ['friend_invite_converted', 'friend_connected']);
    expect(backend.events.first.parameters, {
      'invite_method': 'referral_link',
      'source': 'shared_link',
    });
  });

  test('first-run referral open waits for analytics consent', () async {
    final backend = _FakeBackend();
    final controller =
        _controller(backend, _FakeConsentStore(AnalyticsConsent.unknown));
    await controller.initialize();

    await controller.referralLinkOpened();
    expect(backend.events, isEmpty);

    await controller.allow();
    await controller.referralLinkOpened();

    expect(backend.events.map((event) => event.name),
        ['friend_invite_opened', 'shared_link_opened']);
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
        'taste_profile_completed',
      ],
    );
  });

  test('screen views are meaningful and consecutive duplicates are ignored',
      () async {
    final backend = _FakeBackend();
    final controller =
        _controller(backend, _FakeConsentStore(AnalyticsConsent.accepted));
    await controller.initialize();

    await controller.screenViewed('Home');
    await controller.screenViewed('Home');
    await controller.screenViewed('Movie Detail');

    expect(backend.screens, ['Home', 'Movie Detail']);
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
