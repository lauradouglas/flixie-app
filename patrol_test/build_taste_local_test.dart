import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/features/authentication/presentation/pages/signup_journey_page.dart';
import 'package:flixie_app/features/home/presentation/pages/home_screen.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/features/taste/presentation/pages/build_taste_page.dart';
import 'package:flixie_app/features/taste/data/taste_setup_store.dart';
import 'support/signup_local_journey.dart';
import 'signup_journeys_local_test.dart' show titleEntry;

void main() {
  patrolTest(
      'first save -> optional Home taste card -> Profile resume -> favourites and rating -> discovery',
      ($) async {
    final h = LocalSignupJourney($);
    await h.start();
    Future<void> capture(String stage) async {
      const host = String.fromEnvironment('SIGNUP_SCREENSHOT_HOST');
      if (host.isEmpty) return;
      // ignore: invalid_use_of_protected_member
      ($.tester.binding as LiveTestWidgetsFlutterBinding).setLabel('');
      ScaffoldMessenger.maybeOf(h.context)?.clearSnackBars();
      await $.pump(const Duration(milliseconds: 500));
      await h.io(() async {
        final c = HttpClient();
        try {
          final req = await c.postUrl(Uri.parse('$host/capture'));
          req.headers.set('X-Capture-Token',
              const String.fromEnvironment('SIGNUP_SCREENSHOT_TOKEN'));
          req.headers.contentType = ContentType.json;
          req.write(jsonEncode({
            'device': 'phone',
            'flow': 'build-taste',
            'step': stage,
            'part': 1,
            'name': 'build-taste-$stage-1'
          }));
          final res = await req.close();
          expect(res.statusCode, 200);
          await res.drain<void>();
        } finally {
          c.close(force: true);
        }
      });
    }

    await titleEntry(h, 'watchlist');
    await h.fillSignup();
    await h.until(
        () => find.text('Anything else for later?').evaluate().isNotEmpty,
        'original Alien save');
    var user = await h.io(() => UserService.getUserById(h.auth.dbUser!.id));
    expect(user.movieWatchlist!.where((m) => m.movieId == 348), hasLength(1));
    expect(await const TasteSetupStore().eligible(user.id), true);
    await h.tap(find.descendant(
        of: find.byType(SignupJourneyPage), matching: find.text('Continue')));
    await h.finishWith('Skip for now');
    await h.open('/');
    await h.until(
        () =>
            find.byType(HomeScreen).evaluate().isNotEmpty &&
            find.text('More your kind of thing').evaluate().isNotEmpty,
        'optional Home card after saved action');
    await capture('01-home-card');
    await h.tap(find.text('Maybe later'));
    await $.pump();
    expect(find.text('More your kind of thing'), findsNothing);
    await h.open('/profile');
    await h.tap(find.text('Build your taste'));
    await h.until(
        () =>
            find.byType(BuildTastePage).evaluate().isNotEmpty &&
            find.text('Which films feel like you?').evaluate().isNotEmpty,
        'Profile opens optional taste');
    final tasteSearch = find.descendant(
        of: find.byType(BuildTastePage), matching: find.byType(TextField));
    await $(tasteSearch.first).scrollTo();
    await $(tasteSearch.first)
        .enterText('Alien', settlePolicy: SettlePolicy.noSettle);
    await $.pump(const Duration(milliseconds: 600));
    await h.tap(find.byTooltip('Add Alien to favourites'));
    await h.until(
        () => find
            .byTooltip('Remove Alien from favourites')
            .evaluate()
            .isNotEmpty,
        'favourite persisted');
    user = await h.io(() => UserService.getUserById(user.id));
    expect(
        user.favoriteMovies!
            .where((m) => m.movieId == 348 && m.removed != true),
        hasLength(1));
    await capture('02-favourite');
    await h.tap(find.text('Continue to ratings'));
    await h.until(
        () => find.text('Seen it? Give us your take.').evaluate().isNotEmpty,
        'rating picker reached');
    await $(tasteSearch.first).scrollTo();
    await $(tasteSearch.first)
        .enterText('Interstellar', settlePolicy: SettlePolicy.noSettle);
    expect($.tester.widget<TextField>(tasteSearch.first).controller!.text,
        'Interstellar');
    await $.pump(const Duration(milliseconds: 600));
    await h.tap(find.byTooltip('Rate Interstellar'));
    await h.until(
        () => find.text('How was Interstellar?').evaluate().isNotEmpty,
        'existing rating editor');
    await h.tap(find.widgetWithText(FlixiePill, '8'));
    await h.tap(find.widgetWithText(FlixiePill, 'Yes'));
    await capture('03-rating');
    await h.tap(find.text('Save rating'));
    await h.until(() => find.text('A little more you.').evaluate().isNotEmpty,
        'real rating save before payoff');
    final rating =
        await h.io(() => MovieService().getUserMovieRating(157336, user.id));
    expect(rating.rating, 8);
    expect(rating.recommended, true);
    await capture('04-payoff');
    await h.tap(find.text('Explore For You'));
    await h.until(() => find.byType(HomeScreen).evaluate().isNotEmpty,
        'back to discovery');
    expect(find.text('More your kind of thing'), findsNothing);
    await h.open('/profile');
    await h.tap(find.text('Build your taste'));
    await h.until(() => find.text('A little more you.').evaluate().isNotEmpty,
        'persisted resume via Profile');
    await h.tap(find.text('Add more favourites'));
    await h.until(
        () => find.text('Which films feel like you?').evaluate().isNotEmpty,
        'return to favourites');
    await h.tap(find.text('Skip for now'));
    await h.tap(find.text('Skip for now'));
    await h.tap(find.text('Explore For You'));
    await h.until(() => find.byType(HomeScreen).evaluate().isNotEmpty,
        'skippable return to Home');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
