import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

/// Static welcome/auth lighting; no blur or repeating animation.
class CinemaLightBackground extends StatelessWidget {
  const CinemaLightBackground({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.colors.background,
            gradient: RadialGradient(
              center: const Alignment(.45, -.55),
              radius: .95,
              colors: [
                FlixieColors.primary.withValues(alpha: .27),
                FlixieColors.primary.withValues(alpha: .08),
                context.colors.background,
              ],
              stops: const [0, .48, 1],
            ),
          ),
        ),
      );
}
