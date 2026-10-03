import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../patrol_test/support/store_screenshot_fixture.dart';
import 'support/api_fixture.dart';

void main() {
  testWidgets(
      'all seven screenshot destinations load through isolated fixtures',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = StoreScreenshotFixture();
    useApiFixture(fixture.client);
    final auth = StoreScreenshotAuth();
    final router = storeScreenshotRouter();
    addTearDown(auth.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(storeScreenshotApp(auth, router));
    for (final (route, label) in [
      ('/', 'Pick for me'),
      ('/profile', 'alexriver'),
      ('/watchlist', 'Interstellar'),
      ('/watch-requests/store-movie-night', 'Alien'),
      ('/community/spaces/18', 'The shows that stay with you'),
      ('/movies/157336', 'Interstellar'),
      ('/shows/15621', 'The Newsroom'),
    ]) {
      router.go(route);
      await tester.pumpAndSettle();
      expect(find.textContaining(label), findsWidgets, reason: route);
      expect(fixture.unexpectedRequests, isEmpty, reason: route);
      expect(find.textContaining('Couldn’t load'), findsNothing, reason: route);
      expect(find.text('Episode details unavailable'), findsNothing,
          reason: route);
      expect(tester.takeException(), isNull, reason: route);
      expect(
          tester
              .widget<ColoredBox>(
                  find.byKey(const ValueKey('screenshot-app-background')))
              .color,
          FlixieColors.background,
          reason: 'Transparent routes must use the production backdrop');
      if (route == '/watchlist') {
        expect(find.text('2 friends watched'), findsWidgets);
        expect(find.textContaining('8.5'), findsWidgets);
        expect(find.text('No friends watched yet').hitTestable(), findsNothing);
        expect(find.text('No providers found').hitTestable(), findsNothing);
      }
      if (route == '/watch-requests/store-movie-night') {
        expect(find.text('Both confirmed'), findsOneWidget);
        expect(find.text('Add to calendar'), findsOneWidget);
      }
      if (route == '/movies/157336') {
        expect(find.text('8.7  FlixScore'), findsOneWidget);
        expect(find.text('No ratings yet'), findsNothing);
        await Scrollable.ensureVisible(tester.element(find.text('Friends')),
            alignment: 0.08);
        await tester.pumpAndSettle();
        expect(find.text('jamie').hitTestable(), findsOneWidget);
        expect(find.text('morganlee').hitTestable(), findsOneWidget);
        expect(find.text('People you follow').hitTestable(), findsOneWidget);
        expect(find.text('ninawatches').hitTestable(), findsOneWidget);
        expect(find.text('Interstellar deserves the big screen').hitTestable(),
            findsOneWidget);
      }
    }
    router.go('/movies/157336');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log watch').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '9'));
    await tester.pumpAndSettle();
    expect(find.text('Rate & mark watched'), findsOneWidget);
    expect(fixture.unexpectedRequests, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    // Drain the production image/palette deadlines under the fake clock.
    await tester.pump(const Duration(seconds: 16));
  });
}
