import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Gives widget launches an exit while preserving in-app back navigation.
class WatchlistNavigationButton extends StatelessWidget {
  const WatchlistNavigationButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      return const BackButton();
    }
    return IconButton(
      tooltip: 'Home',
      icon: const Icon(Icons.home_outlined),
      onPressed: () => context.go('/'),
    );
  }
}
