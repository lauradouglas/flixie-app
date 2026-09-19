export 'flixie_palette.dart';
import 'package:flixie_app/app/theme/flixie_pill_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'flixie_palette.dart';

import 'package:flixie_app/app/theme/flixie_typography.dart';

/// Flixie color palette - cinematic dark theme.
class FlixieColors {
  // Primary – vivid purple
  static const Color primary = Color(0xFF7C4DFF);
  static const Color primaryShade = Color(0xFF6534E8);
  static const Color primaryTint = Color(0xFFB9A0FF);
  // Accessible purple for normal-sized text on the dark surface ramp.
  static const Color primaryText = Color(0xFFB9A0FF);

  // Secondary – soft mint for social and shared-watch highlights
  static const Color secondary = Color(0xFF65D6C4);
  static const Color secondaryShade = Color(0xFF19776B);
  static const Color secondaryTint = Color(0xFF95E3D7);

  // Tertiary – peach/orange
  static const Color tertiary = Color(0xFFF1A77A);
  static const Color tertiaryShade = Color(0xFF99552D);
  static const Color tertiaryTint = Color(0xFFF2B087);

  // Functional colours stay distinct from the supporting brand accents.
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
  static const Color light = Color(0xFFB7C2D0); // secondary text
  static const Color lightShade = Color(0xFFA0ACBD);
  static const Color lightTint = Color(0xFFC7D1E2);

  // Muted text stays readable on the darkest and elevated surfaces.
  static const Color medium = Color(0xFFA0ACC0);
  static const Color mediumShade = Color(0xFF909EB5);
  static const Color mediumTint = Color(0xFFAFBACB);

  // Dark – deep navy
  static const Color dark = Color(0xFF1C3391);
  static const Color darkShade = Color(0xFF192D80);
  static const Color darkTint = Color(0xFF33479C);

  // Warm light surfaces and visible interactive boundaries.
  static const Color bone = Color(0xFFF3F0E9);
  static const Color lightTextSecondary = Color(0xFF51495F);
  static const Color controlOutline = Color(0xFF8C7AAE);

  // Background / navigation
  static const Color background = Color(0xFF120A24);
  static const Color surface = Color(0xFF1A1033);
  static const Color surfaceElevated = Color(0xFF27194A);
  static const Color navy = Color(0xFF0A0616);
  static const Color white = Color(0xFFFFFFFF);
  static const Color tabBarBackground = Color(0xFF140C29);
  static const Color tabBarBackgroundFocused = surface;
  static const Color tabBarBorder = Color(0xFF35245B);

  // Watchlist card gradient colours
  static const Color cardGradientTop = Color(0xF227194A); // rgba(39,25,74,0.95)
  static const Color cardGradientBottom =
      Color(0xFA0A0616); // rgba(10,6,22,0.98)
}

