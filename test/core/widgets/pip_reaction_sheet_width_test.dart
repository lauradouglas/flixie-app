import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/widgets/pip_reaction.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_reaction_bubble.dart';

void main() {
  for (final size in [const Size(834, 1194), const Size(1366, 1024)]) {
    testWidgets('tablet sheet spans ${size.width} with all twelve Pips',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () =>
                          showActivityReactionBubble(context, context),
                      child: const Text('React'))))));
      await tester.tap(find.text('React'));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(BottomSheet)).width, size.width);
      expect(find.byType(PipReaction), findsNWidgets(12));
      expect(tester.takeException(), isNull);
    });
  }
}
