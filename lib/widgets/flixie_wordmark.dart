import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class FlixieWordmark extends StatelessWidget {
  const FlixieWordmark({
    super.key,
    this.fontSize = 24,
    this.fontWeight = FontWeight.w800,
    this.letterSpacing = -0.5,
    this.textAlign,
  });

  final double fontSize;
  final FontWeight fontWeight;
  final double letterSpacing;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      flixieWordmarkSpan(
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
      ),
      textAlign: textAlign,
    );
  }
}

TextSpan flixieWordmarkSpan({
  double fontSize = 24,
  FontWeight fontWeight = FontWeight.w800,
  double letterSpacing = -0.5,
}) {
  const base = TextStyle(height: 1);
  return TextSpan(
    children: [
      TextSpan(
        text: 'fli',
        style: base.copyWith(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
        ),
      ),
      TextSpan(
        text: 'xie',
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
