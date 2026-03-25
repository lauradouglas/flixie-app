import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/watch_provider.dart';
import '../../theme/app_theme.dart';

class WatchProviderCard extends StatelessWidget {
  const WatchProviderCard({super.key, required this.provider});

  final WatchProvider provider;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Column(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF1B2E42),
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: CachedNetworkImage(
              imageUrl: 'https://image.tmdb.org/t/p/w92${provider.logoPath}',
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _logoFallback(),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            provider.providerName,
            style: const TextStyle(
              color: FlixieColors.light,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _logoFallback() {
    return Container(
      color: const Color(0xFF253A50),
      child: const Center(
        child: Icon(
          Icons.play_circle_outline,
          color: FlixieColors.medium,
          size: 28,
        ),
      ),
    );
  }
}
