import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Derives a fun "movie taste" personality label from the user's favourite genres.
class MovieTasteBadge extends StatelessWidget {
  const MovieTasteBadge({super.key, required this.favoriteGenres});

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
    final names = genres.map(_genreName).whereType<String>().toList();
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
        .take(4)
        .map((n) => n[0].toUpperCase() + n.substring(1))
        .toList();

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
            color: FlixieColors.tabBarBackgroundFocused,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: personality.color.withValues(alpha: 0.35),
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
                  color: personality.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  personality.icon,
                  color: personality.color,
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
                        color: personality.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: genreNames
                          .map((name) => _GenreChip(
                                name: name,
                                color: personality.color,
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

class _GenreChip extends StatelessWidget {
  const _GenreChip({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
