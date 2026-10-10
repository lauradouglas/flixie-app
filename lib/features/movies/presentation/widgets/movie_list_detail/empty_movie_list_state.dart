import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';

class EmptyMovieListState extends StatelessWidget {
  const EmptyMovieListState({
    super.key,
    required this.isOwner,
    required this.message,
    required this.onAddMovies,
  });

  final bool isOwner;
  final String message;
  final VoidCallback onAddMovies;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.playlist_add_rounded,
              color: context.colors.medium,
              size: 52,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.medium),
            ),
            if (isOwner) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onAddMovies,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Add titles'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
