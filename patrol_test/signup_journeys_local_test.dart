import 'package:flixie_app/features/authentication/presentation/pages/signup_journey_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/features/authentication/presentation/pages/signup_screen.dart';
import 'package:flixie_app/features/guest/presentation/guest_home_screen.dart';
import 'package:flixie_app/features/authentication/presentation/widgets/onboarding/onboarding_services_step.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/movies/data/show_service.dart';
import 'package:flixie_app/features/movies/presentation/pages/movie_detail_screen.dart';
import 'package:flixie_app/features/movies/presentation/pages/show_detail_screen.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/write_review_sheet.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/models/show.dart';
import 'support/signup_local_journey.dart';

Future<void> titleEntry(LocalSignupJourney h, String action,
    {bool show = false}) async {
  await h.open(show ? '/shows/1396' : '/movies/348');
  await h.until(
      () =>
          find
              .byType(show ? ShowDetailScreen : MovieDetailScreen)
              .evaluate()
              .isNotEmpty &&
          find.text('Watchlist').evaluate().isNotEmpty,
      'real title actions');
  if (action == 'review') {
    await h.$.tester.scrollUntilVisible(find.text('Reviews'), 250,
        scrollable: find
            .descendant(
                of: find.byType(show ? ShowDetailScreen : MovieDetailScreen),
                matching: find.byType(Scrollable))
            .first);
    await h.tap(find.text('Reviews').first);
    await h.until(
        () => find.text('Write review').evaluate().isNotEmpty, 'review action');
    await h.tap(find.text('Write review'));
  } else {
    await h.tap(find
        .text(switch (action) {
          'watchlist' => 'Watchlist',
          'rate' => show ? 'Rate' : 'Rate this film',
          'log' => 'Log an entry',
          _ => 'Favourite'
        })
        .first);
  }
  if (action == 'watchlist') {
    await h.open('/guest-watchlist');
    await h.tap(find.text('Create account & keep my picks'));
  } else {
    await h.chooseSignup();
  }
}

Future<void> rated(LocalSignupJourney h) async {
  await h.until(() => find.text('Save rating').evaluate().isNotEmpty,
      'rating editor after signup');
  await h.tap(find.widgetWithText(FlixiePill, '8'));
  await h.tap(find.text('Save rating'));
  await h.until(
      () => find.text('Any all-time favourites?').evaluate().isNotEmpty,
      'persisted rating before favourites');
}

Future<void> review(LocalSignupJourney h) async {
  await h.until(() => find.byType(WriteReviewSheet).evaluate().isNotEmpty,
      'real embedded review editor');
  await h.tap(find.widgetWithText(FlixiePill, '8'));
  final fields = find.descendant(
      of: find.byType(WriteReviewSheet), matching: find.byType(TextFormField));
  await h.text(fields.first, 'Signup diary fixture');
  await h.text(fields.last, 'An isolated local review of Alien.');
  await h.tap(find.text('Post review'));
}

Future<void> companion(LocalSignupJourney h) async {
  await h.tap(find.text('Add someone'));
  await h.text(find.byType(TextField).last, 'Sam Fixture');
  await h.tap(find.text('Add to my watch'));
}

