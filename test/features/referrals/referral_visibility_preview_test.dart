import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/referrals/presentation/social_invite_empty_state.dart';
import 'package:flixie_app/features/authentication/presentation/controllers/onboarding_controller.dart';
import 'package:flixie_app/features/authentication/presentation/widgets/onboarding/onboarding_account_choices.dart';
import '../authentication/onboarding_alert_choices_test.dart' show ChoicesSetup;

void main() {
  setUpAll(() async {
    await (FontLoader('Manrope')
          ..addFont(
              rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  for (final (name, size, scale) in [
    ('small', const Size(320, 640), 2.0),
    ('phone', const Size(390, 844), 1.0),
    ('tablet', const Size(834, 1112), 1.5)
  ]) {
    testWidgets('invite and onboarding choices render at $name', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final c = OnboardingController(
          service: ChoicesSetup(),
          userId: 'casey',
          countryId: 1,
          isCurrentUser: () => true);
      await c.load(includeTaste: false);
      c.selectProvider(1, true);
      for (final scene in ['social', 'choices']) {
        final key = GlobalKey();
        await t.pumpWidget(MaterialApp(
            theme: AppTheme.darkTheme,
            home: MediaQuery(
                data: MediaQueryData(
                    size: size, textScaler: TextScaler.linear(scale)),
                child: RepaintBoundary(
                    key: key,
                    child: Scaffold(
                        backgroundColor: FlixieColors.background,
                        body: SafeArea(
                            child: SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                child: scene == 'social'
                                    ? const SocialInviteEmptyState()
                                    : OnboardingAccountChoices(
                                        controller: c))))))));
        await t.runAsync(() => precacheImage(
            const AssetImage('assets/icon/pip_cosmetics/cinema_club.png'),
            t.element(find.byType(Scaffold))));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final capture = await boundary.toImage(pixelRatio: 2);
          final png = await capture.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory('output/referral-visibility')
            ..createSync(recursive: true);
          File('${dir.path}/$scene-$name.png')
              .writeAsBytesSync(png!.buffer.asUint8List());
          capture.dispose();
        });
        if (scene == 'choices') {
          await t.ensureVisible(
              find.text('Watch history, watchlists and watch plans stay out.'));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }
      }
      await t.pumpWidget(const SizedBox.shrink());
      c.dispose();
    });
  }
}
