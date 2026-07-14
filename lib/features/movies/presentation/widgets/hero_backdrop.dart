import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';

class MovieHeroBackdrop extends StatelessWidget {
  const MovieHeroBackdrop({super.key, this.imagePath});

  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        imagePath != null
            ? CachedNetworkImage(
                imageUrl: imagePath!,
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.18),
                errorWidget: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.12, 0.3, 0.62, 0.84, 1.0],
              colors: [
                Color(0x9A000000),
                Color(0x5C000000),
                Color(0x1A000000),
                Color(0x00120A24),
                Color(0xBC120A24),
                FlixieColors.background,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholder() {
    return Container(
      color: FlixieColors.surface,
      child: const Center(
        child: Icon(
          Icons.movie_creation_outlined,
          color: FlixieColors.medium,
          size: 64,
        ),
      ),
    );
  }
}
