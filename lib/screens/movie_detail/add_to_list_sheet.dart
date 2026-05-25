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

class _AddToListSheetBody extends StatefulWidget {
  const _AddToListSheetBody({required this.movieId});
  final int movieId;

  @override
  State<_AddToListSheetBody> createState() => _AddToListSheetBodyState();
}

class _AddToListSheetBodyState extends State<_AddToListSheetBody> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedListIds = <String>{};
  final Set<String> _initialListIds = <String>{};
  bool _saving = false;
  bool _loadingMembership = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMembership());
  }

  Future<void> _loadMembership() async {
    final provider = context.read<MovieListsProvider>();
    final containing = await provider.getListsContainingMovie(widget.movieId);
    if (!mounted) return;
    setState(() {
      _initialListIds
        ..clear()
        ..addAll(containing.map((list) => list.id));
      _selectedListIds
        ..clear()
        ..addAll(_initialListIds);
      _loadingMembership = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MovieListsProvider>();
    final query = _searchController.text.trim().toLowerCase();
    final filtered = provider.lists
        .where((list) => list.name.toLowerCase().contains(query))
        .toList(growable: false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: provider.isLoading || _loadingMembership
          ? const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add to List',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search your lists',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 12),
                if (provider.lists.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No lists yet. Create one first.',
                      style: TextStyle(color: FlixieColors.medium),
                    ),
                  )
                else
                  SizedBox(
                    height: 260,
                    child: ListView(
                      children: filtered
                          .map(
                            (list) => CheckboxListTile(
                              value: _selectedListIds.contains(list.id),
                              title: Text(list.name),
                              subtitle: Text('${list.movieCount ?? 0} movies'),
                              activeColor: FlixieColors.primary,
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: _saving
                                  ? null
                                  : (selected) {
                                      setState(() {
                                        if (selected == true) {
                                          _selectedListIds.add(list.id);
                                        } else {
                                          _selectedListIds.remove(list.id);
                                        }
                                      });
                                    },
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _saving
                      ? null
                      : () => _showCreateListDialog(context, provider),
                  icon: const Icon(Icons.add),
                  label: const Text('Create new list'),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : () => _applyChanges(provider),
                    child: Text('Save Lists (${_selectedListIds.length})'),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _applyChanges(MovieListsProvider provider) async {
    setState(() => _saving = true);
    final toAdd = _selectedListIds.difference(_initialListIds).toList();
    final toRemove = _initialListIds.difference(_selectedListIds).toList();
    final failed = <String>[];

    for (final listId in toAdd) {
      final ok = await provider.addMovieToList(listId, widget.movieId);
      if (!ok) failed.add(listId);
    }
    for (final listId in toRemove) {
      final ok = await provider.removeMovieFromList(listId, widget.movieId);
      if (!ok) failed.add(listId);
    }

    if (!mounted) return;
    setState(() => _saving = false);
    if (failed.isNotEmpty) {
      final listNames = failed
          .map(
            (id) => provider.lists
                .firstWhere(
                  (list) => list.id == id,
                  orElse: () => const MovieList(
                    id: '',
                    name: 'Unknown List',
                    removed: false,
                  ),
                )
                .name,
          )
          .toSet()
          .join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update lists: $listNames. ${provider.error ?? 'Please try again.'}',
          ),
        ),
      );
      return;
    }
    Navigator.pop(context, true);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Lists updated')));
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
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
    setState(() => _selectedListIds.add(created.id));
  }
}
