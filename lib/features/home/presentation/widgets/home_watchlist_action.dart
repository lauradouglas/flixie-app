import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

/// A persistent Home destination, without adding a row to the content feed.
class HomeWatchlistAction extends StatelessWidget {
  const HomeWatchlistAction({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(14) > 19;
    if (compact) {
      return IconButton(
        tooltip: 'Watchlist',
        onPressed: onPressed,
        icon: const Icon(Icons.bookmark_outline),
      );
    }
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.bookmark_outline, size: 20),
      label: const Text('Watchlist'),
      style: TextButton.styleFrom(
        foregroundColor: context.colors.light,
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}