/// Builds the app-wide [ThemeData] using the Flixie color palette.
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: FlixieColors.primary,
      onPrimary: Colors.white,
      primaryContainer: FlixieColors.primaryShade,
      onPrimaryContainer: Colors.white,
      secondary: FlixieColors.secondary,
      onSecondary: FlixieColors.background,
      secondaryContainer: FlixieColors.secondaryShade,
      onSecondaryContainer: Colors.white,
      tertiary: FlixieColors.tertiary,
      onTertiary: FlixieColors.background,
      tertiaryContainer: FlixieColors.tertiaryShade,
      onTertiaryContainer: Colors.white,
      error: FlixieColors.danger,
      onError: FlixieColors.background,
      errorContainer: FlixieColors.dangerShade,
      onErrorContainer: FlixieColors.background,
      surface: FlixieColors.surface,
      onSurface: FlixieColors.textPrimary,
      surfaceContainerHighest: FlixieColors.surfaceElevated,
      onSurfaceVariant: FlixieColors.medium,
      outline: FlixieColors.controlOutline,
      shadow: Colors.black,
      scrim: Colors.black54,
      inverseSurface: FlixieColors.light,
      onInverseSurface: FlixieColors.background,
      inversePrimary: FlixieColors.primaryShade,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: FlixieTypography.fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent,

      // App bar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        foregroundColor: FlixieColors.light,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: FlixieTypography.sectionTitle.copyWith(
          color: FlixieColors.textPrimary,
        ),
        iconTheme: const IconThemeData(color: FlixieColors.light),
      ),

      // Bottom navigation bar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: FlixieColors.tabBarBackground,
        selectedItemColor: FlixieColors.primaryText,
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
            return const IconThemeData(color: FlixieColors.primaryText);
          }
          return const IconThemeData(color: FlixieColors.medium);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: FlixieColors.primaryText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            );
          }
          return const TextStyle(color: FlixieColors.medium, fontSize: 12);
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

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: FlixieColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: FlixieColors.surface,
        modalBarrierColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: FlixieColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: FlixieColors.tabBarBorder),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: FlixieColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 14,
        shadowColor: Colors.black.withValues(alpha: 0.55),
        position: PopupMenuPosition.under,
        menuPadding: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: FlixieColors.tabBarBorder),
        ),
        textStyle: const TextStyle(
          color: FlixieColors.light,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Filled and elevated actions share the same readable label style.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: FlixieColors.primary,
          foregroundColor: Colors.white,
          textStyle: FlixieTypography.button,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          textStyle: FlixieTypography.button,
          minimumSize: const Size(64, 48),
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
          textStyle: FlixieTypography.button,
          minimumSize: const Size(64, 48),
          foregroundColor: FlixieColors.primaryText,
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
          textStyle: FlixieTypography.button,
          foregroundColor: FlixieColors.primaryText,
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
          borderSide: const BorderSide(color: FlixieColors.controlOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FlixieColors.controlOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: FlixieColors.primaryText, width: 2),
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
      chipTheme: FlixiePillStyle.theme(Brightness.dark),

      // Floating action button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: FlixieColors.primary,
        foregroundColor: Colors.white,
      ),

      // Progress indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: FlixieColors.primary,
        linearTrackColor: FlixieColors.tabBarBorder,
        circularTrackColor: FlixieColors.tabBarBorder,
      ),

      // Toasts must remain readable against every supplied background colour.
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: FlixieColors.surfaceElevated,
        contentTextStyle: TextStyle(
          color: FlixieColors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: FlixieColors.primaryText,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: FlixieColors.tabBarBorder,
        thickness: 1,
      ),

      // Icon theme
      iconTheme: const IconThemeData(color: FlixieColors.light),

      // Text theme
      textTheme: FlixieTypography.textTheme(
        primary: FlixieColors.textPrimary,
        secondary: FlixieColors.light,
        muted: FlixieColors.medium,
      ),
    );
  }

  static ThemeData get lightTheme {
    final base = darkTheme;
    const c = FlixiePalette(Brightness.light);
    final scheme = ColorScheme.fromSeed(
      seedColor: FlixieColors.primary,
      brightness: Brightness.light,
      primary: FlixieColors.primary,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFEAE0FC),
      onPrimaryContainer: c.textPrimary,
      secondary: c.secondary,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFDDF2EA),
      onSecondaryContainer: c.secondary,
      tertiary: c.tertiary,
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFF9E4DC),
      onTertiaryContainer: c.tertiary,
      error: c.danger,
      onError: Colors.white,
      errorContainer: const Color(0xFFFBE3E7),
      onErrorContainer: c.danger,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.light,
      surfaceContainerHighest: c.surfaceElevated,
      outline: FlixieColors.controlOutline,
    );
    // Copy existing geometry and typography: appearance changes colours only.
    return base.copyWith(
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: c.surface,
      primaryTextTheme: FlixieTypography.textTheme(
          primary: c.textPrimary, secondary: c.light, muted: c.medium),
      tabBarTheme: base.tabBarTheme.copyWith(
          labelColor: c.textPrimary,
          unselectedLabelColor: c.light,
          indicatorColor: c.primary),
      dividerColor: c.tabBarBorder,
      disabledColor: c.medium.withValues(alpha: .38),
      hintColor: c.medium,
      textSelectionTheme: TextSelectionThemeData(
          cursorColor: c.primary,
          selectionColor: c.primary.withValues(alpha: .2),
          selectionHandleColor: c.primary),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        foregroundColor: c.light,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle:
            base.appBarTheme.titleTextStyle?.copyWith(color: c.textPrimary),
        iconTheme: IconThemeData(color: c.light),
      ),
      bottomNavigationBarTheme: base.bottomNavigationBarTheme.copyWith(
          backgroundColor: c.tabBarBackground,
          selectedItemColor: c.primaryText,
          unselectedItemColor: c.medium),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        backgroundColor: c.tabBarBackground,
        indicatorColor: c.primary.withValues(alpha: .15),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? c.primaryText
                : c.medium)),
        labelTextStyle: WidgetStateProperty.resolveWith((states) =>
            base.navigationBarTheme.labelTextStyle!.resolve(states)!.copyWith(
                color: states.contains(WidgetState.selected)
                    ? c.primaryText
                    : c.medium)),
      ),
      cardTheme: base.cardTheme.copyWith(
          color: c.surface,
          shape: (base.cardTheme.shape as RoundedRectangleBorder)
              .copyWith(side: BorderSide(color: c.tabBarBorder))),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
          backgroundColor: c.surface, modalBackgroundColor: c.surface),
      dialogTheme: base.dialogTheme.copyWith(
          backgroundColor: c.surface,
          shape: (base.dialogTheme.shape as RoundedRectangleBorder)
              .copyWith(side: BorderSide(color: c.tabBarBorder))),
      popupMenuTheme: base.popupMenuTheme.copyWith(
          color: c.surface,
          textStyle: base.popupMenuTheme.textStyle?.copyWith(color: c.light),
          shape: (base.popupMenuTheme.shape as RoundedRectangleBorder)
              .copyWith(side: BorderSide(color: c.tabBarBorder))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: base.outlinedButtonTheme.style?.copyWith(
              foregroundColor: WidgetStatePropertyAll(c.primaryText))),
      textButtonTheme: TextButtonThemeData(
          style: base.textButtonTheme.style?.copyWith(
              foregroundColor: WidgetStatePropertyAll(c.primaryText))),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: c.surface,
        labelStyle: TextStyle(color: c.medium),
        hintStyle: TextStyle(color: c.medium),
        prefixIconColor: c.medium,
        suffixIconColor: c.medium,
        focusedBorder: (base.inputDecorationTheme.focusedBorder
                as OutlineInputBorder)
            .copyWith(borderSide: BorderSide(color: c.primaryText, width: 2)),
        errorBorder:
            (base.inputDecorationTheme.errorBorder as OutlineInputBorder)
                .copyWith(borderSide: BorderSide(color: c.danger)),
        focusedErrorBorder:
            (base.inputDecorationTheme.focusedErrorBorder as OutlineInputBorder)
                .copyWith(borderSide: BorderSide(color: c.danger, width: 2)),
      ),
      chipTheme: FlixiePillStyle.theme(Brightness.light),
      progressIndicatorTheme: base.progressIndicatorTheme.copyWith(
          linearTrackColor: c.tabBarBorder, circularTrackColor: c.tabBarBorder),
      snackBarTheme: base.snackBarTheme.copyWith(
          backgroundColor: c.surfaceElevated,
          contentTextStyle: base.snackBarTheme.contentTextStyle
              ?.copyWith(color: c.textPrimary),
          actionTextColor: c.primaryText),
      dividerTheme: base.dividerTheme.copyWith(color: c.tabBarBorder),
      iconTheme: IconThemeData(color: c.light),
      textTheme: FlixieTypography.textTheme(
          primary: c.textPrimary, secondary: c.light, muted: c.medium),
    );
  }
}
