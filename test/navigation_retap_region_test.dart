import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/navigation/navigation_retap_region.dart';

void main() {
  testWidgets(
      'nested retained scopes refresh only the visible list and coalesce repeated taps',
      (tester) async {
    final key = GlobalKey<NavigationRetapRegionState>();
    final pending = Completer<void>();
    final counts = [0, 0];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: NavigationRetapRegion(
      key: key,
      child: IndexedStack(index: 1, children: [
        for (var i = 0; i < 2; i++)
          RefreshIndicator(
              onRefresh: () async {
                counts[i]++;
                await pending.future;
              },
              child: ListView.builder(
                  itemCount: 60,
                  itemExtent: 60,
                  itemBuilder: (_, j) => Text('Feed $i item $j'))),
      ]),
    ))));
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    final position =
        tester.state<ScrollableState>(find.byType(Scrollable)).position;
    final first = key.currentState!.refresh();
    final second = key.currentState!.refresh();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(position.pixels, 0);
    expect(counts, [0, 1]);
    pending.complete();
    await tester.pumpAndSettle();
    await Future.wait([first, second]);
    expect(tester.takeException(), isNull);
  });
}
