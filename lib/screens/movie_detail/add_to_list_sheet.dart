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

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.88,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: provider.isLoading || _loadingMembership
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        TextButton(
                          onPressed: _saving ? null : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const Expanded(
                          child: Text(
                            'Add to List',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 64),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Search your lists',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'YOUR LISTS',
                      style: TextStyle(
                        fontSize: 12,
                        color: FlixieColors.medium,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: provider.lists.isEmpty
                          ? const Center(
                              child: Text(
                                "You haven't created any lists yet.",
                                style: TextStyle(color: FlixieColors.medium),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, index) {
                                final list = filtered[index];
                                final selected =
                                    _selectedListIds.contains(list.id);
                                return InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: _saving
                                      ? null
                                      : () => setState(() {
                                            if (selected) {
                                              _selectedListIds.remove(list.id);
                                            } else {
                                              _selectedListIds.add(list.id);
                                            }
                                          }),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: FlixieColors.surface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: selected
                                            ? FlixieColors.primary
                                            : FlixieColors.tabBarBorder,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        _ListPosterStack(list: list),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                list.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${list.movieCount ?? 0} films',
                                                style: const TextStyle(
                                                  color: FlixieColors.medium,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          selected
                                              ? Icons.check_circle
                                              : Icons.radio_button_unchecked,
                                          color: selected
                                              ? FlixieColors.primary
                                              : FlixieColors.medium,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _saving ? null : _openCreateListSheet,
                      icon: const Icon(Icons.add),
                      label: const Text('Create New List'),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : () => _applyChanges(provider),
                        child: Text('Add to List (${_selectedListIds.length})'),
                      ),
                    ),
                  ],
                ),
        ),
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

  Future<void> _openCreateListSheet() async {
    final provider = context.read<MovieListsProvider>();
    final created = await showModalBottomSheet<MovieList>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlixieColors.background,
      builder: (_) => ChangeNotifierProvider<MovieListsProvider>.value(
        value: provider,
        child: const _CreateListFromMovieSheet(),
      ),
    );
    if (!mounted || created == null) return;
    setState(() {
      _searchController.clear();
      _selectedListIds.add(created.id);
    });
  }
}

class _CreateListFromMovieSheet extends StatefulWidget {
  const _CreateListFromMovieSheet();

  @override
  State<_CreateListFromMovieSheet> createState() => _CreateListFromMovieSheetState();
}

class _CreateListFromMovieSheetState extends State<_CreateListFromMovieSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _coverImageController = TextEditingController();

  String _visibility = ListVisibility.friends;
  String _whoCanAddMovies = 'owner';
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _coverImageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.92,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TextButton(
                    onPressed: _submitting ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const Expanded(
                    child: Text(
                      'Create New List',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _submitting ? null : _createList,
                    child: const Text('Create'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 26),
                decoration: BoxDecoration(
                  color: FlixieColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: FlixieColors.tabBarBorder),
                ),
                child: Column(
                  children: const [
                    Icon(Icons.image_outlined, color: FlixieColors.primary),
                    SizedBox(height: 8),
                    Text('Add Cover Image'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _coverImageController,
                decoration: const InputDecoration(
                  labelText: 'Cover image URL (optional)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _nameController,
                maxLength: 50,
                decoration: const InputDecoration(
                  labelText: 'List Name',
                  hintText: 'e.g. 90s Classics',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLength: 140,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: "What's this list about?",
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'List Type',
                style: TextStyle(
                  color: FlixieColors.light,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              _VisibilityOptionTile(
                label: 'Private',
                subtitle: 'Only you can see',
                icon: Icons.lock_outline,
                selected: _visibility == ListVisibility.private,
                onTap: () => setState(() => _visibility = ListVisibility.private),
              ),
              const SizedBox(height: 8),
              _VisibilityOptionTile(
                label: 'Friends',
                subtitle: 'Your friends can see',
                icon: Icons.group_outlined,
                selected: _visibility == ListVisibility.friends,
                onTap: () => setState(() => _visibility = ListVisibility.friends),
              ),
              const SizedBox(height: 8),
              _VisibilityOptionTile(
                label: 'Public',
                subtitle: 'Anyone can see',
                icon: Icons.public,
                selected: _visibility == ListVisibility.public,
                onTap: () => setState(() => _visibility = ListVisibility.public),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _whoCanAddMovies,
                decoration: const InputDecoration(labelText: 'Who can add movies?'),
                items: const [
                  DropdownMenuItem(value: 'owner', child: Text('Only me')),
                  DropdownMenuItem(value: 'friends', child: Text('Friends')),
                ],
                onChanged: _submitting
                    ? null
                    : (value) => setState(() => _whoCanAddMovies = value ?? 'owner'),
              ),
              if (_submitting) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createList() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('List name is required')),
      );
      return;
    }

    setState(() => _submitting = true);
    final provider = context.read<MovieListsProvider>();
    final created = await provider.createList(
      name,
      description: _descriptionController.text.trim(),
      visibility: _visibility,
      coverImageUrl: _coverImageController.text.trim().isEmpty
          ? null
          : _coverImageController.text.trim(),
      whoCanAddMovies: _whoCanAddMovies,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (created == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Unable to create list')),
      );
      return;
    }
    Navigator.pop(context, created);
  }
}

class _VisibilityOptionTile extends StatelessWidget {
  const _VisibilityOptionTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: FlixieColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? FlixieColors.primary : FlixieColors.tabBarBorder,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: FlixieColors.medium),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: FlixieColors.medium,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? FlixieColors.primary : FlixieColors.medium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ListPosterStack extends StatelessWidget {
  const _ListPosterStack({required this.list});
  final MovieList list;

  @override
  Widget build(BuildContext context) {
    final posterUrls = list.previewPosterUrls.isNotEmpty
        ? list.previewPosterUrls.take(3).toList(growable: false)
        : (list.coverImageUrl != null ? [list.coverImageUrl!] : const <String>[]);
    if (posterUrls.isEmpty) {
      return Container(
        width: 64,
        height: 44,
        decoration: BoxDecoration(
          color: FlixieColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.movie_outlined, color: FlixieColors.medium),
      );
    }
    return SizedBox(
      width: 64,
      height: 44,
      child: Stack(
        children: List.generate(posterUrls.length, (index) {
          return Positioned(
            left: index * 14,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                posterUrls[index],
                width: 28,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 28,
                  height: 44,
                  color: FlixieColors.surfaceElevated,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    size: 12,
                    color: FlixieColors.medium,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
