import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';

class FlixieWordmark extends StatelessWidget {
  const FlixieWordmark({
    super.key,
    this.fontSize = 24,
    this.fontWeight = FontWeight.w800,
    this.letterSpacing = -0.5,
    this.textAlign,
    this.foregroundColor,
  });

  final double fontSize;
  final FontWeight fontWeight;
  final double letterSpacing;
  final TextAlign? textAlign;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    if (foregroundColor == null &&
        Theme.of(context).brightness == Brightness.light) {
      return Image.asset('assets/icon/flixie_text_black.png',
          width: fontSize * 2.8,
          height: fontSize * 1.05,
          fit: BoxFit.contain,
          semanticLabel: 'Flixie');
    }
    final legacyWordmarkFont = switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => '.SF Pro Display',
      _ => 'Roboto',
    };
    return Text.rich(
      flixieWordmarkSpan(
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        fontFamily: legacyWordmarkFont,
        foregroundColor: foregroundColor ??
            (Theme.of(context).brightness == Brightness.light
                ? const Color(0xFF29272D)
                : Colors.white),
      ),
      textAlign: textAlign,
    );
  }
}

TextSpan flixieWordmarkSpan({
  double fontSize = 24,
  FontWeight fontWeight = FontWeight.w800,
  double letterSpacing = -0.5,
  String? fontFamily,
  Color foregroundColor = Colors.white,
}) {
  final base = TextStyle(fontFamily: fontFamily, height: 1);
  return TextSpan(
    children: [
      TextSpan(
        text: 'flix',
        style: base.copyWith(
          color: foregroundColor,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
        ),
      ),
      TextSpan(
        text: 'ie',
        style: base.copyWith(
          color: FlixieColors.primary,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
        ),
      ),
    ],
  );
}
