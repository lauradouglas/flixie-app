import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class WatchRequestPosterPlaceholder extends StatelessWidget {
  const WatchRequestPosterPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E2D40),
      child: const Center(
        child: Icon(Icons.movie_outlined, color: FlixieColors.medium),
      ),
    );
  }
}
