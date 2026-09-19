import 'package:flutter/material.dart';

/// The small, role-based typography system used throughout Flixie.
///
/// Prefer the semantic styles exposed by [ThemeData.textTheme]. These named
/// styles are provided for UI roles that Material's text theme does not name
/// directly, such as watch-plan eyebrows and prominent ratings.
abstract final class FlixieTypography {
  static const String fontFamily = 'Manrope';

  static const TextStyle heroTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 30,
    height: 1.2,
    letterSpacing: -0.6,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle pageTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    height: 1.23,
    letterSpacing: -0.26,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle sheetTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    height: 1.25,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle supporting = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 1.43,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle metadata = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    height: 1.38,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle eyebrow = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 1.33,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.96,
  );

  static const TextStyle compactLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 1.33,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 1.375,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle rating = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w800,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  static TextTheme textTheme({
    required Color primary,
    required Color secondary,
    required Color muted,
  }) {
    return TextTheme(
      displayLarge: heroTitle.copyWith(color: primary),
      displayMedium: pageTitle.copyWith(color: primary),
      displaySmall: sheetTitle.copyWith(color: primary),
      headlineLarge: pageTitle.copyWith(color: primary),
      headlineMedium: sheetTitle.copyWith(color: primary),
      headlineSmall: sectionTitle.copyWith(color: primary),
      titleLarge: sectionTitle.copyWith(color: primary),
      titleMedium: cardTitle.copyWith(color: primary),
      titleSmall: supporting.copyWith(
        color: secondary,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: bodyLarge.copyWith(color: primary),
      bodyMedium: body.copyWith(color: primary),
      bodySmall: metadata.copyWith(color: muted),
      labelLarge: button.copyWith(color: primary),
      labelMedium: compactLabel.copyWith(color: secondary),
      labelSmall: compactLabel.copyWith(color: muted),
    );
  }
}
