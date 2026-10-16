import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/movies/presentation/widgets/write_review_sheet.dart';

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
    (const Size(320, 568), 250.0, 2.0),
  ]) {
    testWidgets(
        'Cinema notebook preserves draft and posting above keyboard on $size at $scale',
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
                      onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          useRootNavigator: true,
                          useSafeArea: true,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => WriteReviewSheet(
                              movieId: 348,
                              mediaTitle: 'Alien',
                              userId: 'fixture',
                              watchEntryId: 'watch',
                              initialRating: 8,
                              initialWatchedAt: '2026-10-16T15:00:00Z',
                              onSubmitted: (_) {})),
                      child: const Text('Open review'))))));
      await tester.tap(find.text('Open review'));
      await tester.pumpAndSettle();
      expect(find.text('Alien'), findsOneWidget);
      expect(find.text('Dear movie diary…'), findsOneWidget);
      expect(find.text('Your watch is saved.\nNow for your take.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_NOTEBOOK')) {
        await tester.runAsync(() async {
          final boundary = capture.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('/tmp/flixie-notebook-${size.width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      final title = find.widgetWithText(
          TextFormField, 'Still thinking about that ending');
      final body =
          find.widgetWithText(TextFormField, 'What made this one memorable?');
      await tester.ensureVisible(title);
      await tester.enterText(title, 'Still terrifying');
      await tester.ensureVisible(body);
      await tester.tap(body);
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
      await tester.pumpAndSettle();
      await tester.enterText(body, 'Alien builds tension brilliantly.');
      await tester.pumpAndSettle();
      final post = find.widgetWithText(ElevatedButton, 'Post review');
      expect(post.hitTestable(), findsOneWidget);
      expect(tester.getBottomRight(post).dy,
          lessThanOrEqualTo(size.height - keyboard));
      expect(tester.widget<TextFormField>(title).controller!.text,
          'Still terrifying');
      expect(tester.widget<TextFormField>(body).controller!.text,
          'Alien builds tension brilliantly.');
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(body).controller!.text,
          'Alien builds tension brilliantly.');
    });
  }
}
