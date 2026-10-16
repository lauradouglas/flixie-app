import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/widgets/pip_griddy.dart';

void main() {
  Future<void> show(WidgetTester t,
      {bool reduced = false, bool enabled = true}) async {
    await t.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: TickerMode(
                enabled: enabled, child: const Center(child: PipGriddy())))));
    await t.runAsync(() => precacheImage(
        const AssetImage(PipGriddy.asset), t.element(find.byType(PipGriddy))));
    await t.pump();
  }

  int frame(WidgetTester t) => t
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((w) => w.painter)
      .whereType<PipGriddyPainter>()
      .single
      .frame;
  testWidgets('dance advances articulated frames and loops continuously',
      (t) async {
    await show(t);
    final initial = frame(t);
    await t.pump(const Duration(milliseconds: 900));
    expect(frame(t), 4);
    expect(frame(t), isNot(initial));
    await t.pump(const Duration(milliseconds: 3200));
    expect(frame(t), 4);
    await t.pump(const Duration(milliseconds: 800));
    expect(frame(t), 8);
    expect(find.bySemanticsLabel('Pip dances the Griddy in his Flixie hoodie'),
        findsOneWidget);
    await t.pumpWidget(const SizedBox());
    expect(t.takeException(), isNull);
  });
  testWidgets('Reduce Motion and hidden routes hold a still pose', (t) async {
    await show(t, reduced: true);
    expect(frame(t), 0);
    await t.pump(const Duration(seconds: 3));
    expect(frame(t), 0);
    expect(t.binding.hasScheduledFrame, isFalse);
    await show(t, enabled: false);
    final still = frame(t);
    await t.pump(const Duration(seconds: 3));
    expect(frame(t), still);
    expect(t.binding.hasScheduledFrame, isFalse);
    await t.pumpWidget(const SizedBox());
    expect(t.takeException(), isNull);
  });
  testWidgets('backgrounding pauses the dance until foregrounded', (t) async {
    await show(t);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await t.pump();
    final paused = frame(t);
    await t.pump(const Duration(seconds: 2));
    expect(frame(t), paused);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(frame(t), isNot(paused));
    await t.pumpWidget(const SizedBox());
    expect(t.takeException(), isNull);
  });
}
