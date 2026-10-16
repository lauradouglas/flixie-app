import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/widgets/pip_reaction.dart';

void main() {
  testWidgets('received Pip opens large preview without reacting to parent',
      (tester) async {
    var reacted = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: TextButton(
                    onPressed: () => reacted++,
                    child: const PipReactionCount('😂', 3))))));
    await tester.tap(find.byType(PipReaction));
    await tester.pumpAndSettle();
    expect(find.text('Laughing'), findsOneWidget);
    expect(find.text('3 reactions'), findsOneWidget);
    expect(
        tester
            .widgetList<PipReaction>(find.byType(PipReaction))
            .any((p) => p.size == 200),
        isTrue);
    expect(reacted, 0);
    await tester.tap(find.byTooltip('Close preview'));
    await tester.pumpAndSettle();
    expect(find.text('Laughing'), findsNothing);
  });
  testWidgets('selector artwork does not open a preview', (tester) async {
    var selected = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: TextButton(
                    onPressed: () => selected++,
                    child: const PipReaction('😂'))))));
    await tester.tap(find.byType(PipReaction));
    expect(selected, 1);
    expect(find.text('Laughing'), findsNothing);
  });
}
