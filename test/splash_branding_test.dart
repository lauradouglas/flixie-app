import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/core/widgets/pip_startup_brand.dart';
import 'package:flixie_app/core/widgets/pip_griddy.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/authentication/presentation/pages/splash_screen.dart';

class _SplashAuth extends ChangeNotifier implements AuthProvider {
  String? error;
  int retries = 0;
  @override
  Future<void> retrySession() async {
    retries++;
  }

  @override
  String? get recoveryError => error;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('slow session retains an accessible retry without a spinner',
      (tester) async {
    final auth = _SplashAuth()..error = 'Could not restore your session.';
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
            home: MediaQuery(
                data: const MediaQueryData(disableAnimations: true),
                child: const SplashScreen()))));
    expect(find.text(auth.error!), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.text('Retry'));
    expect(auth.retries, 1);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
  });

  testWidgets('Pip boot preview', (tester) async {
    for (final family in ['Manrope', 'Roboto', '.SF Pro Display']) {
      final fonts = FontLoader(family)
        ..addFont(
            rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'));
      await fonts.load();
    }
    final boundary = GlobalKey();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: RepaintBoundary(
            key: boundary,
            child: const Scaffold(body: HomeBootLoadingScreen()))));
    await tester.runAsync(() => precacheImage(const AssetImage(PipGriddy.asset),
        tester.element(find.byType(HomeBootLoadingScreen))));
    await tester.pump();
    expect(find.byType(PipStartupBrand), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (Platform.environment['PIP_CAPTURE'] == '1') {
      await tester.runAsync(() async {
        final image = await (boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('/private/tmp/flixie-pip-boot.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });

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
          const AssetImage(PipGriddy.asset),
          tester.element(find.byType(SplashScreen))));
      await tester.pump(const Duration(seconds: 1));
      expect(find.bySemanticsLabel('Flixie'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.byType(PipStartupBrand), findsOneWidget);
      expect(find.byType(PipGriddy), findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(SplashScreen),
              matching: find.byType(FadeTransition)),
          findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: HomeBootLoadingScreen())));
      await tester.pump();
      expect(find.byType(PipGriddy), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
