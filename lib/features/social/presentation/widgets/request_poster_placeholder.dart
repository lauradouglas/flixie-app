import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';

class RequestPosterPlaceholder extends StatelessWidget {
  const RequestPosterPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: FlixieColors.tabBarBackground,
      child: const Center(
        child: Icon(Icons.movie_outlined, color: FlixieColors.medium, size: 28),
      ),
    );
  }
}
