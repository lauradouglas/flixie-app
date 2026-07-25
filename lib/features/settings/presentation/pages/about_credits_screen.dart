import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_page.dart';

class AboutCreditsScreen extends StatelessWidget {
  const AboutCreditsScreen({super.key});

  static final Uri _tmdbUri = Uri.parse('https://www.themoviedb.org');
  static final Uri _tmdbTermsUri =
      Uri.parse('https://www.themoviedb.org/api-terms-of-use');
  static final Uri _tmdbAttributionUri =
      Uri.parse('https://developer.themoviedb.org/docs/faq');

  Future<void> _open(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open this link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlixiePageScaffold(
      appBar: const FlixieTitleAppBar(title: Text('About & Credits')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Center(
            child: Image.asset(
              'assets/icon/flixie_text_1024.png',
              height: 82,
              fit: BoxFit.contain,
              semanticLabel: 'Flixie',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Version 1.0.1',
            textAlign: TextAlign.center,
            style: TextStyle(color: FlixieColors.medium, fontSize: 12),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: FlixieColors.surfaceElevated.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: FlixieColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Data provided by TMDB',
                  style: TextStyle(
                    color: FlixieColors.light,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: SvgPicture.asset(
                    'assets/images/tmdb_logo.svg',
                    height: 62,
                    fit: BoxFit.contain,
                    semanticsLabel: 'The Movie Database',
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Movie, television, cast, artwork, and related metadata are provided by TMDB.',
                  style: TextStyle(
                    color: FlixieColors.light,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: FlixieColors.background.withValues(alpha: 0.58),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'This product uses the TMDB API but is not endorsed or certified by TMDB.',
                    style: TextStyle(
                      color: FlixieColors.white,
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _CreditLink(
                  label: 'Visit The Movie Database',
                  onTap: () => _open(context, _tmdbUri),
                ),
                _CreditLink(
                  label: 'TMDB attribution information',
                  onTap: () => _open(context, _tmdbAttributionUri),
                ),
                _CreditLink(
                  label: 'TMDB API Terms of Use',
                  onTap: () => _open(context, _tmdbTermsUri),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Credits',
            style: TextStyle(
              color: FlixieColors.light,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Flixie uses Firebase services for authentication, messaging, and app functionality.',
            style: TextStyle(color: FlixieColors.medium, height: 1.45),
          ),
          const SizedBox(height: 28),
          const Text(
            '© 2026 Flixie',
            textAlign: TextAlign.center,
            style: TextStyle(color: FlixieColors.medium, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CreditLink extends StatelessWidget {
  const _CreditLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: FlixieColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(
              Icons.open_in_new_rounded,
              color: FlixieColors.primary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
