import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/core/widgets/pip_startup_brand.dart';
import 'package:flixie_app/core/widgets/pip_startup_illustration.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
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
    await tester.runAsync(() => precacheImage(
        AssetImage(PipStartupArtwork.launchAsset),
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
          AssetImage(PipStartupArtwork.launchAsset),
          tester.element(find.byType(SplashScreen))));
      await tester.pump(const Duration(seconds: 1));
      expect(find.bySemanticsLabel('Flixie'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.byType(PipStartupBrand), findsOneWidget);
      final splashAsset = tester
          .widget<PipStartupIllustration>(find.byType(PipStartupIllustration))
          .asset;
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: HomeBootLoadingScreen())));
      await tester.pump();
      expect(
          tester
              .widget<PipStartupIllustration>(
                  find.byType(PipStartupIllustration))
              .asset,
          splashAsset);
      expect(tester.takeException(), isNull);
    });
  }
}
