import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/widgets/notification_opt_in.dart';

void main() {
  testWidgets('permission is requested only after an explicit tap',
      (tester) async {
    var requests = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: NotificationOptIn(
                check: () async => true,
                enable: () async {
                  requests++;
                  return true;
                }))));
    await tester.pumpAndSettle();
    expect(requests, 0);
    await tester.tap(find.text('Enable notifications'));
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(find.text('Enable notifications'), findsNothing);
  });
  testWidgets('declining the offer does not request permission',
      (tester) async {
    var requests = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: NotificationOptIn(
                check: () async => true,
                enable: () async {
                  requests++;
                  return true;
                }))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(requests, 0);
    expect(find.text('Enable notifications'), findsNothing);
  });
}
