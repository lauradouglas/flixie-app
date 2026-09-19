import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/authentication/presentation/pages/splash_screen.dart';

class _SplashAuth extends ChangeNotifier implements AuthProvider {
  @override
  String? get recoveryError => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(430, 932),
    const Size(844, 390),
    const Size(834, 1194)
  ]) {
    testWidgets('Splash branding fits ${size.width} x ${size.height}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = _SplashAuth();
      addTearDown(auth.dispose);
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
            builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
            home: const SplashScreen()),
      ));
      await tester.runAsync(() => precacheImage(
          const AssetImage('assets/icon/flixie_f_transparent.png'),
          tester.element(find.byType(SplashScreen))));
      await tester.pump(const Duration(seconds: 1));
      expect(find.bySemanticsLabel('Flixie'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(tester.getCenter(find.byType(Image)),
          Offset(size.width / 2, size.height / 2));
    });
  }
}
