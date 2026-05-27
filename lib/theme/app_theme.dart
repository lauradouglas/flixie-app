import 'package:flutter/material.dart';

/// Flixie color palette — cinematic dark theme.
class FlixieColors {
  // Primary – vivid purple
  static const Color primary = Color(0xFF9B6BFF);
  static const Color primaryShade = Color(0xFF7C4DFF);
  static const Color primaryTint = Color(0xFFB388FF);

  // Secondary – cyan accent
  static const Color secondary = Color(0xFF00D1C7);
  static const Color secondaryShade = Color(0xFF00B8AF);
  static const Color secondaryTint = Color(0xFF26D9D0);

  // Tertiary – peach/orange
  static const Color tertiary = Color(0xFFF1A77A);
  static const Color tertiaryShade = Color(0xFFD4936B);
  static const Color tertiaryTint = Color(0xFFF2B087);

  // Success – vivid green
  static const Color success = Color(0xFF00D97E);
  static const Color successShade = Color(0xFF00C070);
  static const Color successTint = Color(0xFF26E090);

  // Warning – gold (bookmark / favourite)
  static const Color warning = Color(0xFFFFC857);
  static const Color warningShade = Color(0xFFE0B04C);
  static const Color warningTint = Color(0xFFFFD066);

  // Danger – red
  static const Color danger = Color(0xFFE57373);
  static const Color dangerShade = Color(0xFFCA6565);
  static const Color dangerTint = Color(0xFFE88181);

  // Text hierarchy
  static const Color textPrimary = Color(0xFFF5F7FA);
  static const Color light = Color(0xFFB7C2D0);   // secondary text
  static const Color lightShade = Color(0xFFA0ACBD);
  static const Color lightTint = Color(0xFFC7D1E2);

  // Muted text
  static const Color medium = Color(0xFF7F91A8);
  static const Color mediumShade = Color(0xFF6C7D93);
  static const Color mediumTint = Color(0xFF8E9FB5);

  // Dark – deep navy
  static const Color dark = Color(0xFF1C3391);
  static const Color darkShade = Color(0xFF192D80);
  static const Color darkTint = Color(0xFF33479C);

  // Background / navigation
  static const Color background = Color(0xFF061625);
  static const Color surface = Color(0xFF0B2035);
  static const Color surfaceElevated = Color(0xFF12345A);
  static const Color navy = Color(0xFF040F1C);
  static const Color white = Color(0xFFFFFFFF);
  static const Color tabBarBackground = Color(0xFF0A1828);
  static const Color tabBarBackgroundFocused = surface;
  static const Color tabBarBorder = Color(0xFF1A3352);

  // Watchlist card gradient colours
  static const Color cardGradientTop = Color(0xF2102B4A);    // rgba(16,43,74,0.95)
  static const Color cardGradientBottom = Color(0xFA081727); // rgba(8,23,39,0.98)
}

