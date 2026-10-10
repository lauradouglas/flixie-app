import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flixie_app/core/analytics/analytics_backend.dart';
import 'package:flixie_app/core/analytics/analytics_consent.dart';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_prefetch_coordinator.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/watch_provider.dart';
import '../../test/support/watchlist_auth.dart';

/// Observes real HTTP. It does not generate API payloads or artificial delays.
class RuntimeDatabaseClient extends http.BaseClient {
  RuntimeDatabaseClient({required this.onStart, required this.onEnd})
      : _client = HttpOverrides.runWithHttpOverrides(
            () => IOClient(HttpClient()), _RuntimeHttpOverrides());
  final void Function(String) onStart;
  final void Function() onEnd;
  final http.Client _client;
  final responses = <String, Map<String, int>>{};
  final transportErrors = <String, List<String>>{};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    onStart('${request.method} ${request.url.path}');
    try {
      // Buffering tracks completion through body receipt, as the mock client does.
      final response =
          await http.Response.fromStream(await _client.send(request));
      final key = '${request.method} ${request.url.path}';
      final counts = responses.putIfAbsent(key, () => {});
      counts.update('${response.statusCode}', (count) => count + 1,
          ifAbsent: () => 1);
      return http.StreamedResponse(
          Stream.value(response.bodyBytes), response.statusCode,
          headers: response.headers, request: request);
    } catch (error) {
      final key = '${request.method} ${request.url.path}';
      transportErrors.putIfAbsent(key, () => []).add(error.toString());
      rethrow;
    } finally {
      onEnd();
    }
  }

  Future<Map<String, dynamic>> load(String path) async {
    final response = await get(Uri.parse('${ApiClient.baseUrl}$path'));
    if (response.statusCode != 200) {
      throw StateError(
          'Fixture bootstrap failed: $path (${response.statusCode})');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  void close() => _client.close();
}

/// A database User snapshot with production provider enrichment. Authentication
/// bootstrap is excluded; the server accepts only its own fictional identities.
class RuntimeDatabaseAuth extends TestAuth {
  RuntimeDatabaseAuth(this.user, MovieService movies)
      : _prefetch = AuthPrefetchCoordinator(movieService: movies);
  final User user;
  final AuthPrefetchCoordinator _prefetch;
  final _providers = <int, List<WatchProvider>>{};
  Set<int> _userProviders = {};
  Future<void>? _inFlight;

  @override
  User get dbUser => user;
  @override
  int get unreadNotificationCount => 0;
  @override
  Map<int, List<WatchProvider>> get cachedWatchProvidersByMovieId => _providers;
  @override
  Set<int> get cachedUserWatchProviderIds => _userProviders;

  @override
  Future<void> ensureWatchProviderCache({Iterable<int>? movieIds}) async {
    if (_inFlight != null) await _inFlight;
    final missing = (movieIds ?? const <int>[])
        .where((id) => !_providers.containsKey(id))
        .toSet();
    if (missing.isEmpty) return;
    providerRequests.add(missing.toList());
    final future = _prefetch.fetchWatchProviders(user.id, missing,
        region: user.watchProviderRegion, onProgress: (providers, userIds) {
      _providers.addAll(providers);
      _userProviders = userIds;
      notifyListeners();
    }).then((_) {});
    _inFlight = future;
    try {
      await future;
    } finally {
      if (identical(_inFlight, future)) _inFlight = null;
    }
  }
}

class _RuntimeHttpOverrides extends HttpOverrides {}

/// Local analytics transport: no fixture events leave the simulator.
class RuntimeAnalyticsBackend implements AnalyticsBackend {
  @override
  Future<void> setCollectionEnabled(bool enabled) async {}
  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) async {}
  @override
  Future<void> logScreenView(String screenName) async {}
}

class RuntimeAnalyticsConsentStore implements AnalyticsConsentStore {
  @override
  Future<AnalyticsConsent> read() async => AnalyticsConsent.declined;
  @override
  Future<void> write(AnalyticsConsent consent) async {}
}
