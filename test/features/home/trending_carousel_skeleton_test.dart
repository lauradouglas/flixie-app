import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/home/presentation/widgets/trending_carousel_skeleton.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
void main() {
  for (final width in [320.0, 390.0, 1024.0]) {
    testWidgets('carousel skeleton reserves artwork and detail space $width', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
        child: SizedBox(width: width, child: const TrendingCarouselSkeleton())))));
      expect(tester.getSize(find.byType(TrendingCarouselSkeleton)).height, 543);
      expect(find.byType(SkeletonBox), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
