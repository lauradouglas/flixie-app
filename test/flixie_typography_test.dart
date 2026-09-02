import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/app/theme/flixie_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Flixie typography', () {
    test('uses the bundled Manrope family throughout the app theme', () {
      expect(
        AppTheme.darkTheme.textTheme.bodyMedium?.fontFamily,
        FlixieTypography.fontFamily,
      );
      expect(
        AppTheme.lightTheme.textTheme.bodyMedium?.fontFamily,
        FlixieTypography.fontFamily,
      );
    });

    test('keeps the semantic hierarchy compact and consistent', () {
      expect(FlixieTypography.heroTitle.fontSize, 30);
      expect(FlixieTypography.pageTitle.fontSize, 26);
      expect(FlixieTypography.sheetTitle.fontSize, 24);
      expect(FlixieTypography.sectionTitle.fontSize, 20);
      expect(FlixieTypography.cardTitle.fontSize, 17);
      expect(FlixieTypography.body.fontSize, 15);
      expect(FlixieTypography.metadata.fontSize, 13);
      expect(FlixieTypography.eyebrow.fontSize, 12);
      expect(FlixieTypography.rating.fontSize, 20);
    });

    test('maps semantic roles onto Material text styles', () {
      final textTheme = FlixieTypography.textTheme(
        primary: Colors.white,
        secondary: Colors.grey,
        muted: Colors.blueGrey,
      );

      expect(textTheme.headlineLarge?.fontSize, 26);
      expect(textTheme.headlineSmall?.fontSize, 20);
      expect(textTheme.titleMedium?.fontSize, 17);
      expect(textTheme.bodyMedium?.fontSize, 15);
      expect(textTheme.labelLarge?.fontSize, 15);
      expect(textTheme.bodySmall?.fontSize, 13);
    });
  });
}
