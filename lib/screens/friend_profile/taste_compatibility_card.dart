import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class TasteCompatibilityCard extends StatelessWidget {
  const TasteCompatibilityCard({
    super.key,
    required this.score,
    required this.sharedMovies,
    required this.sharedFavs,
    required this.friendName,
  });

  final int? score;
  final int sharedMovies;
  final int sharedFavs;
  final String friendName;

  Color get _color {
    if (score == null) return FlixieColors.medium;
    if (score! >= 75) return FlixieColors.success;
    if (score! >= 50) return FlixieColors.warning;
    return FlixieColors.danger;
  }

  IconData get _icon {
    if (score == null) return Icons.help_outline_rounded;
    if (score! >= 85) return Icons.favorite_rounded;
    if (score! >= 70) return Icons.thumb_up_rounded;
    if (score! >= 55) return Icons.thumbs_up_down_rounded;
    if (score! >= 40) return Icons.swap_horiz_rounded;
    return Icons.contrast_rounded;
  }

  String get _label {
    if (score == null) return 'Not enough data';
    if (score! >= 85) return 'Movie Soulmates';
    if (score! >= 70) return 'Great Taste Match';
    if (score! >= 55) return 'Pretty Compatible';
    if (score! >= 40) return 'Some Overlap';
    return 'Very Different Taste';
  }

  String _buildSubtitle() {
    final parts = <String>[];
    if (sharedMovies > 0) {
      parts.add(
          '$sharedMovies movie${sharedMovies == 1 ? '' : 's'} rated together');
    }
    if (sharedFavs > 0) {
      parts.add('$sharedFavs shared favourite${sharedFavs == 1 ? '' : 's'}');
    }
    if (parts.isEmpty) return 'No movies rated or favourited in common yet';
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = _color;
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
                'TASTE COMPATIBILITY',
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
            color: FlixieColors.tabBarBackgroundFocused,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Icon circle with score ring
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: CircularProgressIndicator(
                      value: score != null ? score! / 100.0 : 0,
                      backgroundColor: Colors.transparent,
                      color: color.withValues(alpha: 0.7),
                      strokeWidth: 3,
                    ),
                  ),
                  if (score != null)
                    Text(
                      '$score%',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    )
                  else
                    Icon(_icon, color: color, size: 24),
                ],
              ),
              const SizedBox(width: 16),
              // Label + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _label,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _buildSubtitle(),
                      style: const TextStyle(
                        color: FlixieColors.medium,
                        fontSize: 12,
                      ),
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
