import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/widgets/pip_startup_brand.dart';
import 'package:flixie_app/features/home/presentation/widgets/home_startup_gate.dart';

void main() {
  Widget host(bool ready, VoidCallback tap) => MaterialApp(
      home: HomeStartupGate(
          ready: ready,
          child: Scaffold(
              body: TextButton(
                  onPressed: tap, child: const Text('Home action')))));
  testWidgets('holds initial Home until ready and never blocks refreshes',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(false, () => taps++));
    expect(find.byType(PipStartupBrand), findsOneWidget);
    expect(find.text('Home action').hitTestable(), findsNothing);
    await tester.pumpWidget(host(true, () => taps++));
    await tester.pump();
    expect(find.byType(PipStartupBrand), findsNothing);
    await tester.tap(find.text('Home action'));
    expect(taps, 1);
    await tester.pumpWidget(host(false, () => taps++));
    expect(find.byType(PipStartupBrand), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'slow connection stays covered until the user chooses to continue',
      (tester) async {
    await tester.pumpWidget(host(false, () {}));
    await tester.pump(const Duration(seconds: 6));
    expect(find.byType(PipStartupBrand), findsOneWidget);
    expect(find.text('Home action').hitTestable(), findsNothing);
    await tester.pump(const Duration(seconds: 14));
    expect(find.byType(PipStartupBrand), findsOneWidget);
    expect(find.text('Home action').hitTestable(), findsNothing);
    await tester.tap(find.text('Continue to Home'));
    await tester.pump();
    expect(find.byType(PipStartupBrand), findsNothing);
    expect(find.text('Home action').hitTestable(), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('late ready data still reveals automatically after the slow notice',
      (tester) async {
    await tester.pumpWidget(host(false, () {}));
    await tester.pump(const Duration(seconds: 21));
    expect(find.byType(PipStartupBrand), findsOneWidget);
    await tester.pumpWidget(host(true, () {}));
    await tester.pump();
    expect(find.byType(PipStartupBrand), findsNothing);
    expect(find.text('Home action').hitTestable(), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('background Home never covers a direct-link destination',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: TickerMode(
            enabled: false,
            child: HomeStartupGate(
                ready: false, child: Text('Background Home')))));
    await tester.pump();
    expect(find.byType(PipStartupBrand), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
