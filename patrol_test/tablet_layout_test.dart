import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flixie_app/app/router/flixie_tablet_navigation.dart';
import 'package:flixie_app/features/home/presentation/widgets/tablet_trending_gallery.dart';
import 'package:flixie_app/features/watchlist/presentation/widgets/watchlist_tablet_gallery.dart';
import 'package:flixie_app/features/profile/presentation/widgets/favourite_poster_rail.dart';
import '../test/support/api_fixture.dart';
import 'support/store_screenshot_fixture.dart';

class TabletLayoutFixture extends StoreScreenshotFixture {
  @override
  Object? response(http.Request request) {
    if (request.url.path == '/community/settings') {
      return {'communitySharing': true};
    }
    if (request.url.path == '/community/activity-state') {
      return {
        'items': [
          for (final target in jsonDecode(request.body)['targets'])
            {
              ...target as Map,
              'saved': false,
              'reactions': {'counts': {}, 'mine': null}
            }
        ]
      };
    }
    if (request.url.path == '/community/activity' &&
        request.url.queryParameters['movieId'] == null) {
      return {
        'items': [
          {
            'id': 'fictional-alien-watch',
            'ownerId': 'store-jamie',
            'user': screenshotFriend,
            'type': 'MOVIE_WATCHED',
            'movieId': 348,
            'movie': screenshotMovies[1],
            'rating': 9,
            'createdAt': DateTime.now()
                .subtract(const Duration(hours: 2))
                .toIso8601String(),
            'reactions': {'counts': {}, 'mine': null},
            'replyCount': 0
          },
        ],
        'nextCursor': null
      };
    }
    return super.response(request);
  }
}

Future<void> capture(String scene) async {
  const host = String.fromEnvironment('TABLET_CAPTURE_HOST');
  if (host.isEmpty) return;
  final client = HttpClient();
  try {
    final request = await client.postUrl(Uri.parse('$host/capture/$scene'));
    request.headers.set('X-Flixie-Capture-Token',
        const String.fromEnvironment('TABLET_CAPTURE_TOKEN'));
    final response = await request.close().timeout(const Duration(seconds: 45));
    final body = await utf8.decoder.bind(response).join();
    expect(response.statusCode, 200, reason: body);
  } finally {
    client.close(force: true);
  }
}

void main() {
  patrolTest('tablet pages reflow and keep library and detail actions',
      ($) async {
    // ignore: invalid_use_of_protected_member
    ($.tester.binding as LiveTestWidgetsFlutterBinding).setLabel('');
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final fixture = TabletLayoutFixture();
    useApiFixture(fixture.client);
    final auth = StoreScreenshotAuth();
    final router = storeScreenshotRouter(tabletReview: true);
    addTearDown(auth.dispose);
    addTearDown(router.dispose);
    addTearDown(() => SystemChrome.setPreferredOrientations([]));
    const tablet = bool.fromEnvironment('TABLET_DEVICE');
    await SystemChrome.setPreferredOrientations([
      tablet ? DeviceOrientation.landscapeLeft : DeviceOrientation.portraitUp
    ]);
    await $.pumpWidgetAndSettle(storeScreenshotApp(auth, router));
    if (tablet) {
      final deadline = DateTime.now().add(const Duration(seconds: 60));
      while ($.tester.view.physicalSize.width <
              $.tester.view.physicalSize.height &&
          DateTime.now().isBefore(deadline)) {
        await $.pump(const Duration(milliseconds: 100));
      }
      await $.pumpAndSettle();
      expect($.tester.view.physicalSize.width,
          greaterThan($.tester.view.physicalSize.height),
          reason: 'Rotate the dedicated iPad Simulator to landscape. '
              'Orientation locks can be ignored with iPad multitasking.');
    }
    for (final (name, route, label) in [
      ('home', '/', 'Trending now'),
      ('profile', '/profile', 'alexriver'),
      ('watchlist', '/watchlist', 'Watchlist'),
      ('social', '/social', 'Communities'),
      ('detail', '/movies/157336', 'Interstellar'),
    ]) {
      router.go('/');
      await $.pumpAndSettle();
      if (route != '/') {
        if (route == '/profile' || route == '/social') {
          router.go(route);
        } else {
          router.push<void>(route);
        }
        await $.pumpAndSettle();
      }
      await $(find.textContaining(label).first).waitUntilVisible();
      if (tablet) {
        expect(find.byType(FlixieTabletNavigation), findsOneWidget);
        if (name == 'home') {
          // Home and In Cinemas both reuse the adaptive carousel.
          expect(find.byType(TabletTrendingGallery), findsNWidgets(2));
          expect(
              $.tester
                  .widget<TabletTrendingGallery>(
                      find.byType(TabletTrendingGallery).first)
                  .movies
                  .first
                  .id,
              157336);
        }
        if (name == 'watchlist') {
          expect(find.byType(WatchlistTabletGallery), findsOneWidget);
        }
      }
      if (name == 'detail') {
        await $.tester.tap(find.text('Buy'));
        await $.pumpAndSettle();
        expect(find.text('Available to buy'), findsOneWidget);
      }
      if (name == 'watchlist') {
        await $(find.byTooltip('More actions').first).waitUntilVisible();
        await $.tester.tap(find.byTooltip('More actions').hitTestable().first);
        await $.pumpAndSettle();
        expect(find.text('Title details'), findsOneWidget);
        expect(find.text('Invite friends'), findsOneWidget);
        await $.tester.tap(find.text('Title details'));
        await $.pumpAndSettle();
        expect(find.text('Story'), findsOneWidget);
        router.pop();
        await $.pumpAndSettle();
      }
      expect(fixture.unexpectedRequests, isEmpty);
      expect($.tester.takeException(), isNull);
      await $.pump(const Duration(seconds: 1));
      await $.pumpAndSettle();
      await capture('${tablet ? 'landscape' : 'phone'}-$name');
    }
    if (tablet &&
        const bool.fromEnvironment('TABLET_ROTATION_REVIEW',
            defaultValue: true)) {
      await SystemChrome.setPreferredOrientations(
          [DeviceOrientation.portraitUp]);
      await $.pumpAndSettle();
      final deadline = DateTime.now().add(const Duration(seconds: 60));
      while ($.tester.view.physicalSize.width >
              $.tester.view.physicalSize.height &&
          DateTime.now().isBefore(deadline)) {
        await $.pump(const Duration(milliseconds: 100));
      }
      await $.pumpAndSettle();
      expect(find.byType(FlixieTabletNavigation), findsNothing);
      expect(find.text('Available to buy'), findsOneWidget);
      expect($.tester.takeException(), isNull);
      await capture('portrait-detail');
      router.go('/profile');
      await $.pumpAndSettle();
      final favourites = find.byType(FavouritePosterRail).first;
      await $.tester.ensureVisible(favourites);
      await $.pumpAndSettle();
      await $.tester
          .tap(find.descendant(of: favourites, matching: find.text('See all')));
      await $.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Alien').hitTestable(), findsOneWidget);
      expect($.tester.takeException(), isNull);
      await capture('portrait-favourites');
    }
    await $.pumpWidgetAndSettle(const SizedBox.shrink());
  },
      config: const PatrolTesterConfig(settleTimeout: Duration(seconds: 60)),
      timeout: const Timeout(Duration(minutes: 10)));
}
