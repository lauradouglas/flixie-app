import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/social/presentation/widgets/social_activity_view.dart';

void main() {
  testWidgets(
      'Activity scopes mount lazily and retain scrolling across switches',
      (tester) async {
    final controllers = List.generate(3, (_) => ScrollController());
    addTearDown(() {
      for (final c in controllers) {
        c.dispose();
      }
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SocialActivityView(feeds: [
      for (var i = 0; i < 3; i++)
        ListView(controller: controllers[i], children: [
          for (var j = 0; j < 60; j++)
            SizedBox(height: 60, child: Text('feed $i post $j'))
        ]),
    ]))));
    expect(controllers[0].hasClients, isTrue);
    expect(controllers[1].hasClients, isFalse);
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    final offset = controllers[0].offset;
    await tester.tap(find.text('Friends'));
    await tester.pumpAndSettle();
    expect(find.text('feed 1 post 0'), findsOneWidget);
    await tester.tap(find.text('Around Flixie'));
    await tester.pumpAndSettle();
    expect(find.text('feed 2 post 0'), findsOneWidget);
    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();
    expect(controllers[0].offset, offset);
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