/// Builds the app-wide [ThemeData] using the Flixie color palette.
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: FlixieColors.primary,
      onPrimary: Colors.black,
      primaryContainer: FlixieColors.primaryShade,
      onPrimaryContainer: FlixieColors.light,
      secondary: FlixieColors.secondary,
      onSecondary: Colors.black,
      secondaryContainer: FlixieColors.secondaryShade,
      onSecondaryContainer: FlixieColors.light,
      tertiary: FlixieColors.tertiary,
      onTertiary: Colors.black,
      tertiaryContainer: FlixieColors.tertiaryShade,
      onTertiaryContainer: FlixieColors.light,
      error: FlixieColors.danger,
      onError: Colors.black,
      errorContainer: FlixieColors.dangerShade,
      onErrorContainer: FlixieColors.light,
      surface: FlixieColors.surface,
      onSurface: FlixieColors.light,
      surfaceContainerHighest: FlixieColors.surfaceElevated,
      onSurfaceVariant: FlixieColors.medium,
      outline: FlixieColors.mediumShade,
      shadow: Colors.black,
      scrim: Colors.black54,
      inverseSurface: FlixieColors.light,
      onInverseSurface: FlixieColors.background,
      inversePrimary: FlixieColors.primaryShade,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent,

      // App bar
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: FlixieColors.light,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: FlixieColors.light,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: FlixieColors.light),
      ),

      // Bottom navigation bar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: FlixieColors.tabBarBackground,
        selectedItemColor: FlixieColors.primary,
        unselectedItemColor: FlixieColors.medium,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Navigation bar (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: FlixieColors.tabBarBackground,
        indicatorColor: FlixieColors.primary.withValues(alpha: 0.15),
        indicatorShape: const StadiumBorder(),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: FlixieColors.primary);
          }
          return const IconThemeData(color: FlixieColors.medium);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: FlixieColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            );
          }
          return const TextStyle(
              color: FlixieColors.medium, fontSize: 11);
        }),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
      ),

      // Cards
      cardTheme: CardThemeData(
        color: FlixieColors.surface,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),

      // Elevated buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FlixieColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          shadowColor: FlixieColors.primary.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),

      // Outlined buttons
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: FlixieColors.primary,
          side: const BorderSide(color: FlixieColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      // Text buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: FlixieColors.primary,
        ),
      ),

      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FlixieColors.surface,
        labelStyle: const TextStyle(color: FlixieColors.medium),
        hintStyle: const TextStyle(color: FlixieColors.mediumShade),
        prefixIconColor: FlixieColors.medium,
        suffixIconColor: FlixieColors.medium,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FlixieColors.tabBarBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FlixieColors.tabBarBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FlixieColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FlixieColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FlixieColors.danger, width: 2),
        ),
      ),

      // Chip theme
      chipTheme: ChipThemeData(
        backgroundColor: FlixieColors.tabBarBorder,
        labelStyle: const TextStyle(color: FlixieColors.light),
        selectedColor: FlixieColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      // Floating action button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: FlixieColors.primary,
        foregroundColor: Colors.black,
      ),

      // Progress indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: FlixieColors.primary,
        linearTrackColor: FlixieColors.tabBarBorder,
        circularTrackColor: FlixieColors.tabBarBorder,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: FlixieColors.tabBarBorder,
        thickness: 1,
      ),

      // Icon theme
      iconTheme: const IconThemeData(color: FlixieColors.light),

      // Text theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: FlixieColors.white,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: FlixieColors.white,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: TextStyle(
          color: FlixieColors.white,
          fontWeight: FontWeight.bold,
        ),
        headlineLarge: TextStyle(
          color: FlixieColors.white,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: FlixieColors.white,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: TextStyle(
          color: FlixieColors.light,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: FlixieColors.light,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(color: FlixieColors.light),
        titleSmall: TextStyle(color: FlixieColors.medium),
        bodyLarge: TextStyle(color: FlixieColors.light),
        bodyMedium: TextStyle(color: FlixieColors.light),
        bodySmall: TextStyle(color: FlixieColors.medium),
        labelLarge: TextStyle(
          color: FlixieColors.light,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: TextStyle(color: FlixieColors.medium),
        labelSmall: TextStyle(color: FlixieColors.mediumShade),
      ),
    );
  }

  static ThemeData get lightTheme {
    const _textDark = Color(0xFF1C1C2E);
    const _textMuted = Color(0xFF6B6B8A);
    const _surface = Color(0xFFF5F7FA);
    const _surfaceVariant = Color(0xFFE8EDF5);
    const _outline = Color(0xFFCDD2DC);

    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: FlixieColors.primary,
      onPrimary: Colors.white,
      primaryContainer: FlixieColors.primaryTint,
      onPrimaryContainer: _textDark,
      secondary: FlixieColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: FlixieColors.secondaryTint,
      onSecondaryContainer: _textDark,
      tertiary: FlixieColors.tertiary,
      onTertiary: Colors.white,
      tertiaryContainer: FlixieColors.tertiaryTint,
      onTertiaryContainer: _textDark,
      error: FlixieColors.danger,
      onError: Colors.white,
      errorContainer: FlixieColors.dangerTint,
      onErrorContainer: _textDark,
      surface: _surface,
      onSurface: _textDark,
      surfaceContainerHighest: _surfaceVariant,
      onSurfaceVariant: _textMuted,
      outline: _outline,
      shadow: Colors.black,
      scrim: Colors.black54,
      inverseSurface: _textDark,
      onInverseSurface: _surface,
      inversePrimary: FlixieColors.primaryShade,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: _surface,
        foregroundColor: _textDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: _textDark,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: _textDark),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _surface,
        selectedItemColor: FlixieColors.primary,
        unselectedItemColor: _textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _surface,
        indicatorColor: FlixieColors.primary.withValues(alpha: 0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: FlixieColors.primary);
          }
          return const IconThemeData(color: _textMuted);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: FlixieColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(color: _textMuted, fontSize: 12);
        }),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.07)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FlixieColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: FlixieColors.primary,
          side: const BorderSide(color: FlixieColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: FlixieColors.primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: _textMuted),
        hintStyle: const TextStyle(color: _textMuted),
        prefixIconColor: _textMuted,
        suffixIconColor: _textMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: FlixieColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: FlixieColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: FlixieColors.danger, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _surfaceVariant,
        labelStyle: const TextStyle(color: _textDark),
        selectedColor: FlixieColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: FlixieColors.primary,
        foregroundColor: Colors.white,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: FlixieColors.primary,
        linearTrackColor: _outline,
        circularTrackColor: _outline,
      ),
      dividerTheme: const DividerThemeData(color: _outline, thickness: 1),
      iconTheme: const IconThemeData(color: _textDark),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: _textDark, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: _textDark, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(color: _textDark, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(color: _textDark, fontWeight: FontWeight.bold),
        headlineMedium:
            TextStyle(color: _textDark, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(color: _textDark, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: _textDark, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: _textDark),
        titleSmall: TextStyle(color: _textMuted),
        bodyLarge: TextStyle(color: _textDark),
        bodyMedium: TextStyle(color: _textDark),
        bodySmall: TextStyle(color: _textMuted),
        labelLarge: TextStyle(color: _textDark, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(color: _textMuted),
        labelSmall: TextStyle(color: _textMuted),
      ),
    );
  }
}
