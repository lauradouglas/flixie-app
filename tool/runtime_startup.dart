import 'package:flixie_app/core/auth/startup_trace.dart';
import 'runtime_fixture_endpoint.dart';
// Autonomous entrypoint for host-observed process-launch benchmarks only.
// Never build or distribute this target as the production app.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/app/theme/appearance_controller.dart';
import 'package:flixie_app/core/analytics/analytics_backend.dart';
import 'package:flixie_app/core/analytics/analytics_consent.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/auth/auth_service.dart';
import 'package:flixie_app/features/authentication/presentation/pages/login_screen.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'package:flixie_app/features/social/data/chat_unread_controller.dart';
import 'package:flixie_app/features/social/data/watch_request_cache.dart';
import 'package:flixie_app/main.dart';

class _NoPushAuth extends AuthProvider {
  _NoPushAuth(super.service, super.movies);
  @override
  void setNavigatorKey(GlobalKey<NavigatorState> key) {}
}

class _LocalAnalytics implements AnalyticsBackend {
  @override
  Future<void> setCollectionEnabled(bool enabled) async {}
  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) async {}
  @override
  Future<void> logScreenView(String screenName) async {}
}

class _DeclinedConsent implements AnalyticsConsentStore {
  @override
  Future<AnalyticsConsent> read() async => AnalyticsConsent.declined;
  @override
  Future<void> write(AnalyticsConsent consent) async {}
}

