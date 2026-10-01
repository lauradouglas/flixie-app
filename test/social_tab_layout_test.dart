import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/social/presentation/widgets/segmented_toggle.dart';

void main() {
  for (final width in [320.0, 430.0, 768.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('social labels fit at $width with text scale $scale',
          (tester) async {
        var selected = -1;
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
              width: width,
              child: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: SocialSegmentedToggle(
                  selectedIndex: 3,
                  labels: const ['Activity', 'People', 'Groups', 'Communities'],
                  onChanged: (index) => selected = index,
                ),
              )),
        ))));
        final label = find.text('Communities');
        final paragraph = tester.renderObject<RenderParagraph>(label);
        expect(paragraph.didExceedMaxLines, isFalse);
        await tester.ensureVisible(label);
        await tester.tap(label);
        expect(selected, 3);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
