import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

class WatchProviderCard extends StatelessWidget {
  const WatchProviderCard({
    super.key,
    required this.provider,
    this.isUserProvider = false,
    this.showUserProviderHighlight = false,
  });

  final WatchProvider provider;
  final bool isUserProvider;
  final bool showUserProviderHighlight;

  static const _greyscale = ColorFilter.matrix([
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);

  @override
  Widget build(BuildContext context) {
    final shouldDim = showUserProviderHighlight && !isUserProvider;
    final logo = ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: provider.logoPath.isEmpty
          ? _logoFallback()
          : CachedNetworkImage(
              imageUrl: provider.logoUrl,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              placeholder: (_, __) => const ColoredBox(
                color: FlixieColors.surfaceElevated,
              ),
              errorWidget: (_, __, ___) => _logoFallback(),
            ),
    );

    return SizedBox(
      width: 80,
      child: Tooltip(
        message: !showUserProviderHighlight || isUserProvider
            ? provider.providerName
            : '${provider.providerName} not in your providers',
        child: Opacity(
          opacity: shouldDim ? 0.42 : 1,
          child: Column(
            children: [
              Container(
                height: 60,
                width: 60,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: showUserProviderHighlight && isUserProvider
                      ? FlixieColors.success.withValues(alpha: 0.16)
                      : FlixieColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: showUserProviderHighlight && isUserProvider
                        ? FlixieColors.success.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: shouldDim
                    ? ColorFiltered(colorFilter: _greyscale, child: logo)
                    : logo,
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
        ),
      ),
    );
  }

  Widget _logoFallback() {
    return Container(
      color: FlixieColors.surfaceElevated,
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
