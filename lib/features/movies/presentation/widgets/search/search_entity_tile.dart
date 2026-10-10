import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flixie_app/models/search_result.dart';

class SearchEntityTile extends StatelessWidget {
  const SearchEntityTile({super.key, required this.result, this.onTap});

  final SearchEntityResult result;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final imagePath =
        result.posterPath ?? result.logoPath ?? result.backdropPath;
    final subtitle = switch (result.type) {
      SearchEntityType.company => [
          'Production company',
          if (result.originCountry != null) result.originCountry!,
        ].join(' · '),
      SearchEntityType.collection => 'Collection',
    };

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: imagePath != null
                      ? CachedNetworkImage(
                          imageUrl: 'https://image.tmdb.org/t/p/w185$imagePath',
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _EntityIconPlaceholder(type: result.type),
                        )
                      : _EntityIconPlaceholder(type: result.type),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.name,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.colors.medium,
                          ),
                    ),
                    if (result.overview != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        result.overview!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.colors.light,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.search_rounded, color: context.colors.medium),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntityIconPlaceholder extends StatelessWidget {
  const _EntityIconPlaceholder({required this.type});

  final SearchEntityType type;

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      SearchEntityType.company => Icons.business_outlined,
      SearchEntityType.collection => Icons.folder_special_outlined,
    };

    return Container(
      color: FlixieColors.primary.withValues(alpha: 0.18),
      child: Icon(icon, color: FlixieColors.primary),
    );
  }
}
