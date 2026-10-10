import '../tool/runtime_fixture_endpoint.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;
import 'dart:isolate';
import 'package:http/io_client.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/app/theme/appearance_controller.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/auth/auth_service.dart';
import 'package:flixie_app/features/authentication/presentation/pages/login_screen.dart';
import 'package:flixie_app/features/home/presentation/widgets/home_watchlist_action.dart';
import 'package:flixie_app/features/home/data/recommendation_service.dart';
import 'package:flixie_app/features/home/presentation/pages/home_screen.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/movies/data/show_service.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'package:flixie_app/features/social/data/chat_unread_controller.dart';
import 'package:flixie_app/features/social/data/watch_request_cache.dart';
import 'package:flixie_app/main.dart';
import '../test/support/api_fixture.dart';
import 'support/runtime_database_fixture.dart';

/// All session logic is production AuthProvider. Only push registration is
/// excluded: this demo project has no APNs/FCM configuration or real identities.
class _LifecycleAuth extends AuthProvider {
  _LifecycleAuth(super.service, super.movies, Map<String, int> phases)
      : super(profileLoader: (id) async {
          final watch = Stopwatch()..start();
          try {
            return await UserService.getUserByExternalId(id);
          } finally {
            phases['profile_us'] = watch.elapsedMicroseconds;
            phases.update('profile_total_us',
                (value) => value + watch.elapsedMicroseconds,
                ifAbsent: () => watch.elapsedMicroseconds);
            phases.update('profile_calls', (value) => value + 1,
                ifAbsent: () => 1);
          }
        }, termsStatusLoader: () async {
          final watch = Stopwatch()..start();
          try {
            final response = await ApiClient.get('/users/me/terms');
            return response is Map && response['accepted'] == true;
          } finally {
            phases['terms_us'] = watch.elapsedMicroseconds;
          }
        });

  @override
  void setNavigatorKey(GlobalKey<NavigatorState> key) {}
}

class _LifecycleService extends AuthService {
  _LifecycleService(fb.FirebaseAuth auth, this.phases)
      : super(firebaseAuth: auth);
  final Map<String, int> phases;
  @override
  Future<fb.UserCredential> signIn(String email, String password) async {
    final watch = Stopwatch()..start();
    try {
      return await super.signIn(email, password);
    } finally {
      phases['firebase_email_sign_in_us'] = watch.elapsedMicroseconds;
    }
  }
}

class _RealHttp extends HttpOverrides {}

class _ResumeObservation extends WidgetsBindingObserver {
  Stopwatch? watch;
  int? resumedUs;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && watch != null) {
      resumedUs ??= watch!.elapsedMicroseconds;
    }
  }
}

