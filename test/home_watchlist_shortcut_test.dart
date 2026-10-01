import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/home/presentation/widgets/home_watchlist_action.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Home Watchlist action works at $width / $scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var opened = false;
        await tester.pumpWidget(MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: Scaffold(
                appBar: AppBar(title: const Text('flixie'), actions: [
              HomeWatchlistAction(onPressed: () => opened = true),
              IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.notifications_outlined)),
            ]))));
        await tester.tap(find.byType(HomeWatchlistAction));
        expect(opened, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
