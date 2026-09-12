import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flixie_app/models/watch_provider.dart';

/// Opens the country-specific watch page supplied by the availability source.
class WatchProviderLink extends StatelessWidget {
  const WatchProviderLink(
      {super.key, required this.provider, required this.child});

  final WatchProvider provider;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final uri = provider.verifiedWatchUri;
    if (uri == null) return child;
    return Tooltip(
      message: 'See watch options on TMDB',
      child: Semantics(
        link: true,
        label:
            '${provider.providerName}: see watch options on TMDB, opens browser',
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              try {
                if (await launchUrl(uri,
                    mode: LaunchMode.externalApplication)) {
                  return;
                }
              } catch (_) {
                // Keep the detail screen usable when no browser can open.
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Couldn’t open TMDB. Please try again.'),
                ));
              }
            },
            child: child,
          ),
        ),
      ),
    );
  }
}
