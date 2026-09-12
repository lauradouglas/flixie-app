import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(844, 390),
    const Size(834, 1194)
  ]) {
    testWidgets('prompt is full width and scrolls at large text on $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      bool? result;
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                      onPressed: () async {
                        result = await showFlixiePromptSheet<bool>(
                            context: context,
                            builder: (sheetContext) => FlixiePromptSheetContent(
                                  title: const Text('Remove from watchlist?'),
                                  content: Text(List.filled(
                                          12, 'Your watch history stays saved.')
                                      .join(' ')),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(sheetContext, true),
                                        child: const Text('Remove'))
                                  ],
                                ));
                      },
                      child: const Text('Open'),
                    ))),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(BottomSheet)).width, size.width);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.scrollUntilVisible(find.text('Remove'), 150,
          scrollable: find.byType(Scrollable).last);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
