import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/widgets/flixie_section_header.dart';

void main() {
  testWidgets('movie section headings lay out inside a row with semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const FlixieSectionHeader(title: 'Top Cast'),
            TextButton(onPressed: () {}, child: const Text('See all')),
          ],
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.text('Top Cast')).width, greaterThan(0));
    expect(find.bySemanticsLabel('Top Cast'), findsOneWidget);
    semantics.dispose();
  });
  testWidgets('section actions remain tappable with long large headings',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2)),
      child: SizedBox(
          width: 280,
          child: FlixieSectionHeader(
            title: 'Recommendations from your favourite communities',
            badge: 12,
            trailingLabel: 'See all',
            onTrailingTap: () => taps++,
          )),
    ))));
    expect(tester.takeException(), isNull);
    final title = tester.widget<Text>(
        find.text('Recommendations from your favourite communities'));
    expect(title.maxLines, isNull);
    expect(title.style?.fontSize, 20);
    expect(title.style?.fontWeight, FontWeight.w700);
    await tester.tap(find.text('See all'));
    expect(taps, 1);
  });
  testWidgets('See all stays at the right edge of the section', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
      width: 400,
      child: FlixieSectionHeader(
          title: 'Watch together',
          trailingLabel: 'See all',
          onTrailingTap: () {}),
    ))));
    expect(tester.getRect(find.byType(TextButton)).right, 400);
    expect(tester.takeException(), isNull);
  });
}
