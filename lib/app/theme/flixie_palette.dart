import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Context-local semantic colours. Never stores the current theme globally.
/// Dark values preserve the existing app; light values use soft lavender surfaces.
class FlixiePalette {
  const FlixiePalette(this.brightness);
  final Brightness brightness;
  Color get providerIncluded =>
      _light ? const Color(0xFF207568) : const Color(0xFF9FE3C5);
  bool get _light => brightness == Brightness.light;
  Color get primary => FlixieColors.primary;
  Color get primaryShade => FlixieColors.primaryShade;
  Color get primaryTint =>
      _light ? const Color(0xFF7441C7) : FlixieColors.primaryTint;
  Color get primaryText =>
      _light ? const Color(0xFF6534B8) : FlixieColors.primaryText;
  Color get secondary =>
      _light ? const Color(0xFF207568) : FlixieColors.secondary;
  Color get secondaryShade => FlixieColors.secondaryShade;
  Color get secondaryTint =>
      _light ? const Color(0xFF207568) : FlixieColors.secondaryTint;
  Color get tertiary =>
      _light ? const Color(0xFF955021) : FlixieColors.tertiary;
  Color get tertiaryShade => FlixieColors.tertiaryShade;
  Color get tertiaryTint =>
      _light ? const Color(0xFF955021) : FlixieColors.tertiaryTint;
  Color get success => _light ? const Color(0xFF147A4E) : FlixieColors.success;
  Color get successShade =>
      _light ? const Color(0xFF116C45) : FlixieColors.successShade;
  Color get successTint =>
      _light ? const Color(0xFF147A4E) : FlixieColors.successTint;
  Color get warning => _light ? const Color(0xFF8C630E) : FlixieColors.warning;
  Color get warningShade =>
      _light ? const Color(0xFF795609) : FlixieColors.warningShade;
  Color get warningTint =>
      _light ? const Color(0xFF8C630E) : FlixieColors.warningTint;
  Color get danger => _light ? const Color(0xFFAD3C50) : FlixieColors.danger;
  Color get dangerShade =>
      _light ? const Color(0xFF943446) : FlixieColors.dangerShade;
  Color get dangerTint =>
      _light ? const Color(0xFFAD3C50) : FlixieColors.dangerTint;
  Color get textPrimary =>
      _light ? const Color(0xFF261735) : FlixieColors.textPrimary;
  Color get light => _light ? const Color(0xFF51465E) : FlixieColors.light;
  Color get lightShade =>
      _light ? const Color(0xFF62566F) : FlixieColors.lightShade;
  Color get lightTint =>
      _light ? const Color(0xFF483C55) : FlixieColors.lightTint;
  Color get medium => _light ? const Color(0xFF71647D) : FlixieColors.medium;
  Color get mediumShade =>
      _light ? const Color(0xFF796A87) : FlixieColors.mediumShade;
  Color get mediumTint =>
      _light ? const Color(0xFF675873) : FlixieColors.mediumTint;
  Color get dark => FlixieColors.dark;
  Color get darkShade => FlixieColors.darkShade;
  Color get darkTint => FlixieColors.darkTint;
  Color get bone => _light ? const Color(0xFFF3EDFC) : FlixieColors.bone;
  Color get lightTextSecondary => FlixieColors.lightTextSecondary;
  Color get controlOutline => FlixieColors.controlOutline;
  Color get background =>
      _light ? const Color(0xFFF3EDFC) : FlixieColors.background;
  Color get surface => _light ? const Color(0xFFFFFFFF) : FlixieColors.surface;
  Color get surfaceElevated =>
      _light ? const Color(0xFFEEE7F6) : FlixieColors.surfaceElevated;
  Color get navy => _light ? const Color(0xFFF3EDFC) : FlixieColors.navy;
  Color get white => _light ? const Color(0xFF261735) : FlixieColors.white;
  Color get tabBarBackground =>
      _light ? const Color(0xFFFFFFFF) : FlixieColors.tabBarBackground;
  Color get tabBarBackgroundFocused =>
      _light ? const Color(0xFFEEE7F6) : FlixieColors.tabBarBackgroundFocused;
  Color get tabBarBorder =>
      _light ? const Color(0xFFDED3EB) : FlixieColors.tabBarBorder;
  Color get cardGradientTop =>
      _light ? const Color(0xFFFFFFFF) : FlixieColors.cardGradientTop;
  Color get cardGradientBottom =>
      _light ? const Color(0xFFF3EDFC) : FlixieColors.cardGradientBottom;

  /// Theme semantic colours carried by model/view-model values.
  Color adapt(Color value) {
    if (!_light) return value;
    final pairs = <Color, Color>{
      FlixieColors.light: light,
      FlixieColors.medium: medium,
      FlixieColors.secondary: secondary,
      FlixieColors.tertiary: tertiary,
      FlixieColors.success: success,
      FlixieColors.warning: warning,
      FlixieColors.danger: danger,
      FlixieColors.primaryTint: primaryText,
    };
    return pairs[value] ?? value;
  }
}

extension FlixiePaletteContext on BuildContext {
  FlixiePalette get colors => FlixiePalette(Theme.of(this).brightness);
}
