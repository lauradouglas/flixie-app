import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

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
                errorWidget: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x44000000),
                Color(0xBB000000),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF1B2E42),
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
