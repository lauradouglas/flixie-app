import 'package:firebase_analytics/firebase_analytics.dart';

abstract interface class AnalyticsBackend {
  Future<void> setCollectionEnabled(bool enabled);
  Future<void> logEvent(String name, Map<String, Object>? parameters);
}

class FirebaseAnalyticsBackend implements AnalyticsBackend {
  FirebaseAnalyticsBackend({FirebaseAnalytics? analytics})
      : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  @override
  Future<void> setCollectionEnabled(bool enabled) =>
      _analytics.setAnalyticsCollectionEnabled(enabled);

  @override
  Future<void> logEvent(
    String name,
    Map<String, Object>? parameters,
  ) =>
      _analytics.logEvent(name: name, parameters: parameters);
}
