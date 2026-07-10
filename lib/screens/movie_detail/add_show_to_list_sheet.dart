import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/show_list.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';

class AddShowToListSheet extends StatefulWidget {
  const AddShowToListSheet({
    super.key,
    required this.showId,
    this.showTitle,
    this.showPosterPath,
    this.firstAirDate,
    this.ratingLabel,
  });

  final int showId;
  final String? showTitle;
  final String? showPosterPath;
  final String? firstAirDate;
  final String? ratingLabel;

  @override
  State<AddShowToListSheet> createState() => _AddShowToListSheetState();
}

class _AddShowToListSheetState extends State<AddShowToListSheet> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedListIds = <String>{};
  final Set<String> _initialListIds = <String>{};
  List<ShowList> _lists = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLists());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLists() async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) return;
    try {
      final lists = await UserService.getShowLists(userId);
      final selected = <String>{};
      for (final list in lists) {
        final shows = await UserService.getShowListShows(userId, list.id);
        if (shows.any((show) => show.id == widget.showId)) {
          selected.add(list.id);
        }
      }
      if (!mounted) return;
      setState(() {
        _lists = lists;
        _initialListIds
          ..clear()
          ..addAll(selected);
        _selectedListIds
          ..clear()
          ..addAll(selected);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load lists')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _lists
        .where((list) => list.name.toLowerCase().contains(query))
        .toList(growable: false);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.88,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        TextButton(
                          onPressed:
                              _saving ? null : () => Navigator.pop(context),
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
                    _SelectedShowSummary(
                      title: widget.showTitle,
                      posterPath: widget.showPosterPath,
                      firstAirDate: widget.firstAirDate,
                      ratingLabel: widget.ratingLabel,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text(
                          'MY LISTS',
                          style: TextStyle(
                            fontSize: 12,
                            color: FlixieColors.medium,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.7,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _saving ? null : _openCreateListSheet,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Create New List'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Search your lists',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _lists.isEmpty
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
                                        _ShowListPosterStack(list: list),
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
                                                _listCountLabel(list),
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
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _applyChanges,
                        child: Text('Save Lists (${_selectedListIds.length})'),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _applyChanges() async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) return;
    setState(() => _saving = true);
    final toAdd = _selectedListIds.difference(_initialListIds).toList();
    final toRemove = _initialListIds.difference(_selectedListIds).toList();
    try {
      for (final listId in toAdd) {
        await UserService.addShowToList(userId, listId, widget.showId);
      }
      for (final listId in toRemove) {
        await UserService.removeShowFromList(userId, listId, widget.showId);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Lists updated')));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update lists')),
      );
    }
  }

  Future<void> _openCreateListSheet() async {
    final created = await showModalBottomSheet<ShowList>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: FlixieColors.background,
      builder: (_) => const _CreateShowListSheet(),
    );
    if (!mounted || created == null) return;
    setState(() {
      _lists = [..._lists, created];
      _searchController.clear();
      _selectedListIds.add(created.id);
    });
  }
}

class _CreateShowListSheet extends StatefulWidget {
  const _CreateShowListSheet();

  @override
  State<_CreateShowListSheet> createState() => _CreateShowListSheetState();
}

class _CreateShowListSheetState extends State<_CreateShowListSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _visibility = ShowListVisibility.friends;
  String _whoCanAddShows = 'owner';
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.86,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TextButton(
                    onPressed:
                        _submitting ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const Expanded(
                    child: Text(
                      'Create List',
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
              TextField(
                controller: _nameController,
                maxLength: 50,
                decoration: const InputDecoration(
                  labelText: 'List Name',
                  hintText: 'e.g. Prestige TV',
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
              DropdownButtonFormField<String>(
                initialValue: _visibility,
                decoration: const InputDecoration(labelText: 'List Type'),
                items: const [
                  DropdownMenuItem(
                    value: ShowListVisibility.private,
                    child: Text('Private'),
                  ),
                  DropdownMenuItem(
                    value: ShowListVisibility.friends,
                    child: Text('Friends'),
                  ),
                  DropdownMenuItem(
                    value: ShowListVisibility.public,
                    child: Text('Public'),
                  ),
                ],
                onChanged: _submitting
                    ? null
                    : (value) => setState(
                          () =>
                              _visibility = value ?? ShowListVisibility.friends,
                        ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _whoCanAddShows,
                decoration:
                    const InputDecoration(labelText: 'Who can add items?'),
                items: const [
                  DropdownMenuItem(value: 'owner', child: Text('Only me')),
                  DropdownMenuItem(value: 'friends', child: Text('Friends')),
                ],
                onChanged: _submitting
                    ? null
                    : (value) =>
                        setState(() => _whoCanAddShows = value ?? 'owner'),
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
    final userId = context.read<AuthProvider>().dbUser?.id;
    final name = _nameController.text.trim();
    if (userId == null) return;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('List name is required')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final created = await UserService.createShowList(
        userId,
        CreateShowListRequest(
          name: name,
          description: _descriptionController.text.trim(),
          visibility: _visibility,
          whoCanAddShows: _whoCanAddShows,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, created);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to create show list')),
      );
    }
  }
}

String _listCountLabel(ShowList list) {
  final movies = list.movieCount ?? 0;
  final shows = list.showCount ?? 0;
  final total = list.itemCount ?? movies + shows;
  if (movies > 0 && shows > 0) {
    return '$total items · $movies films · $shows shows';
  }
  if (shows > 0) return '$shows shows';
  if (movies > 0) return '$movies films';
  return '$total items';
}

class _SelectedShowSummary extends StatelessWidget {
  const _SelectedShowSummary({
    required this.title,
    required this.posterPath,
    required this.firstAirDate,
    required this.ratingLabel,
  });

  final String? title;
  final String? posterPath;
  final String? firstAirDate;
  final String? ratingLabel;

  @override
  Widget build(BuildContext context) {
    final year = firstAirDate != null && firstAirDate!.length >= 4
        ? firstAirDate!.substring(0, 4)
        : null;
    final imageUrl = posterPath?.trim().isNotEmpty == true
        ? 'https://image.tmdb.org/t/p/w185$posterPath'
        : null;
    final parts = [
      if (year != null) year,
      if (ratingLabel?.trim().isNotEmpty == true) ratingLabel!.trim(),
    ];

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 56,
            height: 76,
            color: FlixieColors.surface,
            child: imageUrl == null
                ? const Icon(Icons.live_tv_outlined, color: FlixieColors.medium)
                : Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: FlixieColors.medium,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title?.trim().isNotEmpty == true
                    ? title!.trim()
                    : 'Selected show',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              if (parts.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  parts.join('  •  '),
                  style:
                      const TextStyle(color: FlixieColors.medium, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ShowListPosterStack extends StatelessWidget {
  const _ShowListPosterStack({required this.list});

  final ShowList list;

  @override
  Widget build(BuildContext context) {
    final posterUrls = list.previewPosterUrls.isNotEmpty
        ? list.previewPosterUrls.take(3).toList(growable: false)
        : (list.coverImageUrl != null
            ? [list.coverImageUrl!]
            : const <String>[]);
    if (posterUrls.isEmpty) {
      return Container(
        width: 64,
        height: 44,
        decoration: BoxDecoration(
          color: FlixieColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.live_tv_outlined, color: FlixieColors.medium),
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
