// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:patrol_finders/patrol_finders.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/app/theme/appearance_controller.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/auth/auth_service.dart';
import 'package:flixie_app/core/auth/firebase_environment.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/core/storage/movie_cache_service.dart';
import 'package:flixie_app/features/authentication/presentation/pages/signup_screen.dart';
import 'package:flixie_app/features/authentication/presentation/pages/signup_avatar_step.dart';
import 'package:flixie_app/features/guest/presentation/guest_access.dart';
import 'package:flixie_app/features/guest/presentation/guest_home_screen.dart';
import 'package:flixie_app/features/library_import/data/library_import_session.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/movies/data/show_service.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'package:flixie_app/features/social/data/chat_unread_controller.dart';
import 'package:flixie_app/features/social/data/watch_request_cache.dart';
import 'package:flixie_app/main.dart' show FlixieApp;
import 'runtime_database_fixture.dart'
    show RuntimeAnalyticsBackend, RuntimeAnalyticsConsentStore;

class _LocalHttp extends HttpOverrides {}

/// A real local transport with bounded, opt-in faults. Successful requests go
/// to the local API, and assertions independently re-read persisted server data.
class SignupFaultClient extends http.BaseClient {
  final http.Client inner = IOClient(HttpClient());
  bool Function(http.BaseRequest)? failNext;
  bool loseNextLogReply = false;
  final requests = <(String, String)>[];
  final profileBodies = <Map<String, dynamic>>[];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add((request.method, request.url.path));
    if (request.method == 'POST' &&
        request.url.path.replaceAll(RegExp(r'/$'), '') == '/users' &&
        request is http.Request) {
      profileBodies
          .add(Map<String, dynamic>.from(jsonDecode(request.body) as Map));
    }
    if (failNext?.call(request) == true) {
      failNext = null;
      return http.StreamedResponse(
          Stream.value(
              utf8.encode('{"error":"Isolated signup fixture outage"}')),
          503,
          headers: {'content-type': 'application/json'});
    }
    final response = await inner.send(request);
    if (loseNextLogReply &&
        request.method == 'POST' &&
        request.url.path.endsWith('/watch-requests/log-watch')) {
      loseNextLogReply = false;
      await response.stream.drain<void>();
      return http.StreamedResponse(
          Stream.value(
              utf8.encode('{"error":"Isolated lost response after commit"}')),
          503,
          headers: {'content-type': 'application/json'});
    }
    return response;
  }

  @override
  void close() => inner.close();
}

class LocalSignupJourney {
  LocalSignupJourney(this.$);
  final PatrolTester $;
  late AuthProvider auth;
  late SignupFaultClient transport;
  late String username;
  static int _sequence = 0;
  static const password = 'LocalSignup7!';
  BuildContext get context => $.tester.element(find.byType(Scaffold).first);
  GoRouter get router => GoRouter.of(context);
  Future<void> until(bool Function() ready, String reason) async {
    bool present() {
      try {
        return ready();
      } on StateError {
        // Finder.first throws while a route's widget has not mounted yet.
        return false;
      }
    }

    final deadline = DateTime.now().add(const Duration(seconds: 50));
    while (!present() && DateTime.now().isBefore(deadline)) {
      await $.pump(const Duration(milliseconds: 150));
    }
    expect(present(), true, reason: reason);
    await $.pump();
  }

  Future<T> io<T>(Future<T> Function() action) async =>
      (await $.tester.runAsync(action)) as T;
  Future<void> tap(Finder finder) async {
    await until(() => finder.evaluate().isNotEmpty, 'tap target mounted');
    await $.tester.ensureVisible(finder.first);
    await $.pump(const Duration(milliseconds: 300));
    await until(
        () => finder.evaluate().isNotEmpty, 'tap target remains mounted');
    await $.tester.tap(finder.first);
    await $.pump(const Duration(milliseconds: 300));
  }

  Future<void> text(Finder finder, String value) async {
    await until(() => finder.evaluate().isNotEmpty, 'input target mounted');
    await $.tester.ensureVisible(finder);
    await $.tester.enterText(finder, value);
    await $.pump();
  }

  Future<void> open(String path) async {
    router.go(path);
    await $.pump();
  }

