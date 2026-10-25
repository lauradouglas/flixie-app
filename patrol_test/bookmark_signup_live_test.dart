// Explicitly opt-in live tests. Each creates and cleans up its own fictional account.
// Never part of the local aggregate suite; no existing account credentials.
import 'package:flixie_app/features/authentication/presentation/pages/signup_journey_page.dart';
import 'package:flixie_app/features/authentication/presentation/widgets/onboarding/onboarding_services_step.dart';
import 'package:flixie_app/features/watchlist/presentation/pages/watchlist_screen.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:go_router/go_router.dart';
import 'package:flixie_app/features/movies/presentation/pages/show_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/auth/firebase_environment.dart';
import 'package:flixie_app/features/authentication/presentation/pages/signup_screen.dart';
import 'package:flixie_app/features/authentication/presentation/pages/onboarding_screen.dart';
import 'package:flixie_app/features/movies/presentation/pages/movie_detail_screen.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/main.dart' as app;

class _LocalHttp extends HttpOverrides {}

void main() {
  for (final isShow in [false, true]) {
    final title = isShow ? 'Breaking Bad' : 'Alien';
    patrolTest(
        'LIVE email signup saves $title before setup, survives sign-in, then cleans up',
        ($) async {
      // Hide the test-name overlay so native captures show the actual app UI.
      // ignore: invalid_use_of_protected_member
      ($.tester.binding as LiveTestWidgetsFlutterBinding).setLabel('');
      expect(const bool.fromEnvironment('ALLOW_LIVE_SIGNUP_TEST'), true);
      expect(FirebaseEnvironment.useEmulators, false);
      final api = Uri.parse(ApiClient.baseUrl);
      expect(api.scheme, 'https');
      expect(api.host,
          'flixie-api-fmcehvaecwdheccm.northeurope-01.azurewebsites.net');
      HttpOverrides.global = _LocalHttp();
      // Isolated preferences; the dedicated simulator is reinstalled by Patrol.
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues(
          {'analytics_consent_v2': 'declined', 'guest_welcome_seen_v1': true});
      Future<void> until(bool Function() ready, String reason) async {
        final deadline = DateTime.now().add(const Duration(seconds: 60));
        while (!ready() && DateTime.now().isBefore(deadline)) {
          await $.pump(const Duration(milliseconds: 200));
        }
        expect(ready(), true, reason: reason);
      }

      Future<void> capture(String stage) async {
        const host = String.fromEnvironment('BOOKMARK_CAPTURE_HOST');
        if (host.isEmpty) return;
        final client = HttpClient();
        try {
          final request =
              await client.postUrl(Uri.parse('$host/capture/$stage'));
          final response = await request.close();
          expect(response.statusCode, 200,
              reason: await utf8.decoder.bind(response).join());
        } finally {
          client.close(force: true);
        }
      }

      await $.tester.runAsync(() async {
        await Firebase.initializeApp();
        expect(FirebaseEnvironment.app.options.projectId, 'flixie-9a8eb');
        await FirebaseEnvironment.auth.signOut();
        await app.main();
      });
      await until(
          () => find
              .text('Search movies, shows and people')
              .evaluate()
              .isNotEmpty,
          'guest Home');
      GoRouter.of($.tester.element(find.byType(Scaffold).first))
          .go(isShow ? '/shows/1396' : '/movies/348');
      await $.pump();
      await until(
          () =>
              find
                  .byType(isShow ? ShowDetailScreen : MovieDetailScreen)
                  .evaluate()
                  .isNotEmpty &&
              find.text('Watchlist').evaluate().isNotEmpty,
          'Alien detail');
      await $.tester.ensureVisible(find.text('Watchlist').first);
      await $.tester.tap(find.text('Watchlist').first);
      await until(() => find.text('View picks').evaluate().isNotEmpty,
          'guest pick saved');
      GoRouter.of($.tester.element(find.byType(Scaffold).first))
          .go('/guest-watchlist');
      await $.pump();
      await until(
          () =>
              find.text('Create account & keep my picks').evaluate().isNotEmpty,
          'guest collection');
      await capture('01-guest-picks');
      await $.tester.ensureVisible(find.text('Create account & keep my picks'));
      await $.tester.tap(find.text('Create account & keep my picks'));
      await until(
          () => find.byType(SignupScreen).evaluate().isNotEmpty, 'signup');
      expect(find.text('Keep your picks'), findsOneWidget);
      debugPrint('BOOKMARK_STAGE: signup reminder');
      await capture('02-signup');
      final suffix = DateTime.now().millisecondsSinceEpoch.toString();
      final username = 'livebm_$suffix';
      final email = '$username@example.invalid';
      final random = Random.secure();
      final password =
          '${base64Url.encode(List.generate(24, (_) => random.nextInt(256)))}Aa7!';
      expect(username.length, lessThanOrEqualTo(20));
      final auth =
          $.tester.element(find.byType(SignupScreen)).read<AuthProvider>();
      debugPrint('LIVE_SIGNUP_TEST_STARTED: $username; title: $title');
      String? createdUid;
      bool cleaned = false;
      Future<void> cleanup() async {
        if (cleaned) return;
        await $.tester.runAsync(() async {
          final sdk = FirebaseEnvironment.auth;
          if (sdk.currentUser == null && createdUid == null) return;
          if (sdk.currentUser == null) {
            expect(await auth.signIn(email, password), true);
          }
          expect(sdk.currentUser!.email, email);
          if (auth.dbUser == null) {
            try {
              auth.updateDbUser(
                  await UserService.getUserByExternalId(sdk.currentUser!.uid));
            } on ApiException catch (error) {
              if (error.statusCode != 404) rethrow;
            }
          }
          if (auth.dbUser != null) {
            expect(auth.dbUser!.username, username);
            expect(await auth.deleteAccount(password), isNull,
                reason:
                    'Delete only this newly created fictional test account');
          } else {
            await sdk.currentUser!.delete();
            await sdk.signOut();
          }
          ApiClient.setToken(null);
          expect(await UserService.usernameExists(username), false);
          try {
            await sdk.signInWithEmailAndPassword(
                email: email, password: password);
            fail('Deleted fictional Firebase identity still accepts sign-in');
          } on fb.FirebaseAuthException catch (error) {
            expect(error.code, anyOf('invalid-credential', 'user-not-found'));
          }
          cleaned = true;
          debugPrint('LIVE_SIGNUP_CLEANED: $username');
        });
      }

      addTearDown(cleanup);
      final fields = find.descendant(
          of: find.byType(SignupScreen),
          matching: find.byType(TextFormField, skipOffstage: false),
          skipOffstage: false);
      expect(fields, findsNWidgets(6));
      for (final entry in [
        (0, 'Live Signup Test'),
        (1, username),
        (2, email),
        (4, password),
        (5, password)
      ]) {
        await $.tester.ensureVisible(fields.at(entry.$1));
        await $.tester.enterText(fields.at(entry.$1), entry.$2);
      }
      FocusManager.instance.primaryFocus?.unfocus();
      await $.pump();
      await $.tester.ensureVisible(find.text('I agree to the Terms of Use'));
      await $.tester.tap(find.text('I agree to the Terms of Use'));
      await $.tester.ensureVisible(find.text('Continue').first);
      await $.tester.tap(find.text('Continue').first);
      // Registration now proceeds directly to the saved-title payoff.
      await until(
          () => find.text('Anything else for later?').evaluate().isNotEmpty,
          'saved confirmation before optional extras');
      createdUid = FirebaseEnvironment.auth.currentUser!.uid;
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(SignupJourneyPage), findsOneWidget);
      expect(auth.dbUser!.username, username);
      expect(auth.dbUser!.completedSetup, false);
      await capture('04-saved');
      // Re-read server state, independently of the optimistic UI collection.
      final persisted = await $.tester
          .runAsync(() => UserService.getUserById(auth.dbUser!.id));
      expect(persisted!.completedSetup, false);
      expect(
          isShow
              ? (persisted.showWatchlist ?? [])
                  .where((e) => e is Map && '${e['showId']}' == '1396')
                  .length
              : persisted.movieWatchlist!
                  .where((entry) => entry.movieId == 348)
                  .length,
          1);
      await $.tester.tap(find.text('Continue').first);
      await until(
          () => find.byType(OnboardingServicesStep).evaluate().isNotEmpty,
          'existing provider selector after original save');
      await capture('05-optional-setup');
      expect(auth.dbUser!.completedSetup, false);
      await $.tester.ensureVisible(find.text('Skip for now'));
      await $.tester.tap(find.text('Skip for now'));
      await until(() => find.byType(WatchlistScreen).evaluate().isNotEmpty,
          'saved title in the usable watchlist');
      expect(auth.dbUser!.completedSetup, true);
      expect(
          isShow
              ? (auth.dbUser!.showWatchlist ?? [])
                  .where((e) => e is Map && '${e['showId']}' == '1396')
                  .length
              : auth.dbUser!.movieWatchlist!
                  .where((entry) => entry.movieId == 348)
                  .length,
          1);
      final userId = auth.dbUser!.id;
      await $.tester.runAsync(auth.signOut);
      expect(auth.dbUser, isNull);
      final signedIn =
          await $.tester.runAsync(() => auth.signIn(email, password));
      expect(signedIn, true);
      expect(auth.dbUser!.id, userId);
      final restored =
          await $.tester.runAsync(() => UserService.getUserById(userId));
      expect(
          isShow
              ? (restored!.showWatchlist ?? [])
                  .where((e) => e is Map && '${e['showId']}' == '1396')
              : restored!.movieWatchlist!.where((e) => e.movieId == 348),
          hasLength(1));
      expect(restored.completedSetup, true);
      debugPrint('LIVE_SIGNUP_TEST_ACCOUNT: $username; backend id: $userId');
      debugPrint(
          'BOOKMARK_LIVE_VERIFIED: guest -> contextual signup -> avatar -> persisted $title once -> optional providers skipped -> usable watchlist');
      await cleanup();
    },
        skip: !const bool.fromEnvironment('ALLOW_LIVE_SIGNUP_TEST'),
        timeout: const Timeout(Duration(minutes: 8)));
  }
}
