import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';

class WatchlistPosterPlaceholder extends StatelessWidget {
  const WatchlistPosterPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: FlixieColors.primary.withValues(alpha: 0.18),
      child: const Icon(Icons.movie_outlined, color: FlixieColors.primary),
    );
  }
}