Future<void> main() async {
  final watch = Stopwatch()..start();
  const homeTrace = bool.fromEnvironment('HOME_TIMING_TRACE');
  final trace = <Map<String, Object?>>[];
  if (homeTrace) {
    StartupTrace.observer = (event) {
      if (trace.length < 2000) trace.add(event);
    };
    StartupTrace.mark('capture.dart-entry');
  }
  WidgetsFlutterBinding.ensureInitialized();
  verifyRuntimeFixtureEndpoint(ApiClient.baseUrl);
  // The local host serialises launches and binds each to a fresh nonce.
  // Avoid depending on iOS environment-variable propagation into Dart.
  final client = http.Client();
  final configurationWatch = Stopwatch()..start();
  final configuration = await client.get(
      Uri.parse('${ApiClient.baseUrl}/benchmark/startup-config'),
      headers: {'authorization': 'Bearer runtime-fixture-0'});
  if (configuration.statusCode != 200) {
    throw StateError('Launch only through capture-startup-baseline.py.');
  }
  final configurationUs = configurationWatch.elapsedMicroseconds;
  final config = jsonDecode(configuration.body) as Map<String, dynamic>;
  final captureId = config['capture_id'] as String;
  final mode = config['mode'] as String;
  final size = config['library_size'] as int;
  if (![20, 400].contains(size)) {
    throw StateError('Unexpected fixture library.');
  }
  final index = size == 20 ? 0 : 1;
  final firebaseWatch = Stopwatch()..start();
  final app = await Firebase.initializeApp(
      options: const FirebaseOptions(
          apiKey: 'AIzaSy000000000000000000000000000000000',
          appId: '1:123456789:ios:0123456789abcdef',
          messagingSenderId: '123456789',
          projectId: 'demo-flixie-review'));
  final firebaseUs = firebaseWatch.elapsedMicroseconds;
  final firebase = fb.FirebaseAuth.instanceFor(app: app);
  await firebase.useAuthEmulator(runtimeFixtureHost, 9099,
      automaticHostMapping: false);
  FirebaseFirestore.instanceFor(app: app).useFirestoreEmulator(
      runtimeFirestoreHost, 8185,
      automaticHostMapping: false);
  final requests = <String, int>{};
  final statuses = <String, Map<String, int>>{};
  final api = _CountingClient(client, requests, statuses);
  ApiClient.initializeTransport(client: api);
  final manifestWatch = Stopwatch()..start();
  final manifestResponse =
      await client.get(Uri.parse('${ApiClient.baseUrl}/benchmark/manifest'));
  final manifest = jsonDecode(manifestResponse.body) as Map<String, dynamic>;
  final manifestUs = manifestWatch.elapsedMicroseconds;
  if (manifestResponse.statusCode != 200 ||
      manifest['database'] != 'flixie_runtime_fixture') {
    throw StateError('Unexpected fixture database.');
  }
  Future<void> publish(Map<String, Object?> sample) async {
    final response =
        await client.post(Uri.parse('${ApiClient.baseUrl}/benchmark/results'),
            headers: {
              'content-type': 'application/json',
              'authorization': 'Bearer runtime-fixture-$index'
            },
            body: jsonEncode({
              'complete': true,
              'method': {'suite': 'os_startup', 'capture_id': captureId},
              'samples': [sample]
            }));
    if (response.statusCode != 200) {
      throw StateError('Unable to persist process measurement.');
    }
  }

  if (mode.startsWith('prepare_')) {
    await firebase.signOut();
    if (mode == 'prepare_signed_in') {
      await firebase.signInWithEmailAndPassword(
          email: 'runtime_$index@example.invalid',
          password: 'RuntimeFixture1!');
    }
    await publish({'prepared': true, 'mode': mode});
    return;
  }
  final preferences = await SharedPreferences.getInstance();
  final appearance = AppearanceController(preferences);
  final analytics = AnalyticsController(
      backend: _LocalAnalytics(), consentStore: _DeclinedConsent());
  await analytics.initialize();
  final movies = MovieService();
  final auth = _NoPushAuth(AuthService(firebaseAuth: firebase), movies);
  int? authReadyUs;
  auth.addListener(() {
    if (auth.status != AuthStatus.unknown) {
      authReadyUs ??= watch.elapsedMicroseconds;
    }
  });
  final key = GlobalKey();
  final frames = <FrameTiming>[];
  SchedulerBinding.instance.addTimingsCallback(frames.addAll);
  final startRss = ProcessInfo.currentRss;
  var peakRss = startRss;
  final runAppUs = watch.elapsedMicroseconds;
  runApp(MultiProvider(providers: [
    ChangeNotifierProvider<AppearanceController>.value(value: appearance),
    ChangeNotifierProvider<AnalyticsController>.value(value: analytics),
    Provider<MovieService>.value(value: movies),
    ChangeNotifierProvider<AuthProvider>.value(value: auth),
    ChangeNotifierProxyProvider<AuthProvider, MovieRatingPrivacy>(
        create: (_) => MovieRatingPrivacy.instance,
        update: (_, value, privacy) => (privacy ?? MovieRatingPrivacy.instance)
          ..syncUser(value.dbUser?.id)),
    ChangeNotifierProxyProvider<AuthProvider, ChatUnreadController>(
        create: (_) => ChatUnreadController(),
        update: (_, value, chat) =>
            (chat ?? ChatUnreadController())..syncUser(value.dbUser?.id)),
    ChangeNotifierProxyProvider<AuthProvider, WatchRequestCache>(
        create: (_) => WatchRequestCache(),
        update: (_, value, cache) => (cache ?? WatchRequestCache())
          ..syncUser(value.dbUser?.id, deferWarm: true)),
  ], child: KeyedSubtree(key: key, child: const FlixieApp())));
  var published = false;
  Timer.periodic(const Duration(milliseconds: 20), (timer) async {
    if (ProcessInfo.currentRss > peakRss) peakRss = ProcessInfo.currentRss;
    var useful = false;
    void inspect(Element element) {
      final widget = element.widget;
      if (mode == 'signed_out' &&
          widget is LoginScreen &&
          auth.status == AuthStatus.unauthenticated) {
        useful = true;
      }
      if (mode == 'signed_in' &&
          widget is Text &&
          widget.data == 'Alien' &&
          auth.status == AuthStatus.authenticated &&
          auth.dbUser?.id == 'runtime-fixture-$index') {
        final render = element.findRenderObject();
        if (render is RenderBox &&
            render.attached &&
            render.hasSize &&
            render.size.height > 0) {
          useful = true;
        }
      }
      element.visitChildElements(inspect);
    }

    if (key.currentContext != null) inspect(key.currentContext! as Element);
    if (homeTrace &&
        mode == 'signed_in' &&
        size == 20 &&
        (!trace.any((event) => event['phase'] == 'home.plans.first-frame') ||
            trace.any((event) =>
                event['phase'] == 'home.plans.load' &&
                event['kind'] == 'start' &&
                !trace.any((end) =>
                    end['id'] == event['id'] && end['kind'] == 'end')))) {
      return;
    }
    if (!useful || published) return;
    published = true;
    timer.cancel();
    // Observe content after a completed frame, rather than just its build.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      final usefulUs = watch.elapsedMicroseconds;
      if (mode == 'signed_in' &&
          (auth.dbUser!.movieWatchlist!.length != size ||
              !auth.termsVerified)) {
        throw StateError('Wrong account/library/terms at startup.');
      }
      await publish({
        if (homeTrace) 'home_trace': List.of(trace),
        'scenario': mode,
        'library_size': size,
        'dart_entry_to_content_us': usefulUs,
        'firebase_initialize_us': firebaseUs,
        'fixture_configuration_fetch_us': configurationUs,
        'fixture_manifest_fetch_us': manifestUs,
        'run_app_us': runAppUs,
        'auth_ready_us': authReadyUs,
        'rss_start_bytes': startRss,
        'rss_peak_bytes': peakRss,
        'rss_end_bytes': ProcessInfo.currentRss,
        'requests': Map<String, int>.from(requests),
        'response_statuses': statuses,
        'frame_build_us':
            frames.map((f) => f.buildDuration.inMicroseconds).toList(),
        'frame_raster_us':
            frames.map((f) => f.rasterDuration.inMicroseconds).toList(),
        'database_manifest': manifest,
      });
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  });
}

class _CountingClient extends http.BaseClient {
  _CountingClient(this.client, this.requests, this.statuses);
  final http.Client client;
  final Map<String, int> requests;
  final Map<String, Map<String, int>> statuses;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = '${request.method} ${request.url.path}';
    requests.update(path, (v) => v + 1, ifAbsent: () => 1);
    final response = await http.Response.fromStream(await client.send(request));
    statuses
        .putIfAbsent(path, () => {})
        .update('${response.statusCode}', (v) => v + 1, ifAbsent: () => 1);
    return http.StreamedResponse(
        Stream.value(response.bodyBytes), response.statusCode,
        headers: response.headers, request: request);
  }
}
