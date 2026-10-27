import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/guest/presentation/widgets/guest_signup_section.dart';

void main() {
  for (final config in [(320.0, 2.0), (390.0, 1.0), (834.0, 1.0)]) {
    testWidgets('signup invitation and actions at ${config.$1}/${config.$2}',
        (tester) async {
      tester.view.physicalSize = Size(config.$1, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var signup = 0;
      var signin = 0;
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
              body: MediaQuery(
                  data: MediaQueryData(
                      disableAnimations: true,
                      textScaler: TextScaler.linear(config.$2)),
                  child: SingleChildScrollView(
                      child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: GuestSignupSection(
                              onSignup: () => signup++,
                              onSignin: () => signin++)))))));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Your picks, wherever you sign in.'), findsOneWidget);
      expect(
          find.text(
              'Your watchlist works here already. An account keeps it across devices and gives your ratings and diary a home.'),
          findsOneWidget);
      await tester.ensureVisible(find.text('Keep my picks across devices'));
      await tester.tap(find.text('Keep my picks across devices'));
      expect(signup, 1);
      await tester.ensureVisible(find.text('Already a member? Sign in'));
      await tester.tap(find.text('Already a member? Sign in'));
      expect(signin, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
