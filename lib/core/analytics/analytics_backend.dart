import 'package:firebase_analytics/firebase_analytics.dart';

abstract interface class AnalyticsBackend {
  Future<void> setCollectionEnabled(bool enabled);
  Future<void> logEvent(String name, Map<String, Object>? parameters);
  Future<void> logScreenView(String screenName);
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

  @override
  Future<void> logScreenView(String screenName) =>
      _analytics.logScreenView(screenName: screenName);
}

/// Isolates provider failures so each destination gets the same safe events.
class CompositeAnalyticsBackend implements AnalyticsBackend {
  CompositeAnalyticsBackend(this.backends);

  final List<AnalyticsBackend> backends;

  Future<void> _each(Future<void> Function(AnalyticsBackend) operation) async {
    for (final backend in backends) {
      try {
        await operation(backend);
      } catch (_) {
        // Analytics must never interrupt the app or another provider.
      }
    }
  }

  @override
  Future<void> setCollectionEnabled(bool enabled) =>
      _each((backend) => backend.setCollectionEnabled(enabled));

  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) =>
      _each((backend) => backend.logEvent(name, parameters));

  @override
  Future<void> logScreenView(String screenName) =>
      _each((backend) => backend.logScreenView(screenName));
}
