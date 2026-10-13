import 'package:flixie_app/core/navigation/instant_swipe_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> openPost(WidgetTester tester) async {
    await tester.pumpWidget(CupertinoApp(
      home: Builder(
          builder: (context) => CupertinoPageScaffold(
                child: Center(
                    child: CupertinoButton(
                  onPressed: () => Navigator.of(context)
                      .push<void>(const InstantSwipePage<void>(
                    dismissDuration: Duration(milliseconds: 180),
                    swipeSettleDuration: Duration(milliseconds: 180),
                    child: CupertinoPageScaffold(
                      navigationBar:
                          CupertinoNavigationBar(middle: Text('Post')),
                      child: Center(child: Text('Activity content')),
                    ),
                  ).createRoute(context)),
                  child: const Text('Open activity'),
                )),
              )),
    ));
    await tester.tap(find.text('Open activity'));
    await tester.pumpAndSettle();
  }

  testWidgets('back returns to feed within 180 ms', (tester) async {
    await openPost(tester);
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 181));
    await tester.pump();
    expect(find.text('Activity content'), findsNothing);
    expect(find.text('Open activity'), findsOneWidget);
  });

  testWidgets('completed edge swipe returns to feed within 180 ms',
      (tester) async {
    await openPost(tester);
    final gesture = await tester.startGesture(const Offset(1, 300));
    await gesture.moveBy(const Offset(500, 0));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 181));
    await tester.pump();
    expect(find.text('Activity content'), findsNothing);
    expect(find.text('Open activity'), findsOneWidget);
  });

  testWidgets('cancelled edge swipe keeps the post and permits back',
      (tester) async {
    await openPost(tester);
    final gesture = await tester.startGesture(const Offset(1, 300));
    await gesture.moveBy(const Offset(100, 0));
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 181));
    await tester.pump();
    expect(find.text('Activity content'), findsOneWidget);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.userGestureInProgress, isFalse);
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await tester.pumpAndSettle();
    expect(find.text('Open activity'), findsOneWidget);
  });
}
