import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../test/support/api_fixture.dart';
import 'support/store_screenshot_fixture.dart';

const storeScreenshotScenes = [
  ('01-home', '/', 'Trending now'),
  ('02-profile', '/profile', 'alexriver'),
  ('03-watchlist', '/watchlist', 'Interstellar'),
  ('04-watch-plan', '/watch-requests/store-movie-night', 'Alien'),
  ('05-community', '/community/spaces/18', 'The shows that stay with you'),
  ('06-interstellar', '/movies/157336', 'Interstellar'),
  ('07-the-newsroom', '/shows/15621', 'The Newsroom'),
  ('08-rating', '/movies/157336', 'Interstellar'),
];

void main() {
  const host = String.fromEnvironment('SCREENSHOT_HOST');
  patrolTest('capture launch campaign video', ($) async {
    // Live Flutter test labels are separate from Patrol's --no-label overlay.
    // ignore: invalid_use_of_protected_member
    ($.tester.binding as LiveTestWidgetsFlutterBinding).setLabel('');
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final fixture = StoreScreenshotFixture();
    useApiFixture(fixture.client);
    final auth = StoreScreenshotAuth();
    final router = storeScreenshotRouter();
    addTearDown(auth.dispose);
    addTearDown(router.dispose);
    await $.pumpWidgetAndSettle(storeScreenshotApp(auth, router));
    // iOS can report zero safe-area insets during its first test frame.
    // Wait for native window metrics before capturing the home screen.
    final metricsDeadline = DateTime.now().add(const Duration(seconds: 15));
    while ($.tester.view.viewPadding.top == 0 &&
        DateTime.now().isBefore(metricsDeadline)) {
      await $.pump(const Duration(milliseconds: 100));
    }
    expect($.tester.view.viewPadding.top, greaterThan(0),
        reason: 'Native status-bar insets are not ready');
    await $.pumpAndSettle();
    for (final (name, route, label) in storeScreenshotScenes) {
      const selected = String.fromEnvironment('SCREENSHOT_SCENES');
      if (selected.isNotEmpty && !selected.split('|').contains(name)) continue;
      // Match actual navigation, including the back button on detail routes.
      router.go(route == '/profile' ? route : '/');
      await $.pumpAndSettle();
      if (route != '/' && route != '/profile') {
        router.push<void>(route);
        await $.pumpAndSettle();
      }
      final insetDeadline = DateTime.now().add(const Duration(seconds: 10));
      while ($.tester.view.viewPadding.top == 0 &&
          DateTime.now().isBefore(insetDeadline)) {
        await $.pump(const Duration(milliseconds: 100));
      }
      expect($.tester.view.viewPadding.top, greaterThan(0),
          reason: 'Native safe area lost on $name');
      await $.pumpAndSettle();
      final target = find.textContaining(label).first;
      if (name == '08-rating') {
        await $.tester.tap(find.text('Log watch').first);
        await $.pumpAndSettle();
        await $.tester.tap(find.widgetWithText(TextButton, '9'));
        await $.pumpAndSettle();
        await $.tester.tap(find.byTooltip('Recommend'));
        await $.pumpAndSettle();
        expect(find.text('Rate & mark watched'), findsOneWidget);
      } else if (target.hitTestable().evaluate().isEmpty) {
        await $.tester.ensureVisible(target);
        await $.pumpAndSettle();
      }
      if (name == '06-interstellar' || name == '07-the-newsroom') {
        final buyTab = find.textContaining('Buy').hitTestable();
        if (buyTab.evaluate().isNotEmpty) {
          await $.tester.tap(buyTab.first);
          await $.pumpAndSettle();
        }
      }
      if (name != '08-rating') await $(target).waitUntilVisible();

      // Wait for actual image decoding, including cached-network-image's
      // mounted Image widgets. An artwork failure must fail the capture.
      final context = $.tester.element(find.byType(MaterialApp));
      final providers = <ImageProvider>{
        ...$.tester
            .widgetList<Image>(find.byType(Image))
            .map((image) => image.image),
        ...$.tester
            .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
            .map((image) => CachedNetworkImageProvider(image.imageUrl)),
      };
      for (final provider in providers) {
        Object? error;
        await precacheImage(provider, context,
                onError: (exception, _) => error = exception)
            .timeout(const Duration(seconds: 45));
        expect(error, isNull, reason: 'Artwork failed on $name');
      }
      await $.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: 'A loading indicator remains on $name');
      expect(find.textContaining('Couldn’t load'), findsNothing,
          reason: 'An error state remains on $name');
      expect(find.textContaining('couldn’t load'), findsNothing,
          reason: 'An error state remains on $name');
      expect(find.text('Episode details unavailable'), findsNothing,
          reason: 'Episode tracking is missing on $name');
      expect(fixture.unexpectedRequests, isEmpty);
      expect($.tester.takeException(), isNull);

      Future<void> signal(String phase) async {
        final client = HttpClient();
        try {
          final request = await client.postUrl(Uri.parse('$host/$phase/$name'));
          request.headers.set('X-Flixie-Capture-Token',
              const String.fromEnvironment('SCREENSHOT_TOKEN'));
          final response =
              await request.close().timeout(const Duration(seconds: 45));
          final body = await utf8.decoder.bind(response).join();
          expect(response.statusCode, 200, reason: body);
        } finally {
          client.close(force: true);
        }
      }

      await signal('start');
      // Intentional editorial hold: recording starts only after UI/artwork settle.
      await $.pump(const Duration(milliseconds: 1400));
      if (name == '01-home' || name == '03-watchlist' || name == '02-profile') {
        final scrollable = $.tester.state<ScrollableState>(find
            .byWidgetPredicate((widget) =>
                widget is Scrollable &&
                (widget.axisDirection == AxisDirection.down ||
                    widget.axisDirection == AxisDirection.up))
            .first);
        final position = scrollable.position;
        final scrolling = position.animateTo(
            (position.pixels + 110)
                .clamp(position.minScrollExtent, position.maxScrollExtent),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeInOut);
        await $.pumpAndSettle();
        await scrolling;
      }
      await $.pump(const Duration(milliseconds: 2200));
      await signal('finish');
    }
    await $.pumpWidgetAndSettle(const SizedBox.shrink());
  },
      config: const PatrolTesterConfig(
          settleTimeout: Duration(seconds: 60), printLogs: true),
      skip: host.isEmpty,
      timeout: const Timeout(Duration(minutes: 10)));
}
