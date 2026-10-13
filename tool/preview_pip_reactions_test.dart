import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/activity_reaction.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_reaction_bubble.dart';

void main() {
  testWidgets('capture Pip reaction picker in phone themes and tablet layout',
      (tester) async {
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
                  body: Builder(
                      builder: (context) => Center(
                          child: TextButton(
                              onPressed: () => showActivityReactionBubble(
                                  context, context,
                                  current: '❤️', canReply: true),
                              child: const Text('React'))))))));
      await tester.runAsync(() async {
        for (final reaction in ActivityReaction.values) {
          await precacheImage(
              ResizeImage.resizeIfNeeded(128, null, AssetImage(reaction.asset)),
              key.currentContext!);
        }
      });
      await tester.tap(find.text('React'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('output/pip-reactions/${config.$1}.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
