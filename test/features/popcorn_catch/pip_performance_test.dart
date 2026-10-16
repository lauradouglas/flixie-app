import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/popcorn_catch/presentation/widgets/pip_performance.dart';

void main() {
  testWidgets('celebration performs crouch, leap, landing and dance once',
      (t) async {
    await t.pumpWidget(const MaterialApp(
        home: SizedBox(
            width: 250,
            height: 300,
            child: PipPerformance(mood: PipPerformanceMood.celebrate))));
    String pose() =>
        (t.widget<Image>(find.byType(Image)).image as AssetImage).assetName;
    expect(pose(), endsWith('crouch.png'));
    await t.pump(const Duration(milliseconds: 850));
    expect(pose(), endsWith('leap.png'));
    await t.pump(const Duration(milliseconds: 850));
    expect(pose(), endsWith('land.png'));
    await t.pump(const Duration(milliseconds: 850));
    expect(pose(), endsWith('dance.png'));
    await t.pumpAndSettle();
    expect(pose(), endsWith('dance.png'));
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'rough round uses sad bucket; reduced motion holds the final pose',
      (t) async {
    for (final mood in [
      PipPerformanceMood.rough,
      PipPerformanceMood.celebrate
    ]) {
      await t.pumpWidget(MaterialApp(
          home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: PipPerformance(key: ValueKey(mood), mood: mood))));
      await t.pumpAndSettle();
      final asset =
          (t.widget<Image>(find.byType(Image)).image as AssetImage).assetName;
      expect(asset,
          endsWith(mood == PipPerformanceMood.rough ? 'sad.png' : 'dance.png'));
      expect(t.takeException(), isNull);
    }
  });
}
