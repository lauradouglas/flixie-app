import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/widgets/pip_startup_illustration.dart';

void main() {
  for (final pose in [
    'drink',
    'glasses',
    'popcorn',
    'ticket',
    'confused-phone'
  ]) {
    for (final reduced in [false, true]) {
      testWidgets('$pose Pip renders with reduced motion $reduced', (t) async {
        await t.pumpWidget(MaterialApp(
            home: MediaQuery(
                data: MediaQueryData(disableAnimations: reduced),
                child: Center(
                    child: PipStartupIllustration(
                        asset: 'assets/splash/pip/$pose.png', size: 220)))));
        await t.runAsync(() => precacheImage(
            AssetImage(pose == 'glasses'
                ? 'assets/splash/pip/glasses-clean-face.png'
                : 'assets/splash/pip/$pose.png'),
            t.element(find.byType(PipStartupIllustration))));
        await t.pump();
        expect(find.byType(CustomPaint), findsWidgets);
        await t.pump(const Duration(milliseconds: 1500));
        expect(t.takeException(), isNull);
        expect(t.binding.hasScheduledFrame, !reduced);
        await t.pumpWidget(const SizedBox());
        expect(t.takeException(), isNull);
      });
    }
  }
}
