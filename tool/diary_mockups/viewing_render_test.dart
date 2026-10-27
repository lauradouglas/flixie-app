import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'diary_options.dart';
import 'planner_refinement.dart';

void main() {
  testWidgets(
      'compact cinema checkbox updates one watch and preserves other settings',
      (tester) async {
    for (final family in ['Manrope', 'Roboto', '.SF Pro Display']) {
      await (FontLoader(family)
            ..addFont(
                rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
          .load();
    }
    await (FontLoader('Georgia')
          ..addFont(Future.value(ByteData.sublistView(
              File('/System/Library/Fonts/Supplemental/Georgia.ttf')
                  .readAsBytesSync()))))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    for (final movie in movies) {
      final info = await tester.runAsync(() async {
        final codec =
            await ui.instantiateImageCodec(await File(movie.$5).readAsBytes());
        return ImageInfo(image: (await codec.getNextFrame()).image);
      });
      PaintingBinding.instance.imageCache.putIfAbsent(FileImage(File(movie.$5)),
          () => OneFrameImageStreamCompleter(Future.value(info!)));
    }
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final viewport in [
      (name: 'phone', size: const Size(390, 844), scale: 1.0),
      (name: 'small-large-text', size: const Size(360, 780), scale: 1.5),
      (name: 'tablet', size: const Size(820, 1000), scale: 1.0)
    ]) {
      tester.view.physicalSize = viewport.size;
      await tester.binding.setSurfaceSize(viewport.size);
      for (final option in ['planner-viewing']) {
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
            key: key, child: plannerRefinementApp(scale: viewport.scale)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: '${viewport.name} $option');
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('output/diary-mockups/$option-${viewport.name}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.tap(find.text('Alien').first);
        await tester.pumpAndSettle();
        expect(find.text('Watched at the cinema'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
                  'output/diary-mockups/watch-entry-cinema-compact-${viewport.name}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.tap(find.text('Watched at the cinema'));
        await tester.pumpAndSettle();
        expect(
            tester
                .widget<CheckboxListTile>(find.byType(CheckboxListTile))
                .value,
            isFalse);
        await tester.tap(find.text('Save preview'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Cinema'), findsNothing);
        expect(find.byTooltip('TV'), findsOneWidget);
        await tester.tap(find.text('Alien').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Watched at the cinema'));
        await tester.pumpAndSettle();
        expect(
            tester
                .widget<CheckboxListTile>(find.byType(CheckboxListTile))
                .value,
            isTrue);
        await tester.tap(find.text('Save preview'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Cinema'), findsOneWidget);
        for (final title in ['Spider-Man', 'Interstellar']) {
          await tester.ensureVisible(find.text(title).first);
          await tester.tap(find.text(title).first);
          await tester.pumpAndSettle();
          expect(
              find.text(title == 'Spider-Man'
                  ? '14 October 2026'
                  : '16 October 2026'),
              findsOneWidget);
          if (title == 'Spider-Man') {
            expect(find.text('Solo movie night').last, findsOneWidget);
          } else {
            expect(find.text('Sophie').last, findsOneWidget);
            expect(find.text('Robin').last, findsOneWidget);
          }
          await tester.tap(find.byTooltip('Close entry preview'));
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.text('12–18 October').first);
        await tester.tap(find.text('12–18 October').first);
        await tester.pumpAndSettle();
        expect(find.text('Find a week'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
                  'output/diary-mockups/calendar-viewing-${viewport.name}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.tap(find.byKey(const ValueKey('calendar-2026-10-6')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Show 5–11 October'));
        await tester.tap(find.text('Show 5–11 October'));
        await tester.pumpAndSettle();
        expect(find.text('5–11 October'), findsOneWidget);
        expect(find.text('Alien'), findsOneWidget);
        expect(find.text('Interstellar'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(PageView), const Offset(-340, 0));
        await tester.pumpAndSettle();
        if (viewport.name != 'tablet')
          expect(find.text('12–18 October'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    }
  });
}
