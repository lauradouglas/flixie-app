import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';

/// Derives a fun "movie taste" personality label from the user's favourite genres.
class MovieTasteBadge extends StatelessWidget {
  const MovieTasteBadge(
      {super.key, required this.favoriteGenres, this.compact = false});

  final bool compact;
  final List<dynamic> favoriteGenres;

  // ---------------------------------------------------------------------------
  // Genre name → (label, icon, accent colour)
  // Checked in priority order so distinctive genres beat generic ones.
  // ---------------------------------------------------------------------------
  static const List<(String pattern, String label, IconData icon, Color color)>
      _rules = [
    ('horror', 'Darkness Devotee', Icons.nightlight_round, FlixieColors.danger),
    (
      'science fiction',
      'Galaxy Brain',
      Icons.rocket_launch_rounded,
      FlixieColors.secondary
    ),
    (
      'sci-fi',
      'Galaxy Brain',
      Icons.rocket_launch_rounded,
      FlixieColors.secondary
    ),
    (
      'animation',
      'Forever Young',
      Icons.auto_awesome_rounded,
      FlixieColors.warning
    ),
    (
      'romance',
      'Hopeless Romantic',
      Icons.favorite_rounded,
      FlixieColors.primary
    ),
    (
      'comedy',
      'The Laugh Seeker',
      Icons.sentiment_very_satisfied_rounded,
      FlixieColors.warning
    ),
    (
      'thriller',
      'Edge-of-Seat Expert',
      Icons.visibility_rounded,
      FlixieColors.danger
    ),
    (
      'crime',
      'Detective at Heart',
      Icons.fingerprint_rounded,
      FlixieColors.medium
    ),
    ('mystery', 'Amateur Sleuth', Icons.search_rounded, FlixieColors.light),
    ('action', 'Adrenaline Junkie', Icons.bolt_rounded, FlixieColors.tertiary),
    ('adventure', 'The Explorer', Icons.explore_rounded, FlixieColors.success),
    (
      'fantasy',
      'World Builder',
      Icons.auto_fix_high_rounded,
      FlixieColors.secondaryTint
    ),
    (
      'documentary',
      'Truth Seeker',
      Icons.lightbulb_outline_rounded,
      FlixieColors.light
    ),
    (
      'history',
      'Time Traveller',
      Icons.hourglass_bottom_rounded,
      FlixieColors.light
    ),
    (
      'music',
      'Soundtrack Lover',
      Icons.music_note_rounded,
      FlixieColors.primaryTint
    ),
    (
      'western',
      'Wild West Wanderer',
      Icons.landscape_rounded,
      FlixieColors.tertiary
    ),
    (
      'family',
      'Big Kid at Heart',
      Icons.child_care_rounded,
      FlixieColors.warning
    ),
    ('war', 'History Buff', Icons.military_tech_rounded, FlixieColors.medium),
    (
      'drama',
      'Emotional Deep Diver',
      Icons.theater_comedy_rounded,
      FlixieColors.primaryTint
    ),
  ];

  /// Extracts a lowercase genre name from a raw favoriteGenres list item.
  static String? _genreName(dynamic item) {
    if (item is Map<String, dynamic>) {
      // Join-table format: { genre: { id, name } }
      final nested = item['genre'];
      if (nested is Map<String, dynamic>) {
        return (nested['name'] as String?)?.toLowerCase();
      }
      // Direct genre format: { id, name }
      return (item['name'] as String?)?.toLowerCase();
    }
    return null;
  }

  static ({String label, IconData icon, Color color})? _resolve(
      List<dynamic> genres) {
    final names = genres
        .map(_genreName)
        .whereType<String>()
        .where((name) => name.isNotEmpty)
        .toList();
    if (names.isEmpty) return null;

    for (final (pattern, label, icon, color) in _rules) {
      if (names.any((n) => n.contains(pattern))) {
        return (label: label, icon: icon, color: color);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final personality = _resolve(favoriteGenres);
    if (personality == null) return const SizedBox.shrink();

    final genreNames = favoriteGenres
        .map(_genreName)
        .whereType<String>()
        .where((name) => name.isNotEmpty)
        .take(4)
        .map((n) => n[0].toUpperCase() + n.substring(1))
        .toList();

    if (compact) {
      return Row(children: [
        Icon(personality.icon, color: context.colors.primaryText, size: 28),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(personality.label,
              style: TextStyle(
                  color: context.colors.white, fontWeight: FontWeight.w700)),
          Text('Based on your favourite genres: ${genreNames.join(' · ')}',
              style: TextStyle(color: context.colors.medium, fontSize: 13)),
        ])),
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: FlixieColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'MOVIE TASTE',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),

        // Badge card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.tabBarBackgroundFocused,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.colors
                  .adapt(personality.color)
                  .withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Icon circle
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: context.colors
                      .adapt(personality.color)
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  personality.icon,
                  color: context.colors.adapt(personality.color),
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),

              // Label + genre chips
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      personality.label,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.colors.adapt(personality.color),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: genreNames
                          .map((name) => _GenreChip(
                                name: name,
                                color: _genreColor(context, name),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Color _genreColor(BuildContext context, String name) {
  final named = <String, Color>{
    'action': context.colors.danger,
    'adventure': context.colors.success,
    'animation': const Color(0xFF4DD0E1),
    'comedy': context.colors.warning,
    'crime': const Color(0xFFE573A7),
    'documentary': const Color(0xFF66BB6A),
    'drama': const Color(0xFFAB76FF),
    'family': const Color(0xFFFFB86B),
    'fantasy': FlixieColors.primary,
    'history': const Color(0xFFD4A373),
    'horror': const Color(0xFFE85D75),
    'music': const Color(0xFFEC6BD6),
    'mystery': const Color(0xFF7986CB),
    'romance': const Color(0xFFFF6B9A),
    'science fiction': const Color(0xFF5B8DEF),
    'sci-fi': const Color(0xFF5B8DEF),
    'thriller': const Color(0xFFFF8A65),
    'war': const Color(0xFF9E9D6B),
    'western': const Color(0xFFC68B59),
  };
  final normalized = name.trim().toLowerCase();
  if (named[normalized] case final color?) return color;
  final fallback = [
    FlixieColors.primary,
    context.colors.secondary,
    context.colors.tertiary,
    const Color(0xFF5B8DEF),
    const Color(0xFFEC6BD6),
  ];
  return fallback[normalized.hashCode.abs() % fallback.length];
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FlixiePill.label(colorKey: name, label: Text(name));
  }
}
