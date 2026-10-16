import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/home/presentation/widgets/recommendations_loading_card.dart';
import 'package:flixie_app/features/home/presentation/widgets/pip_loading_strip.dart';

void main() {
  for (final width in [320.0, 834.0]) {
    testWidgets('refresh card fills recommendation area at $width',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(
              body:
                  SingleChildScrollView(child: RecommendationsLoadingCard()))));
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.byType(PipLoadingStrip), findsOneWidget);
      expect(find.text('Finding fresh picks for you…'), findsOneWidget);
      expect(tester.getSize(find.byType(Container)).width, width - 32);
      expect(tester.getSize(find.byType(Container)).height,
          greaterThanOrEqualTo(270));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
