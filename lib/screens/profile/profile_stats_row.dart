import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class ProfileStatsRow extends StatelessWidget {
  const ProfileStatsRow({
    super.key,
    required this.watched,
    required this.watchlist,
    required this.favorites,
  });

  final int watched;
  final int watchlist;
  final int favorites;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _StatItem(value: '$watched', label: 'Watched'),
        _StatItem(value: '$watchlist', label: 'Watchlist'),
        _StatItem(value: '$favorites', label: 'Favourites'),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: FlixieColors.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
