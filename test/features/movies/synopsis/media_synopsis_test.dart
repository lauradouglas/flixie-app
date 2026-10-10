import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/movies/presentation/widgets/media_synopsis.dart';

void main() {
  const plot =
      'When the son of an L.A. family goes missing, his parents search '
      'the city for answers. Their journey takes them through unfamiliar streets '
      'and leads to unexpected discoveries. Every clue brings new questions, '
      'and they must work together to find him before time runs out.';

  for (final (width, scale) in [(320.0, 2.0), (430.0, 1.0), (1024.0, 1.0)]) {
    testWidgets('plot expands and collapses at width $width, text scale $scale',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var expanded = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: SingleChildScrollView(
              child: SizedBox(
                width: 280,
                child: StatefulBuilder(
                    builder: (context, setState) => MediaSynopsis(
                          text: plot,
                          style: const TextStyle(fontSize: 14, height: 1.48),
                          expanded: expanded,
                          onToggle: () => setState(() => expanded = !expanded),
                          actionColor: Colors.deepPurple,
                        )),
              ),
            ),
          ),
        ),
      ));
      // The preview keeps the complete source, including text after L.A.
      expect(find.text(plot), findsOneWidget);
      expect(find.text('When the son of an L.A.'), findsNothing);
      expect(tester.widget<Text>(find.text(plot)).maxLines, 3);
      await tester.tap(find.text('Read more'));
      await tester.pump();
      expect(tester.widget<Text>(find.text(plot)).maxLines, isNull);
      await tester.ensureVisible(find.text('Show less'));
      await tester.tap(find.text('Show less'));
      await tester.pump();
      expect(tester.widget<Text>(find.text(plot)).maxLines, 3);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('short plot containing abbreviations needs no expansion',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MediaSynopsis(
      text: 'Dr. Lee lives in L.A. He finds a clue.',
      style: const TextStyle(fontSize: 14),
      expanded: false,
      onToggle: () => fail('Short plot should not have a toggle'),
      actionColor: Colors.deepPurple,
    ))));
    expect(find.text('Dr. Lee lives in L.A. He finds a clue.'), findsOneWidget);
    expect(find.text('Read more'), findsNothing);
  });
}
