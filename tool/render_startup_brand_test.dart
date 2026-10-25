import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/pip_startup_brand.dart';
import 'package:flixie_app/core/widgets/pip_griddy.dart';

// Rasterize actual Flutter launch widgets at native asset densities.
void main() {
  testWidgets('render matching native launch artwork', (tester) async {
    for (final family in ['Manrope', 'Roboto', '.SF Pro Display']) {
      await (FontLoader(family)
            ..addFont(
                rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
          .load();
    }
    final key = GlobalKey();
    Future<void> show(Widget child) async {
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
              data: const MediaQueryData(
                  size: Size(390, 844), disableAnimations: true),
              child: Center(
                  child: RepaintBoundary(
                      key: key,
                      child: Material(
                          type: MaterialType.transparency, child: child))))));
      await tester.runAsync(() => precacheImage(
          const AssetImage(PipGriddy.asset),
          tester.element(find.byType(PipGriddy))));
      await tester.pump();
    }

    Future<void> save(String path, double scale) async {
      final img = await (key.currentContext!.findRenderObject()
              as RenderRepaintBoundary)
          .toImage(pixelRatio: scale);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      await File(path).writeAsBytes(png!.buffer.asUint8List());
      img.dispose();
    }

    const densities = {
      'mdpi': 1.0,
      'hdpi': 1.5,
      'xhdpi': 2.0,
      'xxhdpi': 3.0,
      'xxxhdpi': 4.0
    };
    await show(
        const SizedBox(width: 192, height: 213, child: PipStartupBrand()));
    await tester.runAsync(() async {
      for (final scale in [1, 2, 3]) {
        await save(
            'ios/Runner/Assets.xcassets/PipLaunchBrand.imageset/LaunchImage${scale == 1 ? '' : '@${scale}x'}.png',
            scale.toDouble());
      }
      for (final density in densities.entries) {
        await save(
            'android/app/src/main/res/drawable-${density.key}/splash.png',
            density.value);
      }
    });
    await show(const PipGriddy(size: 192));
    await tester.runAsync(() async {
      for (final density in densities.entries) {
        for (final night in ['', 'night-']) {
          await save(
              'android/app/src/main/res/drawable-$night${density.key}/android12splash.png',
              density.value);
        }
      }
      await save('assets/splash/pip/launch-frame.png', 3);
    });
  });
}