void main() {
  for (final show in [false, true]) {
    patrolTest(
        'local ${show ? 'TV' : 'film'} bookmark: password validation, persisted original save, optional providers',
        ($) async {
      final h = LocalSignupJourney($);
      await h.start();
      await titleEntry(h, 'watchlist', show: show);
      await h.fillSignup(validateFirst: !show);
      await h.until(
          () => find.text('Anything else for later?').evaluate().isNotEmpty,
          'original save completed');
      expect(h.auth.dbUser!.completedSetup, false);
      final persisted =
          await h.io(() => UserService.getUserById(h.auth.dbUser!.id));
      if (show) {
        expect(
            (persisted.showWatchlist ?? [])
                .any((e) => '${e is Map ? e['showId'] : e.showId}' == '1396'),
            true);
      } else {
        expect(persisted.movieWatchlist!.where((e) => e.movieId == 348),
            hasLength(1));
      }
      await h.tap(find.descendant(
          of: find.byType(SignupJourneyPage), matching: find.text('Continue')));
      await h.until(
          () => find.byType(OnboardingServicesStep).evaluate().isNotEmpty,
          'existing provider selector');
      await h.finishWith('Skip for now');
      expect(
          (await h.io(() => UserService.getUserById(h.auth.dbUser!.id)))
              .completedSetup,
          true);
    }, timeout: const Timeout(Duration(minutes: 4)));
    patrolTest(
        'local ${show ? 'TV' : 'film'} rating saves explicit score before public heart favourites',
        ($) async {
      final h = LocalSignupJourney($);
      await h.start();
      await titleEntry(h, 'rate', show: show);
      await h.fillSignup();
      await rated(h);
      expect(h.auth.dbUser!.completedSetup, false);
      if (show) {
        final saved = await h
            .io(() => ShowService.getUserShowRating(1396, h.auth.dbUser!.id));
        expect(saved?['rating'], 8);
      } else {
        expect(
            (await h.io(() =>
                    MovieService().getUserMovieRating(348, h.auth.dbUser!.id)))
                .rating,
            8);
      }
      await h.until(
          () => find.byIcon(Icons.favorite_border).evaluate().isNotEmpty,
          'optional heart favourites loaded');
      await h.tap(find
          .byTooltip('Add ${show ? 'Breaking Bad' : 'Alien'} to favourites'));
      await h.until(
          () => find.byTooltip('Added to favourites').evaluate().isNotEmpty,
          'explicit favourite persisted');
      final profile =
          await h.io(() => UserService.getUserById(h.auth.dbUser!.id));
      if (show) {
        expect(
            (profile.favoriteShows ?? [])
                .any((e) => e is Map && '${e['showId']}' == '1396'),
            true);
      } else {
        expect(profile.favoriteMovies!.where((m) => m.movieId == 348),
            hasLength(1));
      }
      await h.finishWith('Done for now');
    }, timeout: const Timeout(Duration(minutes: 4)));
    patrolTest(
        'local ${show ? 'TV' : 'film'} review: original editor, exactly one server review, optional diary',
        ($) async {
      final h = LocalSignupJourney($);
      await h.start();
      await titleEntry(h, 'review', show: show);
      await h.fillSignup();
      await review(h);
      await h.until(
          () => find.text('Your review is posted').evaluate().isNotEmpty,
          'review persisted');
      expect(h.auth.dbUser!.completedSetup, false);
      final rows =
          await h.io(() => UserService.getUserReviews(h.auth.dbUser!.id));
      expect(
          rows.where((r) =>
              r.title == 'Signup diary fixture' &&
              (show ? r.showId == 1396 : r.movieId == 348)),
          hasLength(1));
      if (!show) {
        await h.tap(find.text('Add date & watched with'));
        await h.until(() => find.byType(RewatchLogSheet).evaluate().isNotEmpty,
            'review diary editor');
        await companion(h);
        await h.tap(find.text('Save watch'));
        await h.until(() => find.text('Copy invite').evaluate().isNotEmpty,
            'saved viewing invitation');
        final watches = await h
            .io(() => UserService.getMovieWatchHistory(h.auth.dbUser!.id, 348));
        expect(watches, hasLength(1));
        expect(watches.single.externalInvite, isNotNull);
        expect(
            (await h.io(() => UserService.getUserReviews(h.auth.dbUser!.id)))
                .where((r) => r.title == 'Signup diary fixture'),
            hasLength(1));
        await h.tap(find.text('Copy invite'));
        await h.until(() => find.text('Invite copied').evaluate().isNotEmpty,
            'invite copied');
        expect((await Clipboard.getData(Clipboard.kTextPlain))?.text,
            contains('watch='));
        await h.finishWith('Back to the film');
      } else {
        await h.finishWith('Done for now');
      }
    }, timeout: const Timeout(Duration(minutes: 4)));
  }
  patrolTest(
      'local film log retries a lost response without duplicate watches or invites',
      ($) async {
    final h = LocalSignupJourney($);
    await h.start();
    await titleEntry(h, 'log');
    await h.fillSignup();
    await h.until(() => find.byType(RewatchLogSheet).evaluate().isNotEmpty,
        'embedded watch editor');
    await companion(h);
    h.transport.loseNextLogReply = true;
    await h.tap(find.text('Save watch'));
    await h.until(
        () => find
            .text(
                'Flixie is having trouble responding. Please try again shortly.')
            .evaluate()
            .isNotEmpty,
        'lost reply preserves draft');
    expect(h.auth.dbUser!.completedSetup, false);
    await h.tap(find.text('Save watch'));
    await h.until(() => find.text('Copy invite').evaluate().isNotEmpty,
        'retry saved existing viewing');
    final watches = await h
        .io(() => UserService.getMovieWatchHistory(h.auth.dbUser!.id, 348));
    expect(watches, hasLength(1));
    expect(watches.single.externalInvite?.displayName, 'Sam Fixture');
    await h.finishWith('Back to the film');
  }, timeout: const Timeout(Duration(minutes: 4)));
  patrolTest(
      'local failed bookmark and setup completion recover without losing original title',
      ($) async {
    final h = LocalSignupJourney($);
    await h.start();
    await titleEntry(h, 'watchlist');
    h.transport.failNext = (r) =>
        r.method == 'POST' && r.url.path.endsWith('/movie/watchlist/348');
    await h.fillSignup();
    await h.until(() => find.text('Try again').evaluate().isNotEmpty,
        'save failure offers retry');
    expect(find.text('Anything else for later?'), findsNothing);
    expect(h.auth.dbUser!.completedSetup, false);
    await h.tap(find.text('Try again'));
    await h.until(
        () => find.text('Anything else for later?').evaluate().isNotEmpty,
        'save retry');
    h.transport.failNext = (r) => r.url.path.endsWith('/setup-complete');
    await h.tap(find.byTooltip('Close'));
    await h.until(
        () =>
            find.textContaining('Couldn’t finish setup').evaluate().isNotEmpty,
        'completion failure remains recoverable');
    expect(h.auth.dbUser!.completedSetup, false);
    await h.tap(find.byTooltip('Close'));
    await h.until(
        () => h.auth.dbUser?.completedSetup == true, 'setup completed');
    expect(
        (await h.io(() => UserService.getUserById(h.auth.dbUser!.id)))
            .movieWatchlist!
            .where((e) => e.movieId == 348),
        hasLength(1));
  }, timeout: const Timeout(Duration(minutes: 4)));
  for (final source in ['home', 'profile']) {
    patrolTest(
        'local $source signup starts at its contextual first action and can skip',
        ($) async {
      final h = LocalSignupJourney($);
      await h.start();
      if (source == 'profile') await h.open('/profile');
      if (source == 'home') {
        await h.until(() => find.text('Trending now').evaluate().isNotEmpty,
            'guest Home content loaded');
        await h.$.tester.scrollUntilVisible(find.text('Create account'), 350,
            scrollable: find
                .descendant(
                    of: find.byType(GuestHomeScreen),
                    matching: find.byType(Scrollable))
                .first,
            maxScrolls: 30);
      }
      await h.until(() => find.text('Create account').evaluate().isNotEmpty,
          'real $source signup action');
      await h.tap(find.text('Create account').first);
      await h.until(
          () => find.byType(SignupScreen).evaluate().isNotEmpty, 'signup form');
      await h.fillSignup();
      await h.until(
          () => find
              .text(source == 'home'
                  ? 'What brings you to Flixie?'
                  : 'Make yourself at home')
              .evaluate()
              .isNotEmpty,
          'contextual $source first step');
      expect(h.auth.dbUser!.completedSetup, false);
      if (source == 'home') await h.tap(find.text('Add my favourites'));
      await h.finishWith('Skip for now');
    }, timeout: const Timeout(Duration(minutes: 4)));
  }
  patrolTest(
      'local episode signup marks the exact selected released episode once',
      ($) async {
    final h = LocalSignupJourney($);
    await h.start();
    await h.open('/shows/1396');
    await h.until(() => find.text('Mark watched').evaluate().isNotEmpty,
        'guest next-episode action');
    final before = await h.io(() => ShowService.getShowById(1396));
    final selected = TvShowEpisodeProgress(before).nextReleased;
    expect(selected, isNotNull);
    await h.tap(find.text('Mark watched').first);
    await h.chooseSignup();
    await h.fillSignup();
    await h.until(
        () => find.text('Episode marked watched').evaluate().isNotEmpty,
        'selected episode saved');
    final after = await h
        .io(() => ShowService.getShowById(1396, userId: h.auth.dbUser!.id));
    expect(
        TvShowEpisodeProgress(after)
            .allEpisodes
            .where((e) => e.watched)
            .map((e) => e.id),
        [selected!.id]);
    await h.finishWith('Back to the show');
  }, timeout: const Timeout(Duration(minutes: 4)));
  patrolTest(
      'local watchlist provider choices persist through the existing country and provider selector',
      ($) async {
    final h = LocalSignupJourney($);
    await h.start();
    await titleEntry(h, 'watchlist');
    await h.fillSignup();
    await h.until(
        () => find.text('Anything else for later?').evaluate().isNotEmpty,
        'first save');
    await h.tap(find.descendant(
        of: find.byType(SignupJourneyPage), matching: find.text('Continue')));
    await h.until(() => find.text('Select country').evaluate().isNotEmpty,
        'country selector');
    await h.tap(find.text('Select country'));
    await h.text(find.byType(TextField).last, 'United Kingdom');
    await h.tap(find.widgetWithText(ListTile, 'United Kingdom'));
    await h.until(
        () => find.byType(SignupCountryPickerSheet).evaluate().isEmpty,
        'country selected and picker dismissed');
    await h.until(() => find.byType(CheckboxListTile).evaluate().isNotEmpty,
        'existing service choices');
    final tile = find.byType(CheckboxListTile).first;
    final name = ($.tester.widget<CheckboxListTile>(tile).title as Text).data!;
    await h.tap(tile);
    await h.finishWith('Save services & open watchlist');
    final saved =
        await h.io(() => UserService.getUserWatchProviders(h.auth.dbUser!.id));
    expect(saved.any((p) => p.providerName == name), true);
  }, timeout: const Timeout(Duration(minutes: 4)));
  patrolTest(
      'local signup profile-create failure retries the same Firebase account',
      ($) async {
    final h = LocalSignupJourney($);
    await h.start();
    await titleEntry(h, 'watchlist');
    h.transport.failNext = (r) =>
        r.method == 'POST' &&
        r.url.path.replaceAll(RegExp(r'/$'), '') == '/users';
    await h.fillSignup(retryProfileFailure: true);
    await h.until(
        () => find.text('Anything else for later?').evaluate().isNotEmpty,
        'pending save after profile recovery');
    expect(h.transport.profileBodies, hasLength(2));
    expect(
        h.transport.profileBodies.map((b) => b['email']).toSet(), hasLength(1));
  }, timeout: const Timeout(Duration(minutes: 4)));
  patrolTest(
      'local failed review keeps the draft and retry creates only one review',
      ($) async {
    final h = LocalSignupJourney($);
    await h.start();
    await titleEntry(h, 'review');
    await h.fillSignup();
    h.transport.failNext =
        (r) => r.method == 'POST' && r.url.path.endsWith('/review');
    await review(h);
    await h.until(
        () => find
            .textContaining('Couldn’t submit your review')
            .evaluate()
            .isNotEmpty,
        'review failure feedback');
    expect(find.byType(WriteReviewSheet), findsOneWidget);
    expect(find.text('Signup diary fixture'), findsOneWidget);
    await h.tap(find.text('Retry'));
    await h.until(
        () => find.text('Your review is posted').evaluate().isNotEmpty,
        'review retry');
    expect(
        (await h.io(() => UserService.getUserReviews(h.auth.dbUser!.id)))
            .where((r) => r.title == 'Signup diary fixture'),
        hasLength(1));
  }, timeout: const Timeout(Duration(minutes: 4)));
  patrolTest(
      'local cancelled signup and dismissed prompt leave guest browsing usable without writes',
      ($) async {
    final h = LocalSignupJourney($);
    await h.start();
    await titleEntry(h, 'watchlist');
    await h.tap(find.text('Keep exploring'));
    await h.until(() => find.byType(GuestHomeScreen).evaluate().isNotEmpty,
        'guest browsing after signup cancellation');
    expect(h.auth.dbUser, isNull);
    expect(h.transport.profileBodies, isEmpty);
    await h.open('/movies/348');
    await h.until(() => find.text('Watchlist').evaluate().isNotEmpty,
        'title after cancellation');
    await h.tap(find.text('Watchlist'));
    await h.tap(find.text('Keep exploring'));
    expect(find.byType(MovieDetailScreen), findsOneWidget);
    expect(h.auth.dbUser, isNull);
  }, timeout: const Timeout(Duration(minutes: 4)));
  for (final input in ['code', 'username']) {
    patrolTest(
        'local optional referral resolves $input to the inviter before signup',
        ($) async {
      final h = LocalSignupJourney($);
      await h.start();
      await h.open('/profile');
      await h.tap(find.text('Create account'));
      await h.fillSignup();
      await h.until(
          () => find.text('Make yourself at home').evaluate().isNotEmpty,
          'inviter fixture profile');
      await h.finishWith('Skip for now');
      final inviter = h.username;
      final summary = await h.io(UserService.getMyReferral);
      await h.io(h.auth.signOut);
      await h.until(() => h.auth.dbUser == null && !h.auth.isAuthenticated,
          'inviter signed out before second fixture');
      await h.open('/profile');
      await h.tap(find.text('Create account'));
      await h.fillSignup(
          referral: input == 'code' ? summary.code : '@$inviter');
      expect(h.transport.profileBodies.last['referralCode'], summary.code);
      await h.until(
          () => find.text('Make yourself at home').evaluate().isNotEmpty,
          'referred profile created');
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}
