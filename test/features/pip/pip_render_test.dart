import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/pip/presentation/controllers/pip_collection_controller.dart';
import 'package:flixie_app/features/pip/presentation/widgets/my_pip_sheet.dart';
import 'package:flixie_app/features/pip/presentation/widgets/pip_companion.dart';
import 'pip_collection_test.dart' show FakePips;

void main() {
  setUpAll(() async {
    for (final family in ['Manrope', 'Roboto', '.SF Pro Display']) {
      await (FontLoader(family)
            ..addFont(
                rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
          .load();
    }
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  for (final width in [320.0, 390.0, 834.0]) {
    testWidgets('Pip collection choices and controls render at $width',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final size = Size(width, width > 600 ? 1112 : 844);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = PipCollectionController(service: FakePips());
      c.syncUser('viewer', 0);
      await tester.pumpAndSettle();
      final key = GlobalKey();
      await tester.pumpWidget(ChangeNotifierProvider.value(
          value: c,
          child: RepaintBoundary(
              key: key,
              child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.darkTheme,
                  home: MediaQuery(
                      data: MediaQueryData(
                          size: size,
                          textScaler: TextScaler.linear(width == 320
                              ? 2
                              : width > 600
                                  ? 1.5
                                  : 1)),
                      child: Scaffold(
                          body: Align(
                              alignment: Alignment.bottomCenter,
                              child: MyPipSheet(controller: c)),
                          bottomNavigationBar: const PipCompanion()))))));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final path in ['classic', 'cinema_club']) {
          await precacheImage(AssetImage('assets/icon/pip_cosmetics/$path.png'),
              tester.element(find.byType(MyPipSheet)));
        }
      });
      Future<void> capture(String state) async {
        expect(tester.takeException(), isNull);
        if (Platform.environment['FLIXIE_PIP_CAPTURE'] == '1') {
          await tester.runAsync(() async {
            final image = await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            final dir = Directory('output/pip-implementation')
              ..createSync(recursive: true);
            File('${dir.path}/$state-${width.toInt()}.png')
                .writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }

      await tester.pumpAndSettle();
      await capture('collection');
      await tester.ensureVisible(find.text('Pip outfit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pip outfit'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cinema Club'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cinema Club'));
      await tester.pumpAndSettle();
      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(0, 1500));
      await tester.pumpAndSettle();
      await capture('outfit');
      await tester.ensureVisible(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(c.collection.activePip, 'classic');
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
  }
}
