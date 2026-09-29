import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/home/presentation/widgets/find_tonights_film_section.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Manrope')
          ..addFont(
              rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
        .load();
  });
  for (final size in [
    const Size(320, 640),
    const Size(430, 932),
    const Size(768, 1024),
    const Size(844, 390)
  ]) {
    testWidgets(
        'film picker action remains reachable at $size with enlarged text',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final boundary = GlobalKey();
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!),
          home: Builder(
              builder: (context) => Scaffold(
                  body: SingleChildScrollView(
                      child: RepaintBoundary(
                          key: boundary,
                          child: FindTonightsFilmSection(
                              onPick: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                      builder: (_) => const Scaffold(
                                          body: Text(
                                              'Picker destination')))))))))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Solo or with friends. Start with your mood.'),
          findsOneWidget);
      expect(tester.getSize(find.byType(FilledButton)).width, size.width - 32);
      if (const bool.fromEnvironment('UX_CAPTURE')) {
        await tester.runAsync(() async {
          final image = await (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('/tmp/flixie-film-section-${size.width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.ensureVisible(find.text('Pick for me'));
      await tester.tap(find.text('Pick for me'));
      await tester.pumpAndSettle();
      expect(find.text('Picker destination'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Find tonight’s film'), findsOneWidget);
    });
  }
}
