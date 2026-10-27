import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/settings/presentation/pages/invite_friend_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(834, 1112)
  ]) {
    testWidgets('share precedes fallback code and real progress wraps at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      useApiFixture(MockClient((_) async => http.Response(
          jsonEncode({
            'code': 'FLXFIXTURE',
            'inviteUrl': 'https://www.flixie.co.uk/invite?code=FLXFIXTURE',
            'referralCount': 2,
            'qualifiedReferralCount': 1,
            'referrals': [
              {'displayName': 'Sophie', 'qualified': false},
              {'displayName': 'Jamie', 'qualified': true}
            ]
          }),
          200)));
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.darkTheme,
              home: MediaQuery(
                  data: MediaQueryData(
                      size: size,
                      textScaler: TextScaler.linear(size.width == 320
                          ? 2
                          : size.width > 600
                              ? 1.5
                              : 1)),
                  child: const InviteFriendScreen()))));
      await tester.pumpAndSettle();
      await tester.runAsync(() => precacheImage(
          const AssetImage('assets/icon/community_pips/pip-flixie-hoodie.png'),
          tester.element(find.byType(InviteFriendScreen))));
      await tester.pumpAndSettle();
      expect(find.text('Share your invite'), findsOneWidget);
      final shareY = tester.getTopLeft(find.text('Share your invite')).dy;
      await tester.scrollUntilVisible(find.text('Copy code').hitTestable(), 250,
          scrollable: find.byType(Scrollable).first);
      expect(shareY, greaterThan(0));
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
          find.text('View progress').hitTestable(), -250,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('View progress'));
      await tester.pumpAndSettle();
      expect(find.text('Sophie'), findsOneWidget);
      expect(find.text('Joined · reward not earned yet'), findsOneWidget);
      expect(find.text('Joined · Film Friend earned'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find.text('Bring your film person.').hitTestable(), -400,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      if (Platform.environment['FLIXIE_REFERRAL_CAPTURE'] == '1') {
        await tester.runAsync(() async {
          final image = await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory('output/referral-implementation')
            ..createSync(recursive: true);
          File('${dir.path}/referral-${size.width.toInt()}.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
}
