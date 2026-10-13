import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/social/presentation/widgets/community_identity.dart';
import 'package:flixie_app/features/social/presentation/widgets/community_pip.dart';

void main() {
  testWidgets('capture community Pip headers', (tester) async {
    await (FontLoader('Manrope')
          ..addFont(
              rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final config in [
      ('phone-dark', const Size(390, 844), AppTheme.darkTheme),
      ('phone-light', const Size(390, 844), AppTheme.lightTheme),
      ('tablet-dark', const Size(834, 1194), AppTheme.darkTheme),
    ]) {
      tester.view.physicalSize = config.$2;
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: config.$3,
              home: Scaffold(
                backgroundColor: config.$3.brightness == Brightness.dark
                    ? const Color(0xFF150C24) : const Color(0xFFF4EDFF),
                  appBar: AppBar(title: const Text('Communities')),
                  body: SingleChildScrollView(
                      child: Column(children: [
                    for (final entry in [
                      (28, 'Action'),
                      (27, 'Horror'),
                      (10402, 'Music')
                    ])
                      CommunityIdentityHeader(id: entry.$1, name: entry.$2),
                  ]))))));
      await tester.runAsync(() async {
        for (final id in [28, 27, 10402]) {
          await precacheImage(
              ResizeImage.resizeIfNeeded(
                  320, null, AssetImage(CommunityPip.assetFor(id)!)),
              key.currentContext!);
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('output/community-pips/${config.$1}.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
