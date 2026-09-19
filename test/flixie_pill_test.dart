import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/app/theme/flixie_pill_style.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';

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
  test('genre palette is stable and readable in both themes', () {
    for (final brightness in Brightness.values) {
      final colours = <Color>{};
      for (final genre in [
        'Action',
        'Adventure',
        'Comedy',
        'Drama',
        'Romance',
        'Horror',
        'Fantasy',
        'Crime'
      ]) {
        final pair = FlixiePillStyle.genreColors(genre, brightness);
        expect(
            pair,
            FlixiePillStyle.genreColors(
                '  ${genre.toUpperCase()}  ', brightness));
        colours.add(pair.$1);
        final a = pair.$1.computeLuminance();
        final b = pair.$2.computeLuminance();
        final contrast = a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
        expect(contrast, greaterThanOrEqualTo(4.5));
      }
      expect(colours.length, greaterThanOrEqualTo(4));
    }
  });
  test('all Material chips go through the shared component', () {
    final raw = RegExp(
        r'\b(?:ChoiceChip|FilterChip|ActionChip|InputChip|Chip|RawChip)\(');
    final violations = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) =>
            f.path.endsWith('.dart') && !f.path.endsWith('/flixie_pill.dart'))
        .where((f) => raw.hasMatch(f.readAsStringSync()))
        .map((f) => f.path)
        .toList();
    expect(violations, isEmpty);
  });
  testWidgets('selection, action and disabled states preserve behaviour',
      (tester) async {
    var selected = false;
    var actions = 0;
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
            body: StatefulBuilder(
                builder: (context, setState) => Wrap(children: [
                      FlixiePill.filter(
                          label: const Text('Comedy'),
                          selected: selected,
                          onSelected: (value) =>
                              setState(() => selected = value)),
                      FlixiePill.action(
                          label: const Text('Pick one'),
                          onPressed: () => actions++),
                      const FlixiePill.choice(
                          label: Text('Unavailable'),
                          selected: false,
                          onSelected: null),
                    ])))));
    expect(tester.getSize(find.byType(FlixiePill).first).height,
        greaterThanOrEqualTo(48));
    await tester.tap(find.text('Comedy'));
    await tester.pumpAndSettle();
    expect(selected, isTrue);
    final raw = tester.widget<RawChip>(find.byType(RawChip).first);
    expect(raw.selectedColor, FlixiePillStyle.selectedFill);
    expect(raw.side, BorderSide.none);
    expect(raw.labelStyle?.color, FlixiePillStyle.selectedText);
    expect(DefaultTextStyle.of(tester.element(find.text('Comedy'))).style.color,
        FlixiePillStyle.selectedText);
    await tester.tap(find.text('Pick one'));
    expect(actions, 1);
    expect(
        tester.widget<RawChip>(find.byType(RawChip).last).isEnabled, isFalse);
    await tester.tap(find.text('Comedy'));
    await tester.pumpAndSettle();
    expect(selected, isFalse);
  });
  for (final size in [
    const Size(320, 640),
    const Size(430, 932),
    const Size(932, 430),
    const Size(1024, 1366)
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('wraps labels at $size with text scale $scale',
          (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.darkTheme,
            home: MediaQuery(
                data: MediaQueryData(
                    size: size, textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                    body: SingleChildScrollView(
                        child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Wrap(spacing: 8, runSpacing: 4, children: [
                              FlixiePill.choice(
                                  label: const Text('Action & Adventure'),
                                  selected: true,
                                  onSelected: (_) {}),
                              FlixiePill.choice(
                                  label: const Text('Science Fiction'),
                                  selected: false,
                                  onSelected: (_) {}),
                              const FlixiePill.label(
                                  label: Text(
                                      'An unusually long genre or status label that needs to wrap')),
                            ])))))));
        expect(tester.takeException(), isNull);
        expect(
            find.text(
                'An unusually long genre or status label that needs to wrap'),
            findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(find.text(
            'An unusually long genre or status label that needs to wrap'));
        expect(paragraph.didExceedMaxLines, isFalse);
        if (size.width == 320) {
          expect(paragraph.size.height, greaterThan(24 * scale));
        }
      });
    }
  }
  testWidgets('keyboard activates focused pill', (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: FlixiePill.action(
                label: const Text('Pick'), onPressed: () => calls++))));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls, 1);
  });
  testWidgets('Option A gallery in both themes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(860, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: Row(textDirection: TextDirection.ltr, children: [
          for (final dark in [true, false])
            Expanded(
                child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
                    home: Scaffold(
                        backgroundColor: dark
                            ? const Color(0xFF180F2E)
                            : const Color(0xFFFAF7FF),
                        body: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 24),
                                  const Text('Choose a genre',
                                      style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 20),
                                  Wrap(spacing: 8, runSpacing: 4, children: [
                                    for (final genre in [
                                      'All genres',
                                      'Action',
                                      'Adventure',
                                      'Animation',
                                      'Comedy',
                                      'Crime',
                                      'Drama',
                                      'Family',
                                      'Fantasy',
                                      'Horror',
                                      'Rom com',
                                      'Romance',
                                      'Science Fiction',
                                      'Thriller'
                                    ])
                                      FlixiePill.choice(
                                          label: Text(genre),
                                          selected: genre == 'Comedy',
                                          onSelected: (_) {})
                                  ]),
                                  const SizedBox(height: 24),
                                  Wrap(spacing: 8, children: [
                                    const FlixiePill.label(
                                        label: Text('Movie')),
                                    const FlixiePill.label(
                                        label: Text('Recommended'),
                                        avatar: Icon(Icons.thumb_up_outlined)),
                                    FlixiePill.action(
                                        label: const Text('Pick one'),
                                        avatar: const Icon(Icons.shuffle),
                                        onPressed: () {})
                                  ]),
                                  const SizedBox(height: 16),
                                  const FlixiePill.choice(
                                      label: Text('Unavailable'),
                                      selected: false,
                                      onSelected: null),
                                ])))))
        ])));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    if (Platform.environment['PILL_CAPTURE'] == '1') {
      await tester.runAsync(() async {
        final image = await (key.currentContext!.findRenderObject()!
                as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('/tmp/flixie-pill-gallery.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
