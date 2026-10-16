import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/home/presentation/widgets/pip_loading_strip.dart';

void main() {
  Future<void> show(WidgetTester tester, {bool reduced = false}) =>
      tester.pumpWidget(MaterialApp(
          home: MediaQuery(
              data: MediaQueryData(
                  disableAnimations: reduced,
                  textScaler: const TextScaler.linear(2)),
              child: const Scaffold(
                  body: SizedBox(width: 320, child: PipLoadingStrip())))));
  testWidgets('delays Pip, skips within strip and cancels on removal',
      (tester) async {
    await show(tester);
    expect(find.byType(Image), findsNothing);
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.byType(Image), findsOneWidget);
    final start = tester.getTopLeft(find.byType(Image));
    await tester.pump(const Duration(milliseconds: 1500));
    final next = tester.getTopLeft(find.byType(Image));
    expect(next.dx, greaterThan(start.dx));
    expect(next.dx, lessThan(320));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
    expect(tester.takeException(), isNull);
  });
  testWidgets('reduced motion keeps Pip still and status readable',
      (tester) async {
    await show(tester, reduced: true);
    await tester.pump(const Duration(milliseconds: 450));
    final before = tester.getTopLeft(find.byType(Image));
    await tester.pump(const Duration(seconds: 3));
    expect(tester.getTopLeft(find.byType(Image)), before);
    expect(find.text('Finding your next great watch…'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
