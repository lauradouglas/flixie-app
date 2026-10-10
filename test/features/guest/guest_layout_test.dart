import 'package:flixie_app/core/widgets/cinema_light_background.dart';
import 'package:flixie_app/core/widgets/cinema_wordmark.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/guest/presentation/guest_home_screen.dart';
import 'package:flixie_app/features/guest/presentation/guest_access.dart';
import 'guest_router_test.dart' show GuestAuth;

void main() {
  setUpAll(() async {
    for (final family in ['Manrope', '.SF Pro Display', 'Roboto']) {
      await (FontLoader(family)
            ..addFont(
                rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
          .load();
    }
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  for (final (name, size, scale) in [
    ('phone', const Size(390, 844), 1.0),
    ('small-large-text', const Size(320, 568), 2.0),
    ('tablet', const Size(1024, 768), 1.0),
  ]) {
    testWidgets('guest account layouts fit $name', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey(), auth = GuestAuth();
      final router = GoRouter(routes: [
        GoRoute(
            path: '/', builder: (_, __) => const GuestWelcomeScreen(you: true)),
        GoRoute(
            path: '/auth/signup',
            builder: (_, __) => const Scaffold(body: Text('Signup fixture')))
      ]);
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: RepaintBoundary(
              key: key,
              child: MaterialApp.router(
                  debugShowCheckedModeBanner: false,
                  routerConfig: router,
                  theme: AppTheme.darkTheme,
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!)))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(CinemaLightBackground), findsOneWidget);
      expect(find.byType(CinemaWordmark), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
      const output = String.fromEnvironment('GUEST_SCREENSHOT_DIR');
      Future<void> capture(String suffix) async {
        if (output.isEmpty) return;
        await tester.runAsync(() async {
          final image = await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(output).create(recursive: true);
          await File('$output/$name-$suffix.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('you');
      final context = tester.element(find.byType(GuestWelcomeScreen));
      final sheet = GuestAccess.require(context,
          title: 'Save Alien for later',
          message: 'Create a free account to keep your watchlist with you.',
          path: '/movies/348',
          intent: 'watchlist');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture('sheet');
      await tester.scrollUntilVisible(
          find.descendant(
              of: find.byType(BottomSheet),
              matching: find.text('Keep exploring')),
          160,
          scrollable: find
              .descendant(
                  of: find.byType(BottomSheet),
                  matching: find.byType(Scrollable))
              .first);
      await tester.tap(find.descendant(
          of: find.byType(BottomSheet), matching: find.text('Keep exploring')));
      await tester.pumpAndSettle();
      await sheet;
      await tester.ensureVisible(find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(find.text('Signup fixture'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Create your account'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      auth.dispose();
    });
  }
}
