import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/safety/safety_actions.dart';

void main() {
  testWidgets('last report reason is reachable in landscape with large text',
      (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: Scaffold(
          body: Builder(
              builder: (context) => TextButton(
                    onPressed: () =>
                        SafetyActions.report(context, targetType: 'USER'),
                    child: const Text('Open report'),
                  ))),
    ));
    await tester.tap(find.text('Open report'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Something else'), 150);
    expect(find.text('Something else').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
