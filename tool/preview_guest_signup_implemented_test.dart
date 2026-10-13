import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/guest/presentation/widgets/guest_signup_section.dart';
import 'package:flixie_app/core/widgets/flixie_wordmark.dart';

void main() {
  testWidgets('capture signed-out Home signup mockup', (tester) async {
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
              home: Scaffold(backgroundColor: config.$3.brightness == Brightness.dark ? const Color(0xFF150C24) : const Color(0xFFF4EDFF),
 appBar: AppBar(title: Text.rich(flixieWordmarkSpan(fontFamily: 'Manrope', foregroundColor: config.$3.brightness == Brightness.dark ? Colors.white : const Color(0xFF29272D)))),
 body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
 OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.search), label: const Text('Search movies, shows and people')),
 const SizedBox(height: 24), GuestSignupSection(onSignup: () {}, onSignin: () {}),
 const SizedBox(height: 24), const Text('Trending now', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
 ])))))));
      await tester.runAsync(() async {
        await precacheImage(const AssetImage('assets/splash/pip/glasses-clean-face.png'),
            key.currentContext!);
      });
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('output/guest-signup-implemented/${config.$1}.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
