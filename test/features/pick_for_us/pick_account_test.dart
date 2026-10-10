import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/pick_for_us/pick_for_us_screen.dart';
import 'people_baseline_test.dart' show CountingPickService;
import '../../pick_for_us_test.dart' show scroll;

void main() {
  testWidgets('changing account resets the flow and viewer cache',
      (tester) async {
    final service = CountingPickService();
    Future<void> mount(String id) => tester.pumpWidget(MaterialApp(
          home: PickForUsScreen(userId: id, service: service),
        ));
    await mount('first');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next · Your evening'));
    await tester.pumpAndSettle();
    await scroll(tester, find.text('With a friend'), 150);
    await tester.tap(find.text('With a friend'));
    await tester.pumpAndSettle();
    expect(service.friendReads, 1);
    await mount('second');
    await tester.pumpAndSettle();
    expect(find.text('Next · Your evening'), findsOneWidget);
    expect(find.text('Alex'), findsNothing);
    await tester.tap(find.text('Next · Your evening'));
    await tester.pumpAndSettle();
    await scroll(tester, find.text('With a friend'), 150);
    await tester.tap(find.text('With a friend'));
    await tester.pumpAndSettle();
    expect(service.friendReads, 2);
    expect(service.groupReads, 0);
    expect(tester.takeException(), isNull);
  });
}
