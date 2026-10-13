import 'package:flutter/material.dart';

/// Decorative genre companions; private communities retain their own identity.
class CommunityPip extends StatelessWidget {
  const CommunityPip({super.key, required this.id, this.size = 112});
  final int id;
  final double size;

  static const variants = <int, String>{
    -1: 'anime',
    -2: 'superhero',
    -3: 'detective',
    -4: 'romance',
    -5: 'jedi',
    -6: 'cosy-movie-night',
    -7: 'red-carpet',
    28: 'superhero',
    12: 'odyssey',
    16: 'anime',
    35: 'laughing',
    80: 'black-suit',
    99: 'director',
    18: 'romance',
    10751: 'flixie-hoodie',
    14: 'jedi',
    36: 'odyssey',
    27: 'horror-slasher-v2',
    10402: 'music',
    9648: 'detective',
    10749: 'romance',
    878: 'space-adventure',
    10770: 'cosy-movie-night',
    53: 'stressed',
    10752: 'vintage-soldier',
    37: 'cowboy',
  };

  static String? assetFor(int id) {
    final variant = variants[id];
    return variant == null
        ? null
        : 'assets/icon/community_pips/pip-$variant.png';
  }

  @override
  Widget build(BuildContext context) {
    final asset = assetFor(id);
    if (asset == null) return const SizedBox.shrink();
    return ExcludeSemantics(
        child: Image.asset(asset,
            width: size, height: size, fit: BoxFit.contain, cacheWidth: 320));
  }
}
