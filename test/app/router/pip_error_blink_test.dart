import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/widgets/pip_startup_illustration.dart';

void main() {
  const asset = 'assets/splash/pip/confused-phone.png';
  for (final (name, reduced, visible) in [
    ('blinks', false, true),
    ('reduced motion stays still', true, true),
    ('hidden stays still', false, false),
  ]) {
    testWidgets('confused Pip $name and keeps phone/body still', (t) async {
      final key = GlobalKey();
      await t.pumpWidget(MaterialApp(
          home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: TickerMode(
                  enabled: visible,
                  child: Center(
                      child: RepaintBoundary(
                          key: key,
                          child: const PipStartupIllustration(
                              asset: asset, size: 220)))))));
      await t.runAsync(() => precacheImage(const AssetImage(asset),
          t.element(find.byType(PipStartupIllustration))));
      await t.pump();
      Future<Uint8List> pixels(String frame) async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await boundary.toImage();
        final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (const bool.fromEnvironment('PIP_ERROR_CAPTURE')) {
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          await File('/private/tmp/pip-error-$name-$frame.png')
              .writeAsBytes(png!.buffer.asUint8List());
        }
        img.dispose();
        return data!.buffer.asUint8List();
      }

      final before = (await t.runAsync(() => pixels('open')))!;
      await t.pump(const Duration(milliseconds: 2650));
      final blink = (await t.runAsync(() => pixels('blink')))!;
      if (reduced || !visible) {
        expect(blink, orderedEquals(before));
        expect(t.binding.hasScheduledFrame, false);
      } else {
        expect(blink, isNot(orderedEquals(before)));
        // Lower artwork contains the phone, hands and seated body.
        expect(blink.sublist(220 * 4 * 132),
            orderedEquals(before.sublist(220 * 4 * 132)));
      }
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
}
