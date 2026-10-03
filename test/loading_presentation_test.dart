import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/skeleton.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Manrope')
          ..addFont(
              rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  for (final size in [
    const Size(320, 740),
    const Size(430, 932),
    const Size(768, 1024),
    const Size(932, 430)
  ]) {
    testWidgets('detail preview fits $size with large text and reduced motion',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  disableAnimations: true,
                  textScaler: const TextScaler.linear(2)),
              child: child!),
          home: RepaintBoundary(
              key: boundary,
              child: const Scaffold(
                  body: MediaDetailPreview(
                      title: 'The Odyssey: A Journey Home')))));
      await tester.pumpAndSettle();
      expect(find.text('The Odyssey: A Journey Home'), findsOneWidget);
      expect(find.textContaining('Loading'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
      final output = Platform.environment['FLIXIE_LOADING_CAPTURES'];
      if (output != null) {
        await tester.runAsync(() async {
          final render = boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final capture = await render.toImage();
          final bytes =
              await capture.toByteData(format: ui.ImageByteFormat.png);
          await File('$output/detail-${size.width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          capture.dispose();
        });
      }
    });
  }
  testWidgets('preview back remains usable before details arrive',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const Scaffold(
                                body: MediaDetailPreview(title: 'Alien')))),
                    child: const Text('Open Alien'))))));
    await tester.tap(find.text('Open Alien'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Open Alien'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Alien'), findsNothing);
  });
  testWidgets(
      'section placeholders fit narrow width and expose accessible status',
      (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
            body: MediaQuery(
                data: const MediaQueryData(disableAnimations: true),
                child: Center(
                    child: SizedBox(
                        width: 220,
                        child: ListView(children: [
                          for (final style in ContentPlaceholderStyle.values)
                            ContentPlaceholder(
                                label: 'Pending ${style.name}', style: style),
                          const LoadingActionLabel(
                              loading: true, text: 'More comments'),
                        ])))))));
    await tester.pump();
    expect(find.bySemanticsLabel('Pending rows'), findsOneWidget);
    expect(find.textContaining('Pending'), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
