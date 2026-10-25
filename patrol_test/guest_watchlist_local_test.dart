import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flixie_app/features/authentication/presentation/pages/signup_journey_page.dart';
import 'package:flixie_app/features/watchlist/presentation/pages/watchlist_screen.dart';
import 'package:flixie_app/features/guest/presentation/guest_home_screen.dart';
import 'package:flixie_app/features/movies/presentation/pages/movie_detail_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:flixie_app/features/watchlist/data/guest_watchlist_store.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'support/signup_local_journey.dart';

void main() {
  patrolTest('guest picks survive signup cancellation then save before setup',
      ($) async {
    final h = LocalSignupJourney($);
    await h.start();
    Future<void> capture(String stage) async {
      const host = String.fromEnvironment('SIGNUP_SCREENSHOT_HOST');
      if (host.isEmpty) return;
      // ignore: invalid_use_of_protected_member
      ($.tester.binding as LiveTestWidgetsFlutterBinding).setLabel('');
      ScaffoldMessenger.maybeOf($.tester.element(find.byType(Scaffold).first))
          ?.clearSnackBars();
      await $.pump(const Duration(milliseconds: 500));
      final scrolls = $.tester
          .stateList<ScrollableState>(find.byType(Scrollable))
          .where((s) =>
              s.position.axis == Axis.vertical &&
              s.position.maxScrollExtent > 30)
          .toList()
        ..sort((a, b) =>
            b.position.maxScrollExtent.compareTo(a.position.maxScrollExtent));
      final position = scrolls.isEmpty ? null : scrolls.first.position;
      position?.jumpTo(0);
      var part = 0;
      do {
        await $.pump(const Duration(milliseconds: 350));
        final context = $.tester.element(find.byType(Scaffold).first);
        await h.io(() async {
          await Future.wait($.tester
                  .widgetList<Image>(find.byType(Image))
                  .map((i) => precacheImage(i.image, context)))
              .timeout(const Duration(seconds: 15));
        });
        await $.pump(const Duration(milliseconds: 250));
        await h.io(() async {
          final client = HttpClient();
          try {
            final req = await client.postUrl(Uri.parse('$host/capture'));
            req.headers.set('X-Capture-Token',
                const String.fromEnvironment('SIGNUP_SCREENSHOT_TOKEN'));
            req.headers.contentType = ContentType.json;
            req.write(jsonEncode({
              'device': 'phone',
              'flow': 'guest-watchlist',
              'step': stage,
              'part': ++part,
              'name': 'guest-watchlist-$stage-$part'
            }));
            final res = await req.close();
            expect(res.statusCode, 200);
            await res.drain<void>();
          } finally {
            client.close(force: true);
          }
        });
        if (position == null || position.extentAfter <= 20 || part >= 5) break;
        position.jumpTo((position.pixels + position.viewportDimension * .78)
            .clamp(0, position.maxScrollExtent));
      } while (true);
      position?.jumpTo(0);
      await $.pump();
    }

    await h.open('/movies/348');
    await h.until(
        () => find.text('Watchlist').evaluate().isNotEmpty, 'Alien actions');
    await h.tap(find.text('Watchlist').first);
    await h.until(
        () => find.text('View picks').evaluate().isNotEmpty, 'device saved');
    expect(h.auth.dbUser, isNull);
    expect(await GuestWatchlistStore.instance.read(), hasLength(1));
    await h.open('/');
    await h.until(() => find.byType(GuestHomeScreen).evaluate().isNotEmpty,
        'return to browsing');
    await h.open('/movies/157336');
    await h.until(
        () =>
            find
                .byWidgetPredicate(
                    (w) => w is MovieDetailScreen && w.movieId == '157336')
                .evaluate()
                .isNotEmpty &&
            find.text('Interstellar').evaluate().isNotEmpty &&
            find.text('Watchlist').evaluate().isNotEmpty,
        'Interstellar actions');
    await $.pump(const Duration(milliseconds: 500));
    await h.tap(find.text('Watchlist').first);
    await $.pump(const Duration(milliseconds: 500));
    await h.open('/guest-watchlist');
    await h.until(
        () =>
            find.text('Good picks. Keep them together.').evaluate().isNotEmpty,
        'guest collection');
    expect((await GuestWatchlistStore.instance.read()), hasLength(2));
    await capture('01-guest-picks');
    await h.tap(find.text('Create account & keep my picks'));
    await h.open('/guest-watchlist');
    expect(await GuestWatchlistStore.instance.read(), hasLength(2));
    await h.tap(find.text('Create account & keep my picks'));
    await capture('02-signup');
    await h.fillSignup();
    await h.until(
        () => find.text('Anything else for later?').evaluate().isNotEmpty,
        'saved before setup');
    expect(h.auth.dbUser!.completedSetup, false);
    final user = await h.io(() => UserService.getUserById(h.auth.dbUser!.id));
    expect(user.movieWatchlist!.where((m) => m.movieId == 348), hasLength(1));
    expect(
        user.movieWatchlist!.where((m) => m.movieId == 157336), hasLength(1));
    expect(await GuestWatchlistStore.instance.read(), isEmpty);
    await capture('03-picks-saved');
    await h.tap(find.descendant(
        of: find.byType(SignupJourneyPage), matching: find.text('Continue')));
    await h.until(
        () => find.text('Save services & open watchlist').evaluate().isNotEmpty,
        'optional provider screen');
    await capture('04-optional-providers');
    await h.tap(find.text('Select country'));
    await h.text(find.byType(TextField).last, 'United Kingdom');
    FocusManager.instance.primaryFocus?.unfocus();
    await $.pump();
    await h.until(
        () => find
            .widgetWithText(ListTile, 'United Kingdom')
            .evaluate()
            .isNotEmpty,
        'country options');
    await capture('04b-country-selection');
    await h.tap(find.widgetWithText(ListTile, 'United Kingdom'));
    await h.until(() => find.text('Netflix').evaluate().isNotEmpty,
        'provider names and icons loaded');
    await capture('04c-provider-icons');
    await h.finishWith('Skip for now');
    await h.until(() => find.byType(WatchlistScreen).evaluate().isNotEmpty,
        'account watchlist');
    await h.until(() => find.text('Interstellar').evaluate().isNotEmpty,
        'saved titles loaded');
    await capture('05-account-watchlist');
  }, timeout: const Timeout(Duration(minutes: 4)));
}
