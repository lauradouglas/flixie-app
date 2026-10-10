import 'package:flutter/material.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/movies/presentation/widgets/media_backdrop_inset.dart';

void main() {
  testWidgets('loading poster clips to the loaded poster corner shape',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: MediaDetailPreview(title: 'Alien', reserveBackdrop: true))));
    final clip = tester.widget<ClipRRect>(find
        .descendant(
            of: find.byType(MediaDetailPreview),
            matching: find.byType(ClipRRect))
        .first);
    expect(clip.borderRadius,
        const BorderRadius.horizontal(right: Radius.circular(12)));
  });

  for (final backdrop in [false, true]) {
    for (final reduced in [false, true]) {
      testWidgets('backdrop $backdrop reduced motion $reduced', (tester) async {
        const marker = Key('poster');
        await tester.pumpWidget(MaterialApp(
            home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Align(
              alignment: Alignment.topLeft,
              child: MediaBackdropInset(
                  animate: true,
                  hasBackdrop: backdrop,
                  width: 390,
                  top: 0,
                  bottom: 0,
                  child: const SizedBox(key: marker, width: 100, height: 150))),
        )));
        final initial = tester.getTopLeft(find.byKey(marker)).dy;
        expect(initial, backdrop || !reduced ? closeTo(148.2, .01) : 0);
        await tester.pump(const Duration(milliseconds: 140));
        final middle = tester.getTopLeft(find.byKey(marker)).dy;
        if (!backdrop && !reduced) {
          expect(middle, greaterThan(0));
          expect(middle, lessThan(initial));
        }
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.byKey(marker)).dy,
            backdrop ? closeTo(148.2, .01) : 0);
      });
    }
  }
}