  Future<void> start({AuthService Function()? authServiceFactory}) async {
    expect(FirebaseEnvironment.useEmulators, true);
    final api = Uri.parse(ApiClient.baseUrl);
    expect(api.scheme, 'http');
    expect(api.host, '127.0.0.1');
    HttpOverrides.global = _LocalHttp();
    SharedPreferences.setMockInitialValues(
        {'analytics_consent_v2': 'declined', 'guest_welcome_seen_v1': true});
    GuestAccess.clear();
    MovieCacheService().clearCache();
    ShowService.clearSummaryCache();
    await io(() async {
      if (!Firebase.apps.any((app) => app.name == 'flixie-local')) {
        await FirebaseEnvironment.initializeLocal();
      }
      await FirebaseEnvironment.auth.signOut();
    });
    ApiClient.setToken(null);
    transport = SignupFaultClient();
    ApiClient.useClientForTesting(transport);
    final appearance =
        AppearanceController(await SharedPreferences.getInstance());
    final analytics = AnalyticsController(
        backend: RuntimeAnalyticsBackend(),
        consentStore: RuntimeAnalyticsConsentStore());
    await analytics.initialize();
    final movies = MovieService();
    auth = AuthProvider(authServiceFactory?.call() ?? AuthService(), movies);
    final chat = ChatUnreadController();
    final plans = WatchRequestCache();
    final imports = LibraryImportSession();
    auth.addListener(() {
      chat.syncUser(auth.dbUser?.id);
      plans.syncUser(auth.dbUser?.id, deferWarm: true);
      imports.syncUser(auth.dbUser?.id);
      MovieRatingPrivacy.instance.syncUser(auth.dbUser?.id);
    });
    addTearDown(() async {
      ApiClient.useClientForTesting(null);
      transport.close();
      auth.dispose();
      chat.dispose();
      plans.dispose();
      imports.dispose();
      appearance.dispose();
      analytics.dispose();
      GuestAccess.clear();
    });
    await $.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<AppearanceController>.value(value: appearance),
      ChangeNotifierProvider<AnalyticsController>.value(value: analytics),
      Provider<MovieService>.value(value: movies),
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<MovieRatingPrivacy>.value(
          value: MovieRatingPrivacy.instance),
      ChangeNotifierProvider<ChatUnreadController>.value(value: chat),
      ChangeNotifierProvider<WatchRequestCache>.value(value: plans),
      ChangeNotifierProvider<LibraryImportSession>.value(value: imports),
    ], child: const FlixieApp()));
    await until(() => find.byType(GuestHomeScreen).evaluate().isNotEmpty,
        'real guest Home');
  }

  Future<void> chooseSignup() async {
    final create = find.byWidgetPredicate((w) =>
        w is FilledButton &&
        w.child is Text &&
        ((w.child as Text).data ?? '').startsWith('Create account'));
    await until(
        () =>
            create.evaluate().isNotEmpty ||
            find.text('View picks').evaluate().isNotEmpty,
        'contextual signup or guest saved pick');
    if (create.evaluate().isEmpty) {
      await open('/guest-watchlist');
    }
    await until(
        () => create.evaluate().isNotEmpty, 'contextual create-account action');
    await tap(create);
    await until(
        () => find.byType(SignupScreen).evaluate().isNotEmpty, 'signup form');
  }

  Finder get formFields => find.descendant(
      of: find.byType(SignupScreen),
      matching: find.byType(TextFormField, skipOffstage: false),
      skipOffstage: false);
  Future<void> fillSignup(
      {bool validateFirst = false,
      String? referral,
      bool retryProfileFailure = false}) async {
    username = 'sj${DateTime.now().millisecondsSinceEpoch}${++_sequence}';
    expect(username.length, lessThanOrEqualTo(20));
    await until(() => formFields.evaluate().length == 6, 'email signup fields');
    expect(formFields, findsNWidgets(6));
    if (validateFirst) {
      await text(formFields.at(0), 'Signup Fixture');
      await text(formFields.at(1), username);
      await text(formFields.at(2), '$username@example.invalid');
      await text(formFields.at(4), 'weak');
      await text(formFields.at(5), 'different');
      await tap(find.text('I agree to the Terms of Use'));
      await tap(find.text('Continue').first);
      await $.pump();
      expect(
          find.text('Password must be at least 8 characters.'), findsOneWidget);
      expect(find.byType(SignupAvatarStep), findsNothing);
      expect(auth.dbUser, isNull);
    }
    for (final entry in [
      (0, 'Signup Fixture'),
      (1, username),
      (2, '$username@example.invalid'),
      (4, password),
      (5, password)
    ]) {
      await text(formFields.at(entry.$1), entry.$2);
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await $.pump();
    if (referral != null) {
      await tap(find.text('Referred by a friend?'));
      await text(formFields.at(3), referral);
      await until(
          () => find.textContaining('referred you').evaluate().isNotEmpty,
          'referral code/username resolves before submission');
    }
    if (!validateFirst) await tap(find.text('I agree to the Terms of Use'));
    await tap(find.text('Continue').first);
    if (retryProfileFailure) {
      await until(() => auth.errorMessage != null,
          'profile API failure shown without losing signup draft');
      expect(find.byType(SignupScreen), findsOneWidget);
      expect(auth.dbUser, isNull);
      final uid = FirebaseEnvironment.auth.currentUser!.uid;
      await tap(find.text('Continue').first);
      await until(() => auth.isAuthenticated,
          'profile retry uses existing Firebase identity');
      expect(FirebaseEnvironment.auth.currentUser!.uid, uid);
    }
    await completeAvatar();
  }

  Future<void> fillSocialProfile() async {
    username = 'soc${DateTime.now().millisecondsSinceEpoch}${++_sequence}';
    await until(
        () => formFields.evaluate().length == 3, 'social profile fields');
    expect(formFields, findsNWidgets(3));
    expect(find.text('Password'), findsNothing);
    await text(formFields.at(0), 'Social Fixture');
    await text(formFields.at(1), username);
    await tap(find.text('I agree to the Terms of Use'));
    await tap(find.text('Continue').first);
    await completeAvatar();
  }

  Future<void> completeAvatar() async {
    await until(() => auth.isAuthenticated && !auth.needsSocialProfile,
        'account completes without mandatory avatar selection');
    expect(find.byType(SignupAvatarStep), findsNothing);
    expect(auth.dbUser!.username, username);
  }

  Future<void> finishWith(String label) async {
    await tap(find.text(label).first);
    await until(() => auth.dbUser?.completedSetup == true,
        'setup completion persisted');
  }
}
