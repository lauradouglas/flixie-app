import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/library_import/data/library_import_controller.dart';
import 'package:flixie_app/features/library_import/data/library_import_models.dart';
import 'package:flixie_app/features/library_import/presentation/library_import_screen.dart';

void main() {
  for (final missingPlugin in [true, false]) {
    testWidgets(
        'Picker launch failure reports the chooser, not a bad export ($missingPlugin)',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      FilePickerIO.registerWith();
      final channel = MethodChannel(
          'miguelruivo.flutter.plugins.filepicker',
          Platform.isMacOS || Platform.isLinux || Platform.isWindows
              ? const JSONMethodCodec()
              : const StandardMethodCodec());
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (_) async {
        if (missingPlugin) throw MissingPluginException();
        throw PlatformException(code: 'picker_unavailable');
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: LibraryImportScreen(
              controller: LibraryImportController(
                  userId: 'picker-test', isCurrentUser: () => true))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose export files'));
      await tester.pumpAndSettle();
      expect(
          find.textContaining(
              missingPlugin ? 'full rebuild' : 'file chooser could not open'),
          findsOneWidget);
      expect(find.textContaining('Download a fresh export'), findsNothing);
    });
  }
  setUpAll(() async {
    await (FontLoader('Manrope')
          ..addFont(
              rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  for (final width in [390.0, 1024.0]) {
    testWidgets('Import entry visual at width $width', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = Size(width, width == 390 ? 844 : 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: LibraryImportScreen(
              controller: LibraryImportController(
                  userId: 'visual', isCurrentUser: () => true))));
      await tester.pumpAndSettle();
      await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile(
              'goldens/library_import_entry_${width.toInt()}.png'));
    });
  }
  for (final size in [
    const Size(320, 568),
    const Size(430, 932),
    const Size(1024, 768),
    const Size(844, 390)
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Import preview fits $size at text scale $scale',
          (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller =
            LibraryImportController(userId: 'test', isCurrentUser: () => true);
        controller.data = LibraryImportData([
          LibraryImportRow(
              title:
                  'A very long film title that must wrap without truncating meaningful information',
              source: 'Letterboxd',
              year: 2020,
              rating: 7,
              watchlist: true)
            ..status = 'review',
        ], [
          '1 invalid row skipped.'
        ]);
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.darkTheme,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: LibraryImportScreen(controller: controller)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
            find.textContaining('A very long film title'), 400,
            scrollable: find.byType(Scrollable).first, maxScrolls: 20);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.textContaining('A very long film title'), findsOneWidget);
      });
    }
  }
  testWidgets('Entry screen explains export and never asks for passwords',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: LibraryImportScreen(
            controller: LibraryImportController(
                userId: 'test', isCurrentUser: () => true))));
    await tester.pumpAndSettle();
    expect(find.text('Open Letterboxd export'), findsOneWidget);
    expect(find.text('Open IMDb ratings'), findsOneWidget);
    expect(find.text('Open IMDb watchlist'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
