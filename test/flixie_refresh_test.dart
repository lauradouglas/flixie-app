import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/widgets/flixie_refresh.dart';
import 'package:flixie_app/core/navigation/navigation_retap_region.dart';

void main() {
  for (final short in [true, false]) {
    testWidgets('iOS pull refresh retains content, short=$short',
        (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      var haptics = 0;
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics++;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: Scaffold(
              body: FlixieRefresh(
                  onRefresh: () {
                    calls++;
                    return pending.future;
                  },
                  child: ListView.builder(
                      itemCount: short ? 1 : 40,
                      itemBuilder: (_, i) => SizedBox(
                          height: 70, child: Text('Saved item $i')))))));
      final gesture = await tester.startGesture(const Offset(150, 180));
      await gesture.moveBy(const Offset(0, 45));
      await tester.pump();
      expect(find.text('Pull to refresh'), findsOneWidget);
      expect(calls, 0);
      await gesture.moveBy(const Offset(0, 350));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      expect(find.text('Release to refresh'), findsOneWidget);
      if (short && const bool.fromEnvironment('REFRESH_CAPTURE')) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byType(RepaintBoundary).first);
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('/tmp/flixie-native-refresh.png')
              .writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(calls, 1);
      expect(haptics, 1);
      expect(find.text('Saved item 0'), findsOneWidget);
      pending.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'tab refresh scrolls native content to top and coalesces requests',
      (tester) async {
    final region = GlobalKey<NavigationRetapRegionState>();
    final pending = Completer<void>();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Scaffold(
            body: NavigationRetapRegion(
                key: region,
                child: FlixieRefresh(
                    onRefresh: () {
                      calls++;
                      return pending.future;
                    },
                    child: ListView.builder(
                        controller: controller,
                        itemCount: 50,
                        itemBuilder: (_, i) =>
                            SizedBox(height: 70, child: Text('Item $i'))))))));
    controller.jumpTo(700);
    await tester.pump();
    final first = region.currentState!.refresh();
    final second = region.currentState!.refresh();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(controller.offset, 0);
    expect(calls, 1);
    expect(find.text('Refreshing…'), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    await Future.wait([first, second]);
    expect(find.byType(CupertinoSliverRefreshControl, skipOffstage: false),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
