import 'package:flutter/material.dart';

/// Flixie color palette derived from the Ionic app color scheme.
class FlixieColors {
  // Primary – purple
  static const Color primary = Color(0xFF947AF1);
  static const Color primaryShade = Color(0xFF826BD4);
  static const Color primaryTint = Color(0xFF9F87F2);

  // Secondary – teal
  static const Color secondary = Color(0xFF08A391);
  static const Color secondaryShade = Color(0xFF078F80);
  static const Color secondaryTint = Color(0xFF21AC9C);

  // Tertiary – peach/orange
  static const Color tertiary = Color(0xFFF1A77A);
  static const Color tertiaryShade = Color(0xFFD4936B);
  static const Color tertiaryTint = Color(0xFFF2B087);

  // Success – green
  static const Color success = Color(0xFF30C48D);
  static const Color successShade = Color(0xFF2AAC7C);
  static const Color successTint = Color(0xFF45CA98);

  // Warning – yellow
  static const Color warning = Color(0xFFFFD166);
  static const Color warningShade = Color(0xFFE0B85A);
  static const Color warningTint = Color(0xFFFFD675);

  // Danger – red
  static const Color danger = Color(0xFFE57373);
  static const Color dangerShade = Color(0xFFCA6565);
  static const Color dangerTint = Color(0xFFE88181);

  // Light – light blue-grey
  static const Color light = Color(0xFFC1CCDF);
  static const Color lightShade = Color(0xFFAAB4C4);
  static const Color lightTint = Color(0xFFC7D1E2);

  // Medium – grey-blue
  static const Color medium = Color(0xFF6C7A89);
  static const Color mediumShade = Color(0xFF5F6B79);
  static const Color mediumTint = Color(0xFF7B8795);

  // Dark – deep navy
  static const Color dark = Color(0xFF1C3391);
  static const Color darkShade = Color(0xFF192D80);
  static const Color darkTint = Color(0xFF33479C);

  // Background / navigation
  static const Color background = Color(0xFF172B4D);
  static const Color navy = Color(0xFF001F3F);
  static const Color white = Color(0xFFFFFFFF);
  static const Color tabBarBackground = Color(0xFF172B4D);
  static const Color tabBarBackgroundFocused = Color(0xFF1B3258);
  static const Color tabBarBorder = Color(0xFF1B325B);
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
      surface: FlixieColors.tabBarBackgroundFocused,
      onSurface: FlixieColors.light,
      surfaceContainerHighest: FlixieColors.tabBarBorder,
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
      scaffoldBackgroundColor: FlixieColors.background,

      // App bar
      appBarTheme: const AppBarTheme(
        backgroundColor: FlixieColors.tabBarBackgroundFocused,
        foregroundColor: FlixieColors.light,
        elevation: 0,
        centerTitle: true,
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
        indicatorColor: FlixieColors.primary.withValues(alpha: 0.2),
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
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(color: FlixieColors.medium, fontSize: 12);
        }),
        surfaceTintColor: Colors.transparent,
      ),

      // Cards
      cardTheme: CardThemeData(
        color: FlixieColors.tabBarBackgroundFocused,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // Elevated buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FlixieColors.primary,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
        fillColor: FlixieColors.tabBarBackgroundFocused,
        labelStyle: const TextStyle(color: FlixieColors.medium),
        hintStyle: const TextStyle(color: FlixieColors.mediumShade),
        prefixIconColor: FlixieColors.medium,
        suffixIconColor: FlixieColors.medium,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: FlixieColors.tabBarBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: FlixieColors.tabBarBorder),
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
          color: FlixieColors.light,
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
}