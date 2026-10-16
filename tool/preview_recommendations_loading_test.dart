import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/home/presentation/widgets/recommendations_loading_card.dart';

void main() {
  testWidgets('capture Home Pip loading strip', (tester) async {
    await (FontLoader('Manrope')
          ..addFont(
              rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final config in [
      ('phone-dark', const Size(390, 844), AppTheme.darkTheme),
      ('phone-light', const Size(390, 844), AppTheme.lightTheme),
      ('tablet-dark', const Size(834, 1194), AppTheme.darkTheme),
    ]) {
      tester.view.physicalSize = config.$2;
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: config.$3,
              home: Scaffold(
                backgroundColor: config.$3.brightness == Brightness.dark
                    ? const Color(0xFF150C24) : const Color(0xFFF4EDFF),
                  appBar: AppBar(title: const Text('Just for you')),
                body: const SingleChildScrollView(child: RecommendationsLoadingCard())))));
      await tester.runAsync(() async {
        await precacheImage(ResizeImage.resizeIfNeeded(160, null, const AssetImage('assets/splash/pip/popcorn.png')), key.currentContext!);
      });
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pump(const Duration(milliseconds: 10));
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('output/recommendations-loading/${config.$1}.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
