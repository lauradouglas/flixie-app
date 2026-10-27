import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/controllers/profile_diary_controller.dart';
import 'package:flixie_app/features/profile/presentation/pages/profile_diary_screen.dart';
import '../../test/features/profile/profile_controller_test.dart'
    show ProfileAuth;
import '../../test/features/profile/diary/diary_test.dart' show DiaryData;

void main() {
  setUpAll(() async {
    await (FontLoader('Manrope')
          ..addFont(
              rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
        .load();
    await (FontLoader('Georgia')
          ..addFont(Future.value(ByteData.sublistView(
              File('/System/Library/Fonts/Supplemental/Georgia.ttf')
                  .readAsBytesSync()))))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  testWidgets('capture implemented diary across responsive sizes',
      (tester) async {
    for (final spec in [
      (name: 'phone', size: const Size(390, 844), scale: 1.0),
      (name: 'large-text', size: const Size(320, 780), scale: 1.8),
      (name: 'tablet', size: const Size(834, 1194), scale: 1.0),
      (name: 'landscape', size: const Size(844, 390), scale: 1.0)
    ]) {
      tester.view.physicalSize = spec.size;
      tester.view.devicePixelRatio = 1;
      final c =
          ProfileDiaryController(auth: ProfileAuth(), service: DiaryData());
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
              theme: AppTheme.darkTheme,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(spec.scale)),
                  child: child!),
              home: ProfileDiaryScreen(
                  controller: c, today: DateTime(2026, 10, 17)))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image = await (key.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('output/diary-update').create(recursive: true);
        await File('output/diary-update/${spec.name}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      c.auth.dispose();
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
