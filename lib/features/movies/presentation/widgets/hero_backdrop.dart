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
                errorWidget: (_, __, ___) => _placeholder(context),
              )
            : _placeholder(context),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.12, 0.3, 0.62, 0.84, 1.0],
              colors: [
                const Color(0x9A000000),
                const Color(0x5C000000),
                const Color(0x1A000000),
                context.colors.background.withValues(alpha: 0),
                context.colors.background.withValues(alpha: 188 / 255),
                context.colors.background,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      color: context.colors.surface,
      child: Center(
        child: Icon(
          Icons.movie_creation_outlined,
          color: context.colors.medium,
          size: 64,
        ),
      ),
    );
  }
}
