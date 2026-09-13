import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/social/presentation/widgets/segmented_toggle.dart';

void main() {
  testWidgets('chat counter fits narrow and wide layouts with large text',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [320.0, 430.0, 1024.0]) {
      await tester.binding.setSurfaceSize(Size(width, 700));
      for (final scale in [1.0, 2.0]) {
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
              width: width,
              child: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: SocialSegmentedToggle(
                  selectedIndex: 1,
                  labels: const ['Friends', 'Chats', 'Groups'],
                  counts: const {1: 125},
                  onChanged: (_) {},
                ),
              )),
        ))));
        expect(find.text('99+'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(MaterialApp(
        home: SocialSegmentedToggle(
      selectedIndex: 0,
      labels: const ['Friends', 'Chats', 'Groups'],
      onChanged: (_) {},
    )));
    expect(find.byType(Badge), findsNothing);
  });
}
