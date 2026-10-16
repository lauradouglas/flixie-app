// Renders design proposals; deliberately outside the regression suite.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'preview.dart';

void main() {
  testWidgets('render current UI and watch-together proposals', (tester) async {
    await (FontLoader('Manrope')
          ..addFont(
              rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final family in ['Roboto', '.SF Pro Display']) {
      await (FontLoader(family)..addFont(rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'))).load();
    }
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final screen in [
      'current-log',
      'updated-log',
      'create-plan',
      'saved-plan',
      'companion-prompt',
      'rating-prompt'
    ]) {
      final key = GlobalKey();
      await tester.pumpWidget(
          RepaintBoundary(key: key, child: watchTogetherPreview(screen)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: screen);
      final render =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('output/watch-together-mockups/$screen.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
