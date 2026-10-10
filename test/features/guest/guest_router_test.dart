import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/features/guest/data/first_open_store.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/auth/referral_attribution_store.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/app/router/router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/guest/presentation/guest_access.dart';
import '../movies/movie_detail_action_flow_test.dart'
    show ActionAuth, ActionAnalytics;

class GuestAuth extends ActionAuth {
  @override
  AuthStatus get status => AuthStatus.unauthenticated;
  @override
  Listenable get authStatusListenable => this;
  @override
  bool get needsSocialProfile => false;
  @override
  bool get isLoading => false;
}

class GuestReferrals implements ReferralAttributionStore {
  @override
  Future<void> clear() async {}
  @override
  Future<String?> read() async => null;
  @override
  Future<void> save(String value) async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(
      {FirstOpenStore.welcomeSeenKey: true}));
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
    ('tablet', const Size(1024, 768), 1.0)
  ]) {
    testWidgets(
        '$name guest Home has public activity and exactly Home Discover You tabs',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final captureKey = GlobalKey();
      GuestAccess.clear();
      final requests = <String>[];
      ApiClient.useClientForTesting(MockClient((request) async {
        requests.add(request.url.path);
        return http.Response(
            jsonEncode(request.url.path == '/guest/home'
                ? {
                    'activity': [
                      {
                        'id': 'fixture-review',
                        'movie': {'id': 348, 'title': 'Alien'},
                        'user': {
                          'username': 'FilmFriend',
                          'avatar': null,
                          'profileBadges': ['FOUNDER']
                        }
                      }
                    ],
                    'communities': [
                      {'id': 27, 'name': 'Horror'}
                    ]
                  }
                : [
                    {'id': 348, 'title': 'Alien'}
                  ]),
            200);
      }));
      final auth = GuestAuth(), analytics = ActionAnalytics();
      final router = buildRouter(auth, analytics, GuestReferrals());
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<AnalyticsController>.value(value: analytics),
          ],
          child: RepaintBoundary(
              key: captureKey,
              child: MaterialApp.router(
                  debugShowCheckedModeBanner: false,
                  routerConfig: router,
                  theme: AppTheme.darkTheme,
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!)))));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Discover'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      expect(find.text('Plans'), findsNothing);
      expect(find.text('Social'), findsNothing);
      expect(
          requests.where((path) =>
              path.startsWith('/users') ||
              path.startsWith('/friends') ||
              path.startsWith('/community/')),
          isEmpty);
      expect(tester.takeException(), isNull);
      const output = String.fromEnvironment('GUEST_SCREENSHOT_DIR');
      if (output.isNotEmpty) {
        await tester.runAsync(() async {
          final image = await (captureKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(output).create(recursive: true);
          await File('$output/$name-home.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.text('You'));
      await tester.pumpAndSettle();
      expect(find.text('Create your account'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
      expect(find.text('Your streaming services'), findsNothing);
      expect(find.text('Already a member? Sign in'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      auth.dispose();
      analytics.dispose();
      ApiClient.useClientForTesting(null);
    });
  }
}
