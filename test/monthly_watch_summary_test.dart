import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/profile/presentation/widgets/monthly_watch_summary.dart';

void main() {
  testWidgets('empty month offers discovery and logging instead of zero totals',
      (tester) async {
    var discover = 0, log = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MonthlyWatchSummary(
                movies: 0,
                episodes: 0,
                onDiscover: () => discover++,
                onLog: () => log++))));
    expect(find.text('0 movie watches · 0 episodes'), findsNothing);
    await tester.tap(find.text('Find something to watch'));
    await tester.tap(find.text('Log something I’ve watched'));
    expect(discover, 1);
    expect(log, 1);
  });
  testWidgets('a month with activity retains its real totals', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: MonthlyWatchSummary(
            movies: 0, episodes: 3, onDiscover: () {}, onLog: () {})));
    expect(find.text('0 movie watches · 3 episodes'), findsOneWidget);
    expect(find.text('Find something to watch'), findsNothing);
  });
}
