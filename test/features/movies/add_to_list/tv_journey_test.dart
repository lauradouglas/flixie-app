import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'journey.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Manrope')
          ..addFont(
              rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
        .load();
  });
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1024, 1366)
  ]) {
    testWidgets('TV picker at $size with large text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await addToListJourney(tester, show: true);
    });
  }
  testWidgets(
      'TV retry, save and undo',
      (tester) => addToListJourney(tester,
          show: true, membershipRetry: true, retry: true, saveAndUndo: true));
  testWidgets('TV membership and lazy creation baseline',
      (tester) => addToListJourney(tester, show: true));
}
