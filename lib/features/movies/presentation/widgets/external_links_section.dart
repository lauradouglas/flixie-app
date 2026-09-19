import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flixie_app/models/movie.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

class ExternalLinksSection extends StatelessWidget {
  const ExternalLinksSection({super.key, required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    final hasImdb = movie.imdbId != null && movie.imdbId!.isNotEmpty;
    final hasHomepage = movie.homepage != null && movie.homepage!.isNotEmpty;
    final hasInstagram =
        movie.instagramId != null && movie.instagramId!.isNotEmpty;
    final hasTwitter = movie.twitterId != null && movie.twitterId!.isNotEmpty;

    if (!hasImdb && !hasHomepage && !hasInstagram && !hasTwitter) {
      return const SizedBox.shrink();
    }

    Future<void> launch(String url) async {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }

    Widget linkCard({
      required Widget leading,
      required String label,
      required VoidCallback onTap,
      bool fullWidth = false,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.tabBarBorder),
          ),
          child: Row(
            mainAxisAlignment: fullWidth
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.center,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    leading,
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (fullWidth)
                Icon(Icons.open_in_new, color: context.colors.medium, size: 18),
            ],
          ),
        ),
      );
    }

    final hasSocials = hasInstagram || hasTwitter;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'External Links',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: context.colors.white,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        if (hasImdb)
          linkCard(
            fullWidth: true,
            leading: Container(
              width: 36,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFF5C518),
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: const Text(
                'IMDb',
                style: TextStyle(
                  color: Color(0xFF000000),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            label: 'View on IMDb',
            onTap: () => launch('https://www.imdb.com/title/${movie.imdbId}'),
          ),
        if (hasImdb && (hasHomepage || hasSocials)) const SizedBox(height: 10),
        if (hasHomepage)
          linkCard(
            fullWidth: true,
            leading:
                Icon(Icons.language, color: context.colors.medium, size: 20),
            label: 'Official Website',
            onTap: () => launch(movie.homepage!),
          ),
        if (hasHomepage && hasSocials) const SizedBox(height: 10),
        if (hasSocials)
          Row(
            children: [
              if (hasInstagram)
                Expanded(
                  child: linkCard(
                    leading: Icon(Icons.language,
                        color: context.colors.medium, size: 20),
                    label: 'INSTAGRAM',
                    onTap: () => launch(
                        'https://www.instagram.com/${movie.instagramId}'),
                  ),
                ),
              if (hasInstagram && hasTwitter) const SizedBox(width: 10),
              if (hasTwitter)
                Expanded(
                  child: linkCard(
                    leading: Text(
                      '@',
                      style: TextStyle(
                          color: context.colors.medium,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    label: 'TWITTER',
                    onTap: () =>
                        launch('https://twitter.com/${movie.twitterId}'),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
