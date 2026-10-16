import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/guest/presentation/guest_home_screen.dart';
import 'package:flixie_app/features/guest/presentation/widgets/guest_home_welcome.dart';
import '../../support/api_fixture.dart';

void main() {
  setUpAll(() async {
    for (final family in ['Manrope', 'Roboto', '.SF Pro Display']) {
      await (FontLoader(family)
            ..addFont(
                rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
          .load();
    }
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  for (final (size, scale) in [
    (const Size(320, 568), 2.0),
    (const Size(430, 932), 1.0),
    (const Size(844, 390), 1.0),
    (const Size(834, 1194), 2.0),
  ]) {
    testWidgets('guest discovery precedes signup at $size/$scale',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      useApiFixture(MockClient((request) async => http.Response(
          jsonEncode(request.url.path == '/guest/home'
              ? {'communities': []}
              : request.url.path == '/guest/community/activity'
                  ? {'items': [], 'nextCursor': null}
                  : [
                      {
                        'id': 348,
                        'name': 'Alien',
                        'title': 'Alien',
                        'mediaType': 'MOVIE',
                        'releaseDate': '1979-05-25'
                      },
                      {
                        'id': 1,
                        'name': 'The Odyssey',
                        'title': 'The Odyssey',
                        'mediaType': 'MOVIE'
                      },
                    ]),
          200)));
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, __) => const GuestHomeScreen()),
        GoRoute(
            path: '/auth/signup',
            builder: (_, __) =>
                const Scaffold(body: Text('Signup destination'))),
        GoRoute(
            path: '/auth/login',
            builder: (_, __) =>
                const Scaffold(body: Text('Signin destination'))),
        GoRoute(
            path: '/search',
            builder: (_, __) =>
                const Scaffold(body: Text('Search destination'))),
      ]);
      addTearDown(router.dispose);
      final boundary = GlobalKey();
      await tester.pumpWidget(MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.darkTheme,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(key: boundary, child: child!))));
      await tester.pumpAndSettle();
      expect(find.byType(GuestHomeWelcome), findsOneWidget);
      await tester.runAsync(() => precacheImage(
          const AssetImage('assets/icon/community_pips/pip-flixie-hoodie.png'),
          tester.element(find.byType(GuestHomeWelcome))));
      await tester.pump();
      expect(find.text('Create account').hitTestable(), findsNothing);
      expect(tester.takeException(), isNull);
      // Capture the phone/tablet opening viewport when explicitly requested.
      if (Platform.environment['GUEST_HOME_CAPTURE'] == '1') {
        await tester.runAsync(() async {
          final image = await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('/tmp/flixie-guest-home-${size.width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.scrollUntilVisible(find.text('In cinemas'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Make it yours.').hitTestable(), findsNothing);
      await tester.scrollUntilVisible(find.text('Create account'), 300,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(find.text('Signup destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
