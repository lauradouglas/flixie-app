import 'package:go_router/go_router.dart';
import 'package:flixie_app/features/authentication/presentation/pages/signup_journey_page.dart';
import 'package:flixie_app/features/authentication/presentation/widgets/onboarding/onboarding_services_step.dart';
import 'package:flixie_app/features/watchlist/presentation/pages/watchlist_screen.dart';
import 'dart:convert';
import 'dart:io';
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
import 'package:flixie_app/features/movies/presentation/pages/search_screen.dart';
import 'package:flixie_app/features/movies/presentation/widgets/search/search_content.dart';
import 'package:flixie_app/features/movies/presentation/pages/movie_detail_screen.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/main.dart' as app;

class _LocalHttp extends HttpOverrides {}

void main() {
  patrolTest('real local guest bookmarks Alien, signs up, saves before setup',
      ($) async {
    // Hide the test-name overlay so native captures show the actual app UI.
    // ignore: invalid_use_of_protected_member
    ($.tester.binding as LiveTestWidgetsFlutterBinding).setLabel('');
    expect(FirebaseEnvironment.useEmulators, true);
    expect(Uri.parse(ApiClient.baseUrl).host, '127.0.0.1');
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
        final request = await client.postUrl(Uri.parse('$host/capture/$stage'));
        final response = await request.close();
        expect(response.statusCode, 200,
            reason: await utf8.decoder.bind(response).join());
      } finally {
        client.close(force: true);
      }
    }

    await $.tester.runAsync(() async {
      await FirebaseEnvironment.initializeLocal();
      await FirebaseEnvironment.auth.signOut();
      await app.main();
    });
    await until(
        () =>
            find.text('Search movies, shows and people').evaluate().isNotEmpty,
        'guest Home');
    await $.tester.tap(find.text('Search movies, shows and people'));
    await until(
        () => find.byType(SearchScreen).evaluate().isNotEmpty, 'search');
    await $.tester.enterText(find.byType(TextField).first, 'Alien');
    await $.tester.testTextInput.receiveAction(TextInputAction.search);
    final alienResult = find.byWidgetPredicate(
        (widget) => widget is SearchHighlightedText && widget.text == 'Alien');
    await until(
        () => alienResult.evaluate().isNotEmpty, 'real Alien search result');
    await $.tester.ensureVisible(alienResult.first);
    await $.tester.tap(alienResult.first);
    await until(
        () =>
            find.byType(MovieDetailScreen).evaluate().isNotEmpty &&
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
        () => find.text('Create account & keep my picks').evaluate().isNotEmpty,
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
    final username = 'devbm_$suffix';
    expect(username.length, lessThanOrEqualTo(20));
    final fields = find.descendant(
        of: find.byType(SignupScreen),
        matching: find.byType(TextFormField, skipOffstage: false),
        skipOffstage: false);
    expect(fields, findsNWidgets(6));
    for (final entry in [
      (0, 'Bookmark Fixture'),
      (1, username),
      (2, '$username@example.invalid'),
      (4, 'LocalBookmark7!'),
      (5, 'LocalBookmark7!')
    ]) {
      await $.tester.ensureVisible(fields.at(entry.$1));
      await $.tester.enterText(fields.at(entry.$1), entry.$2);
    }
    await $.tester.testTextInput.receiveAction(TextInputAction.done);
    await $.pump();
    await $.tester.ensureVisible(find.text('I agree to the Terms of Use'));
    await $.tester.tap(find.text('I agree to the Terms of Use'));
    await $.tester.ensureVisible(find.text('Continue').first);
    await $.tester.tap(find.text('Continue').first);
    await until(
        () => find.text('Anything else for later?').evaluate().isNotEmpty,
        'saved confirmation before optional extras');
    expect(find.byType(OnboardingScreen), findsNothing);
    final context = $.tester.element(find.byType(SignupJourneyPage));
    final auth = context.read<AuthProvider>();
    expect(auth.dbUser!.username, username);
    expect(auth.dbUser!.completedSetup, false);
    await capture('04-saved');
    // Re-read server state, independently of the optimistic UI collection.
    final persisted =
        await $.tester.runAsync(() => UserService.getUserById(auth.dbUser!.id));
    expect(persisted!.completedSetup, false);
    expect(
        persisted.movieWatchlist!.where((entry) => entry.movieId == 348).length,
        1);
    await $.tester.tap(find.text('Continue').first);
    await until(() => find.byType(OnboardingServicesStep).evaluate().isNotEmpty,
        'existing provider selector after original save');
    await capture('05-optional-setup');
    expect(auth.dbUser!.completedSetup, false);
    await $.tester.ensureVisible(find.text('Skip for now'));
    await $.tester.tap(find.text('Skip for now'));
    await until(() => find.byType(WatchlistScreen).evaluate().isNotEmpty,
        'saved title in the usable watchlist');
    expect(auth.dbUser!.completedSetup, true);
    expect(
        auth.dbUser!.movieWatchlist!
            .where((entry) => entry.movieId == 348)
            .length,
        1);
    debugPrint(
        'BOOKMARK_LOCAL_VERIFIED: guest -> contextual signup -> avatar -> persisted Alien once -> optional providers skipped -> usable watchlist');
  }, timeout: const Timeout(Duration(minutes: 8)));
}