void main() {
  patrolTest('record real auth startup login and native resume', ($) async {
    verifyRuntimeFixtureEndpoint(ApiClient.baseUrl);
    final initializeWatch = Stopwatch()..start();
    final app = await Firebase.initializeApp(
        options: const FirebaseOptions(
            apiKey: 'AIzaSy000000000000000000000000000000000',
            appId: '1:123456789:ios:0123456789abcdef',
            messagingSenderId: '123456789',
            projectId: 'demo-flixie-review'));
    final firebaseInitializeUs = initializeWatch.elapsedMicroseconds;
    final firebase = fb.FirebaseAuth.instanceFor(app: app);
    await firebase.useAuthEmulator(runtimeFixtureHost, 9099,
        automaticHostMapping: false);
    FirebaseFirestore.instanceFor(app: app).useFirestoreEmulator(
        runtimeFirestoreHost, 8185,
        automaticHostMapping: false);
    expect(app.options.projectId, 'demo-flixie-review');

    final requests = <String, int>{};
    var active = 0;
    var maxActive = 0;
    final client = RuntimeDatabaseClient(
        onStart: (path) {
          requests.update(path, (value) => value + 1, ifAbsent: () => 1);
          active++;
          if (active > maxActive) maxActive = active;
        },
        onEnd: () => active--);
    useApiFixture(client);
    final manifest = await client.load('/benchmark/manifest');
    expect(manifest['database'], 'flixie_runtime_fixture');
    const accounts =
        String.fromEnvironment('RUNTIME_LIFECYCLE_SCOPE') == 'accounts';
    const retaining = bool.fromEnvironment('RUNTIME_RETAINING_PATHS');
    final memory = <Map<String, Object?>>[];
    final rpc = IOClient(
        HttpOverrides.runWithHttpOverrides(() => HttpClient(), _RealHttp()));
    addTearDown(rpc.close);
    Future<void> profile(String phase, int size, int repetition) async {
      final vm = (await developer.Service.getInfo()).serverUri!;
      final response = await rpc
          .get(vm.resolve('getAllocationProfile').replace(queryParameters: {
        'isolateId': developer.Service.getIsolateId(Isolate.current)!,
        'gc': 'true',
      }));
      expect(response.statusCode, 200);
      final envelope = jsonDecode(response.body) as Map<String, dynamic>;
      final data = Map<String, dynamic>.from(envelope['result'] ?? envelope);
      expect(data['type'], 'AllocationProfile');
      final paths = <Map<String, Object?>>[];
      var lookupCount = 0;
      if (retaining &&
          ['unmounted', 'post_cycle', 'post_input_replacement']
              .contains(phase)) {
        Future<Map<String, dynamic>> call(
            String method, Map<String, String> args) async {
          final result =
              await rpc.get(vm.resolve(method).replace(queryParameters: {
            'isolateId': developer.Service.getIsolateId(Isolate.current)!,
            ...args,
          }));
          expect(result.statusCode, 200);
          final envelope = jsonDecode(result.body) as Map<String, dynamic>;
          expect(envelope['error'], isNull);
          return Map<String, dynamic>.from(envelope['result'] ?? envelope);
        }

        for (final item in data['members'] as List) {
          if (item['class']['name'] != '_LifecycleAuth' ||
              item['instancesCurrent'] == 0) {
            continue;
          }
          final instances = await call(
              'getInstances', {'objectId': item['class']['id'], 'limit': '10'});
          lookupCount += instances['totalCount'] as int;
          for (final instance in instances['instances'] as List) {
            final path = await call('getRetainingPath',
                {'targetId': instance['id'], 'limit': '1000'});
            // Class/reference labels only: never serialise object values, fields or tokens.
            paths.add({
              'type': path['type'],
              'length': path['length'],
              'gcRootType': path['gcRootType'],
              'elements': [
                for (final element in (path['elements'] as List? ?? []))
                  {
                    'class': element['value']['class']?['name'],
                    'kind': element['value']['kind'],
                    'type': element['value']['type'],
                    'name': element['value']['name'],
                    'function': element['value']['closureFunction']?['name'],
                    'parentField': element['parentField'],
                    'parentListIndex': element['parentListIndex'],
                  }
              ],
            });
          }
        }
      }
      memory.add({
        'phase': phase,
        if (retaining) 'retaining_paths': paths,
        if (retaining) 'instance_lookup_count': lookupCount,
        'library_size': size,
        'repetition': repetition,
        'rss_bytes': ProcessInfo.currentRss,
        'image_cache_bytes':
            PaintingBinding.instance.imageCache.currentSizeBytes,
        'memoryUsage': data['memoryUsage'],
        'dateLastServiceGC': data['dateLastServiceGC'],
        'owned_classes': [
          for (final item in data['members'] as List)
            if ([
              'AuthProvider',
              'AuthAccountCache',
              'AuthSessionRecovery',
              '_LifecycleAuth',
              'HomeController',
              '_HomeSnapshot',
              '_HomeScreenState'
            ].contains(item['class']['name']))
              {
                'name': item['class']['name'],
                'instancesCurrent': item['instancesCurrent'],
                'bytesCurrent': item['bytesCurrent']
              }
        ],
      });
    }

    final samples = <Map<String, Object?>>[];
    final method = <String, Object?>{
      'suite': 'lifecycle',
      'scope': accounts ? 'accounts' : 'startup_login_resume',
      'retaining_paths': retaining,
      'capture_id': const String.fromEnvironment('RUNTIME_CAPTURE_ID'),
      'mode': kProfileMode
          ? 'profile'
          : kReleaseMode
              ? 'release'
              : 'debug',
      'database_manifest': manifest,
      'firebase_initialize_us': firebaseInitializeUs,
      'auth': 'native Firebase SDK, local Auth emulator, demo-flixie-review',
      'root':
          'production FlixieApp/router/AuthProvider, push registration excluded',
      'content_boundary': 'visible Home watchlist action and loaded Alien title; title may be below fold',
      'startup':
          'fresh auth provider/root; existing native Firebase session; not OS process launch',
      'login':
          'real email/password UI submit; Firebase emulator + profile/terms + Home',
      'resume':
          'native home/openApp; first refresh and next resume within two-minute throttle',
    };
    final observation = _ResumeObservation();
    WidgetsBinding.instance.addObserver(observation);
    addTearDown(() {
      WidgetsBinding.instance.removeObserver(observation);
      ApiClient.setToken(null);
    });

    Future<void> until(bool Function() ready) async {
      final deadline = DateTime.now().add(const Duration(seconds: 45));
      while (!ready() && DateTime.now().isBefore(deadline)) {
        await $.pump(const Duration(milliseconds: 50));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(ready(), isTrue, reason: 'Session/lifecycle readiness timed out');
    }

    Future<void> save(bool complete) async {
      // The collector is outside measured windows; never export JWTs/passwords.
      final response =
          await client.post(Uri.parse('${ApiClient.baseUrl}/benchmark/results'),
              headers: {
                'content-type': 'application/json',
                'authorization': 'Bearer ${manifest['smallViewer']}'
              },
              body: jsonEncode({
                'complete': complete,
                'method': method,
                'samples': samples,
                'memory_samples': memory
              }));
      expect(response.statusCode, 200);
    }

    Future<void> runCycle(int repetition, int size) async {
      final index = size == 20 ? 0 : 1;
      var viewer = manifest[size == 20 ? 'smallViewer' : 'largeViewer'];
      final phases = <String, int>{};
      final movies = MovieService();
      _LifecycleAuth? auth;
      AnalyticsController? analytics;
      AppearanceController? appearance;
      ChatUnreadController? chat;
      WatchRequestCache? plans;
      VoidCallback? authObserver;
      addTearDown(() => auth?.dispose());

      Future<void> unmount() async {
        await $.pumpWidgetAndSettle(const SizedBox.shrink());
        auth?.dispose();
        auth = null;
        analytics?.dispose();
        appearance?.dispose();
        chat?.dispose();
        plans?.dispose();
        await until(() => active == 0);
      }

      void resetCaches() {
        movies.clearCache();
        ShowService.clearSummaryCache();
        RecommendationService.invalidateCache();
        // Patrol files live outside test/, but this is a native test.
        // ignore: invalid_use_of_visible_for_testing_member
        HomeScreen.clearSessionSnapshotForTesting();
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      }

      Future<void> mount() async {
        appearance =
            AppearanceController(await SharedPreferences.getInstance());
        analytics = AnalyticsController(
            backend: RuntimeAnalyticsBackend(),
            consentStore: RuntimeAnalyticsConsentStore());
        await analytics!.initialize();
        auth =
            _LifecycleAuth(_LifecycleService(firebase, phases), movies, phases);
        if (authObserver != null) auth!.addListener(authObserver!);
        plans = WatchRequestCache();
        chat = ChatUnreadController();
        await $.pumpWidget(MultiProvider(providers: [
          ChangeNotifierProvider<AppearanceController>.value(
              value: appearance!),
          ChangeNotifierProvider<AnalyticsController>.value(value: analytics!),
          Provider<MovieService>.value(value: movies),
          ChangeNotifierProvider<AuthProvider>.value(value: auth!),
          ChangeNotifierProvider<MovieRatingPrivacy>.value(
              value: MovieRatingPrivacy.instance),
          ChangeNotifierProvider<ChatUnreadController>.value(value: chat!),
          ChangeNotifierProvider<WatchRequestCache>.value(value: plans!),
        ], child: const FlixieApp()));
      }

      Future<void> measure(String scenario, Future<void> Function() action,
          bool Function() ready,
          {bool signedOut = false}) async {
        await until(() => active == 0);
        requests.clear();
        client.responses.clear();
        client.transportErrors.clear();
        phases.clear();
        maxActive = 0;
        final frames = <FrameTiming>[];
        void collect(List<FrameTiming> batch) => frames.addAll(batch);
        SchedulerBinding.instance.addTimingsCallback(collect);
        final startRss = ProcessInfo.currentRss;
        var peakRss = startRss;
        final poll = Timer.periodic(const Duration(milliseconds: 20), (_) {
          if (ProcessInfo.currentRss > peakRss) {
            peakRss = ProcessInfo.currentRss;
          }
        });
        final watch = Stopwatch()..start();
        int? authReadyUs;
        void observeAuth() {
          if (auth?.status == AuthStatus.authenticated) {
            authReadyUs ??= watch.elapsedMicroseconds;
          }
        }

        observation.watch = watch;
        observation.resumedUs = null;
        authObserver = observeAuth;
        auth?.addListener(observeAuth);
        try {
          await action();
          observeAuth();
          await until(ready);
          if (signedOut) {
            await $(LoginScreen).waitUntilVisible();
          } else {
            await $(HomeScreen).waitUntilVisible();
            // Home's fixture title can sit below the fold after the plan preview.
            // Verify the visible Home action and loaded title separately.
            await $(HomeWatchlistAction).waitUntilVisible();
            await until(() => find.text('Alien').evaluate().isNotEmpty);
            expect(find.text('Alien'), findsWidgets);
            expect(auth!.dbUser!.id, viewer);
            expect(auth!.dbUser!.movieWatchlist!.length,
                viewer == manifest['smallViewer'] ? 20 : 400);
            expect(auth!.termsVerified, isTrue);
            expect(auth!.recoveryError, isNull);
          }
          final usefulUs = watch.elapsedMicroseconds;
          await $.pumpAndSettle();
          await until(() => active == 0 && !auth!.isPrefetching);
          await $.pump(const Duration(milliseconds: 100));
          await until(() => active == 0);
          final settledUs = watch.elapsedMicroseconds;
          expect($.tester.takeException(), isNull);
          await Future<void>.delayed(const Duration(milliseconds: 600));
          samples.add({
            'scenario': scenario,
            'library_size': size,
            'repetition': repetition,
            'useful_content_us': usefulUs,
            'settled_us': settledUs,
            'auth_ready_observed_us': authReadyUs,
            'native_resumed_us': observation.resumedUs,
            'phases_us': Map<String, int>.from(phases),
            'requests': Map<String, int>.from(requests),
            'response_statuses': {
              for (final entry in client.responses.entries)
                entry.key: Map<String, int>.from(entry.value)
            },
            'transport_errors': {
              for (final entry in client.transportErrors.entries)
                entry.key: List<String>.of(entry.value),
            },
            'max_active_http': maxActive,
            'rss_start_bytes': startRss,
            'rss_peak_bytes': peakRss,
            'rss_end_bytes': ProcessInfo.currentRss,
            'image_cache_bytes':
                PaintingBinding.instance.imageCache.currentSizeBytes,
            'frame_build_us':
                frames.map((f) => f.buildDuration.inMicroseconds).toList(),
            'frame_raster_us':
                frames.map((f) => f.rasterDuration.inMicroseconds).toList(),
            'display_refresh_hz': WidgetsBinding
                .instance.platformDispatcher.views.first.display.refreshRate,
          });
        } catch (error) {
          // Fixture-only diagnostics on failure; no tokens or passwords.
          method['failed_condition'] = {
            'scenario': scenario,
            'library_size': size,
            'repetition': repetition,
            'phases': Map<String, int>.from(phases),
            'requests': Map<String, int>.from(requests),
            'response_statuses': client.responses,
            'transport_errors': client.transportErrors,
            'text': $.tester
                .widgetList<Text>(find.byType(Text))
                .map((text) => text.data)
                .whereType<String>()
                .take(80)
                .toList(),
          };
          await save(false);
          rethrow;
        } finally {
          auth?.removeListener(observeAuth);
          authObserver = null;
          poll.cancel();
          SchedulerBinding.instance.removeTimingsCallback(collect);
          observation.watch = null;
        }
        await save(false);
      }

      await firebase.signOut();
      await firebase.signInWithEmailAndPassword(
          email: 'runtime_$index@example.invalid',
          password: 'RuntimeFixture1!');
      resetCaches();
      if (accounts) {
        await mount();
        await until(() => auth?.status == AuthStatus.authenticated);
        await $(HomeScreen).waitUntilVisible();
        // Home's fixture title can sit below the fold after the plan preview.
            // Verify the visible Home action and loaded title separately.
            await $(HomeWatchlistAction).waitUntilVisible();
            await until(() => find.text('Alien').evaluate().isNotEmpty);
            expect(find.text('Alien'), findsWidgets);
        await until(() => active == 0 && !auth!.isPrefetching);
        await $.pumpAndSettle();
        await profile('signed_in', size, repetition);
        await measure(
            'logout',
            () => auth!.signOut(),
            () =>
                auth?.status == AuthStatus.unauthenticated &&
                firebase.currentUser == null,
            signedOut: true);
        expect(auth!.dbUser, isNull);
        expect(auth!.cachedFriends, isNull);
        expect(auth!.cachedMovieLists, isNull);
        await profile('logged_out', size, repetition);
        viewer = manifest[size == 20 ? 'largeViewer' : 'smallViewer'];
        final targetIndex = 1 - index;
        await $(find.byType(TextFormField).at(0))
            .enterText('runtime_$targetIndex@example.invalid');
        await $(find.byType(TextFormField).at(1)).enterText('RuntimeFixture1!');
        FocusManager.instance.primaryFocus?.unfocus();
        await $.pumpAndSettle();
        await measure('account_switch_login', () => $('Sign In').tap(),
            () => auth?.status == AuthStatus.authenticated);
        expect(phases['profile_calls'], 1);
        await profile('switched', size, repetition);
        await auth!.signOut();
        await until(
            () => auth?.status == AuthStatus.unauthenticated && active == 0);
        await $(LoginScreen).waitUntilVisible();
        await $.pumpAndSettle();
        await unmount();
        await Future<void>.delayed(const Duration(milliseconds: 600));
        await $.pumpAndSettle();
        await profile('unmounted', size, repetition);
        return;
      }
      await measure('startup_signed_in', mount,
          () => auth?.status == AuthStatus.authenticated);

      var version = auth!.activityVersion;
      await $.platform.mobile.pressHome();
      await Future<void>.delayed(const Duration(seconds: 1));
      await measure(
          'resume_refresh',
          () => $.platform.mobile.openApp(),
          () =>
              observation.resumedUs != null && auth!.activityVersion > version);
      // Home must reuse the profile refreshed by native resume recovery.
      expect(requests['GET /users/external-id/$viewer'], 1);
      expect(phases['profile_calls'], 1);
      version = auth!.activityVersion;
      await $.platform.mobile.pressHome();
      await Future<void>.delayed(const Duration(seconds: 1));
      await measure('resume_throttled', () => $.platform.mobile.openApp(),
          () => observation.resumedUs != null);
      expect(auth!.activityVersion, version);
      expect(requests['GET /users/external-id/$viewer'] ?? 0, 0);

      await unmount();
      await firebase.signOut();
      resetCaches();
      await measure('startup_signed_out', mount,
          () => auth?.status == AuthStatus.unauthenticated,
          signedOut: true);
      await $(find.byType(TextFormField).at(0))
          .enterText('runtime_$index@example.invalid');
      await $(find.byType(TextFormField).at(1)).enterText('RuntimeFixture1!');
      FocusManager.instance.primaryFocus?.unfocus();
      await $.pumpAndSettle();
      resetCaches();
      await measure('email_login', () => $('Sign In').tap(),
          () => auth?.status == AuthStatus.authenticated);
      expect(phases['firebase_email_sign_in_us'], greaterThan(0));
      expect(requests['GET /users/external-id/$viewer'], 1);
      expect(requests['GET /users/me/terms'], 1);
      await unmount();
    }

    for (var repetition = 1; repetition <= 5; repetition++) {
      for (final size in [20, 400]) {
        await runCycle(repetition, size);
        if (accounts && retaining) {
          await Future<void>.delayed(const Duration(milliseconds: 600));
          await $.pumpAndSettle();
          await profile('post_cycle', size, repetition);
          await save(false);
          // Control: replace Flutter's last input connection with an empty field
          // whose ancestor tree has no account provider. No private VM mutation.
          final neutralFocus = FocusNode();
          await $.pumpWidget(MaterialApp(
              home: Scaffold(
                  body: TextField(autofocus: true, focusNode: neutralFocus))));
          await $.pump(const Duration(milliseconds: 300));
          expect(neutralFocus.hasFocus, isTrue,
              reason: 'Neutral input must focus');
          await $.pumpWidgetAndSettle(const SizedBox.shrink());
          await Future<void>.delayed(const Duration(milliseconds: 600));
          await $.pumpAndSettle();
          neutralFocus.dispose();
          await profile('post_input_replacement', size, repetition);
          final remaining = memory.last['instance_lookup_count'];
          await save(false);
          expect(remaining, 0,
              reason: 'Auth survives account-free input replacement');
        }
      }
    }
    expect(samples.length, accounts ? 20 : 50);
    await save(true);
    await firebase.signOut();
  }, timeout: const Timeout(Duration(minutes: 20)));
}
