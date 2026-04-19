import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/movie_list.dart';
import '../../providers/auth_provider.dart';
import '../../providers/movie_lists_provider.dart';
import '../../repositories/movie_features_repository.dart';
import '../../theme/app_theme.dart';

class AddToListSheet extends StatelessWidget {
  const AddToListSheet({
    super.key,
    required this.movieId,
  });

  final int movieId;

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('Sign in to use lists')),
      );
    }
    return ChangeNotifierProvider(
      create: (_) => MovieListsProvider(
        repository: const MovieFeaturesRepository(),
        userId: userId,
      )..loadLists(),
      child: _AddToListSheetBody(movieId: movieId),
    );
  }
}

class _AddToListSheetBody extends StatelessWidget {
  const _AddToListSheetBody({required this.movieId});
  final int movieId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MovieListsProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: provider.isLoading
          ? const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()))
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add to List', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (provider.lists.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No lists yet. Create one first.', style: TextStyle(color: FlixieColors.medium)),
                  )
                else
                  ...provider.lists.map(
                    (list) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(list.name),
                      onTap: () async {
                        final ok = await provider.addMovieToList(list.id, movieId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok ? 'Added to ${list.name}' : (provider.error ?? 'Unable to add movie'),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _showCreateListDialog(context, provider),
                  icon: const Icon(Icons.add),
                  label: const Text('Create new list'),
                ),
              ],
            ),
    );
  }

  Future<void> _showCreateListDialog(
    BuildContext context,
    MovieListsProvider provider,
  ) async {
    final controller = TextEditingController();
    final created = await showDialog<MovieList?>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FlixieColors.tabBarBackgroundFocused,
        title: const Text('Create List'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'List name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final list = await provider.createList(controller.text.trim());
              if (ctx.mounted) Navigator.pop(ctx, list);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (!context.mounted) return;
    if (created == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Unable to create list')),
      );
      return;
    }
    final ok = await provider.addMovieToList(created.id, movieId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Created and added to ${created.name}' : (provider.error ?? 'Unable to add movie')),
        ),
      );
    }
  }
}
