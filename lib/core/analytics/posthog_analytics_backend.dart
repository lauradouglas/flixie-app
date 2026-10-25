import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:flutter/foundation.dart';

import 'analytics_backend.dart';

/// Receives only the consent-gated, filtered events from AnalyticsController.
class PostHogAnalyticsBackend implements AnalyticsBackend {
  PostHogAnalyticsBackend({
    this.projectToken = const String.fromEnvironment(
      'POSTHOG_PROJECT_TOKEN',
      // Public ingestion token, not an administrative API credential.
      // Development builds stay silent unless explicitly configured.
      defaultValue: kReleaseMode
          ? 'phc_pBPr8bxMacv2NFncoFSTrD4jjKhwCmEGD58McJkq4CDY'
          : '',
    ),
    this.host = const String.fromEnvironment('POSTHOG_HOST',
        defaultValue: 'https://eu.i.posthog.com'),
  });

  final String projectToken;
  final String host;
  bool _ready = false;
  bool _enabled = false;

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    _enabled = false;
    if (kIsWeb || projectToken.trim().isEmpty) return;
    // Do not initialise or contact PostHog before explicit consent.
    if (!_ready) {
      if (!enabled) return;
      final config = PostHogConfig(projectToken.trim())
        ..host = host
        ..optOut = true
        ..captureApplicationLifecycleEvents = false
        ..preloadFeatureFlags = false
        ..sendFeatureFlagEvent = false
        ..sessionReplay = false
        ..personProfiles = PostHogPersonProfiles.never;
      config.rageClickConfig.enabled = false;
      await Posthog().setup(config);
      _ready = true;
    }
    if (enabled) {
      await Posthog().optIn();
      _enabled = true;
    } else {
      await Posthog().optOut();
    }
  }

  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) async {
    if (!_enabled) return;
    await Posthog().capture(eventName: name, properties: parameters);
  }

  @override
  Future<void> logScreenView(String screenName) async {
    if (!_enabled) return;
    await Posthog().screen(screenName: screenName);
  }
}
