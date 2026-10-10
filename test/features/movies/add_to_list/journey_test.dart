import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'journey.dart';

void main() {
  testWidgets('membership failure blocks editing until a successful retry',
      (tester) => addToListJourney(tester, membershipRetry: true));
  setUpAll(() async {
    await (FontLoader('Manrope')
          ..addFont(
              rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
        .load();
  });
  testWidgets('add-to-list lazy collaborators and selected created list',
      addToListJourney);
  testWidgets('collaborator retry, save and undo',
      (tester) => addToListJourney(tester, retry: true, saveAndUndo: true));
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1024, 1366)
  ]) {
    testWidgets('creation works at $size with large text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await addToListJourney(tester);
    });
  }
}
