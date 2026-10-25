import 'package:flixie_app/core/analytics/posthog_analytics_backend.dart';
import 'package:flixie_app/core/analytics/analytics_backend.dart';
import 'package:flixie_app/core/analytics/analytics_consent.dart';
import 'package:flixie_app/core/analytics/shared_preferences_analytics_consent_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:posthog_flutter/src/posthog_flutter_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Platform extends PosthogFlutterPlatformInterface {
  PostHogConfig? config;
  final events = <String>[];
  final states = <bool>[];
  @override
  Future<void> setup(PostHogConfig config) async => this.config = config;
  @override
  Future<void> enable() async => states.add(true);
  @override
  Future<void> disable() async => states.add(false);
  @override
  Future<void> capture(
      {required String eventName,
      Map<String, Object>? properties,
      Map<String, Object>? userProperties,
      Map<String, Object>? userPropertiesSetOnce}) async {
    events.add(eventName);
  }

  @override
  Future<void> screen(
      {required String screenName, Map<String, Object>? properties}) async {
    events.add(screenName);
  }
}

class _Backend implements AnalyticsBackend {
  _Backend({this.fail = false});
  final bool fail;
  final calls = <String>[];
  Future<void> record(String call) async {
    if (fail) throw StateError('provider unavailable');
    calls.add(call);
  }

  @override
  Future<void> setCollectionEnabled(bool enabled) => record('$enabled');
  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) =>
      record(name);
  @override
  Future<void> logScreenView(String screenName) => record(screenName);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Platform platform;
  setUp(() {
    platform = _Platform();
    PosthogFlutterPlatformInterface.instance = platform;
  });

  test('provider failure cannot block collection changes or the other provider',
      () async {
    final healthy = _Backend();
    final backend = CompositeAnalyticsBackend([_Backend(fail: true), healthy]);
    await backend.setCollectionEnabled(true);
    await backend.logEvent('signup_completed', null);
    await backend.logScreenView('home');
    await backend.setCollectionEnabled(false);
    expect(healthy.calls, ['true', 'signup_completed', 'home', 'false']);
  });

  test('unknown consent and missing token never initialise PostHog', () async {
    final backend = PostHogAnalyticsBackend(projectToken: 'test');
    await backend.setCollectionEnabled(false);
    await backend.logEvent('signup_completed', null);
    expect(platform.config, isNull);
    final unconfigured = PostHogAnalyticsBackend(projectToken: '');
    await unconfigured.setCollectionEnabled(true);
    await unconfigured.logEvent('signup_completed', null);
    expect(platform.config, isNull);
    expect(platform.events, isEmpty);
  });

  test('allow enables manual events; withdrawal stops them', () async {
    final backend = PostHogAnalyticsBackend(projectToken: 'test');
    await backend.setCollectionEnabled(true);
    final config = platform.config!;
    expect(config.optOut, isTrue);
    expect(config.sessionReplay, isFalse);
    expect(config.captureApplicationLifecycleEvents, isFalse);
    expect(config.preloadFeatureFlags, isFalse);
    expect(config.rageClickConfig.enabled, isFalse);
    expect(config.personProfiles, PostHogPersonProfiles.never);
    await backend.logEvent('signup_completed', null);
    await backend.logScreenView('home');
    await backend.setCollectionEnabled(false);
    await backend.logEvent('watch_logged', null);
    await backend.logScreenView('profile');
    expect(platform.events, ['signup_completed', 'home']);
    expect(platform.states, [true, false]);
  });

  test('old acceptance requires renewed consent; old refusal is preserved',
      () async {
    final store = SharedPreferencesAnalyticsConsentStore();
    SharedPreferences.setMockInitialValues(
        {'analytics_consent_v1': 'accepted'});
    expect(await store.read(), AnalyticsConsent.unknown);
    SharedPreferences.setMockInitialValues(
        {'analytics_consent_v1': 'declined'});
    expect(await store.read(), AnalyticsConsent.declined);
    await store.write(AnalyticsConsent.accepted);
    expect(await store.read(), AnalyticsConsent.accepted);
  });
}
