import 'package:flutter/material.dart';

/// Option A: quiet fill, soft corners and a pale lilac selected state.
/// Shared by the widget and the Material fallback theme.
abstract final class FlixiePillStyle {
  static const radius = BorderRadius.all(Radius.circular(12));
  static const shape = RoundedRectangleBorder(borderRadius: radius);
  static const iconColor = Color(0xFF7C4DFF);
  static const selectedFill = Color(0xFFD6BFFF);
  static const selectedText = Color(0xFF271140);

  static Color fill(Brightness brightness) => brightness == Brightness.dark
      ? const Color(0xFF2B1E40)
      : const Color(0xFFEEE7F6);
  static Color foreground(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color(0xFFF5F0FF)
          : const Color(0xFF38234E);
  static TextStyle label(Brightness brightness) => TextStyle(
      fontFamily: 'Manrope',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: foreground(brightness));

  /// Deterministic across rebuilds and launches; counts and casing don't
  /// change a genre's colour. Dark and light pairs keep labels readable.
  static (Color, Color) genreColors(String key, Brightness brightness) {
    final normalized = key.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    var hash = 0;
    for (final unit in normalized.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    const dark = [
      (Color(0xFF183D38), Color(0xFFA8E8D3)),
      (Color(0xFF3F293F), Color(0xFFF2BAD9)),
      (Color(0xFF203653), Color(0xFFB4D4FF)),
      (Color(0xFF493721), Color(0xFFF1D49C)),
      (Color(0xFF462C29), Color(0xFFFFC7B5)),
      (Color(0xFF34334E), Color(0xFFD0C7FF)),
    ];
    const light = [
      (Color(0xFFDDF2EA), Color(0xFF205448)),
      (Color(0xFFF6E1EE), Color(0xFF763A60)),
      (Color(0xFFE1EBFC), Color(0xFF2D527C)),
      (Color(0xFFF5EACC), Color(0xFF69501F)),
      (Color(0xFFF9E4DC), Color(0xFF794635)),
      (Color(0xFFEAE4F9), Color(0xFF554078)),
    ];
    return (brightness == Brightness.dark ? dark : light)[hash % dark.length];
  }

  static ChipThemeData theme(Brightness brightness) => ChipThemeData(
      backgroundColor: fill(brightness),
      selectedColor: selectedFill,
      disabledColor: fill(brightness).withValues(alpha: .38),
      secondarySelectedColor: selectedFill,
      labelStyle: label(brightness).copyWith(
          color: WidgetStateColor.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? selectedText
                  : foreground(brightness))),
      secondaryLabelStyle: label(brightness)
          .copyWith(color: selectedText, fontWeight: FontWeight.w700),
      iconTheme: const IconThemeData(color: iconColor, size: 16),
      checkmarkColor: selectedText,
      side: BorderSide.none,
      shape: shape,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      labelPadding: const EdgeInsets.symmetric(horizontal: 5),
      elevation: 0,
      pressElevation: 0,
      showCheckmark: true);
}
