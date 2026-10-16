import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';

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
  for (final (size, keyboard, scale) in [
    (const Size(375, 667), 300.0, 1.0),
    (const Size(844, 390), 216.0, 1.0),
    (const Size(820, 1180), 400.0, 1.6),
  ]) {
    testWidgets(
        'review selection and watch comment stay above keyboard on $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final capture = GlobalKey();
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => RepaintBoundary(
              key: capture,
              child: MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!)),
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () => showMovieWatchLogSheet<void>(
                          context: context,
                          builder: (_) => RewatchLogSheet(
                              movieTitle: 'Alien',
                              showReviewOption: true,
                              onReviewSelected: (_) {},
                              onDetailsChanged: (_) {},
                              onSubmit: (
                                  {required watchedAt,
                                  required rating,
                                  required recommended,
                                  required notes}) async {})),
                      child: const Text('Open watch'))))));
      await tester.tap(find.text('Open watch'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Write a review next'));
      await tester.tap(find.text('Write a review next'));
      await tester.pumpAndSettle();
      final review = find.widgetWithText(TextField, 'Watch comment (optional)');
      await tester.ensureVisible(review);
      await tester.tap(review);
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
      await tester.pumpAndSettle();
      await tester.enterText(review, 'A brilliant screening with Sophie.');
      await tester.pumpAndSettle();
      expect(
          tester
              .getBottomRight(
                  find.widgetWithText(FilledButton, 'Save & write review'))
              .dy,
          lessThanOrEqualTo(size.height - keyboard));
      expect(find.text('Save & write review').hitTestable(), findsOneWidget);
      expect(tester.widget<TextField>(review).controller!.text,
          'A brilliant screening with Sophie.');
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_WATCH_LOG')) {
        await tester.runAsync(() async {
          final boundary = capture.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('/tmp/flixie-watch-keyboard-${size.width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(review).controller!.text,
          'A brilliant screening with Sophie.');
    });
  }
}
