import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/movie_list.dart';
import '../providers/auth_provider.dart';
import '../providers/movie_lists_provider.dart';
import '../repositories/movie_features_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/flixie_page.dart';

class MovieListsScreen extends StatelessWidget {
  const MovieListsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to manage lists')),
      );
    }
    return ChangeNotifierProvider(
      create: (_) => MovieListsProvider(
        repository: const MovieFeaturesRepository(),
        userId: userId,
      )..loadLists(),
      child: const _MovieListsView(),
    );
  }
}

class _MovieListsView extends StatelessWidget {
  const _MovieListsView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MovieListsProvider>();
    return FlixiePageScaffold(
      appBar: const FlixieTitleAppBar(title: Text('Your Lists')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openListEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Create List'),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.lists.isEmpty
              ? _EmptyState(
                  message:
                      provider.error ?? 'No lists yet. Create your first one.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.lists.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final list = provider.lists[i];
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => context.push(
                        '/movie-lists/${list.id}?name=${Uri.encodeComponent(list.name)}',
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: FlixieColors.tabBarBackgroundFocused,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: FlixieColors.tabBarBorder),
                        ),
                        child: Row(
                          children: [
                            _PosterPreviewStack(
                              posterUrls: list.previewPosterUrls,
                              coverImageUrl: list.coverImageUrl,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          list.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Icon(
                                        _privacyIcon(list.visibility),
                                        size: 16,
                                        color: FlixieColors.medium,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${list.movieCount ?? 0} movies',
                                    style: const TextStyle(
                                      color: FlixieColors.medium,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _updatedLabel(
                                        list.updatedAt ?? list.createdAt),
                                    style: const TextStyle(
                                      color: FlixieColors.medium,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  await _openListEditor(
                                    context,
                                    listId: list.id,
                                    initialName: list.name,
                                    initialDescription: list.description,
                                    initialVisibility: list.visibility,
                                    initialWhoCanAddMovies:
                                        list.whoCanAddMovies,
                                  );
                                  return;
                                }
                                final ok = await provider.deleteList(list.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok
                                            ? 'List deleted'
                                            : (provider.error ??
                                                'Failed to delete list'),
                                      ),
                                    ),
                                  );
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                    value: 'edit', child: Text('Edit')),
                                PopupMenuItem(
                                    value: 'delete', child: Text('Delete')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _openListEditor(
    BuildContext context, {
    String? listId,
    String? initialName,
    String? initialDescription,
    String? initialVisibility,
    String? initialWhoCanAddMovies,
  }) async {
    final provider = context.read<MovieListsProvider>();
    final controller = TextEditingController(text: initialName ?? '');
    final descriptionController =
        TextEditingController(text: initialDescription ?? '');
    String visibility = initialVisibility ?? ListVisibility.private;
    String whoCanAddMovies = initialWhoCanAddMovies ?? 'owner';
    final isEdit = listId != null;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isEdit ? 'Rename List' : 'Create List',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 50,
                decoration: const InputDecoration(hintText: 'List name'),
              ),
              TextField(
                controller: descriptionController,
                maxLength: 140,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Description (optional)',
                ),
              ),
              StatefulBuilder(
                builder: (context, setInnerState) =>
                    DropdownButtonFormField<String>(
                  value: visibility,
                  decoration: const InputDecoration(labelText: 'Privacy'),
                  items: const [
                    DropdownMenuItem(
                      value: ListVisibility.private,
                      child: Text('Private'),
                    ),
                    DropdownMenuItem(
                      value: ListVisibility.friends,
                      child: Text('Friends'),
                    ),
                    DropdownMenuItem(
                      value: ListVisibility.public,
                      child: Text('Public'),
                    ),
                  ],
                  onChanged: (value) => setInnerState(
                    () => visibility = value ?? ListVisibility.private,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (context, setInnerState) =>
                    DropdownButtonFormField<String>(
                  value: whoCanAddMovies,
                  decoration:
                      const InputDecoration(labelText: 'Who can add movies?'),
                  items: const [
                    DropdownMenuItem(value: 'owner', child: Text('Only me')),
                    DropdownMenuItem(value: 'friends', child: Text('Friends')),
                  ],
                  onChanged: (value) => setInnerState(
                    () => whoCanAddMovies = value ?? 'owner',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final name = controller.text.trim();
                    if (name.isEmpty) return;
                    final ok = isEdit
                        ? await provider.renameList(
                            listId,
                            name,
                            description: descriptionController.text.trim(),
                            visibility: visibility,
                            whoCanAddMovies: whoCanAddMovies,
                          )
                        : (await provider.createList(
                              name,
                              description: descriptionController.text.trim(),
                              visibility: visibility,
                              whoCanAddMovies: whoCanAddMovies,
                            )) !=
                            null;
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok
                              ? (isEdit ? 'List renamed' : 'List created')
                              : (provider.error ?? 'Unable to save list')),
                        ),
                      );
                    }
                  },
                  child: Text(isEdit ? 'Save' : 'Create'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: FlixieColors.medium),
        ),
      ),
    );
  }
}

class _PosterPreviewStack extends StatelessWidget {
  const _PosterPreviewStack({
    required this.posterUrls,
    required this.coverImageUrl,
  });

  final List<String> posterUrls;
  final String? coverImageUrl;

  @override
  Widget build(BuildContext context) {
    final urls = posterUrls.isNotEmpty
        ? posterUrls.take(3).toList(growable: false)
        : (coverImageUrl != null ? [coverImageUrl!] : const <String>[]);
    if (urls.isEmpty) {
      return Container(
        width: 72,
        height: 54,
        decoration: BoxDecoration(
          color: FlixieColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
        ),
        child:
            const Icon(Icons.local_movies_outlined, color: FlixieColors.medium),
      );
    }
    return SizedBox(
      width: 72,
      height: 54,
      child: Stack(
        children: List.generate(urls.length, (index) {
          final left = index * 18.0;
          return Positioned(
            left: left,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                urls[index],
                width: 36,
                height: 54,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 36,
                  height: 54,
                  color: FlixieColors.surfaceElevated,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    color: FlixieColors.medium,
                    size: 16,
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

IconData _privacyIcon(String visibility) {
  switch (visibility.toUpperCase()) {
    case ListVisibility.public:
      return Icons.public;
    case ListVisibility.friends:
      return Icons.group;
    default:
      return Icons.lock_outline;
  }
}

String _updatedLabel(String? date) {
  if (date == null || date.isEmpty) return 'Updated recently';
  final parsed = DateTime.tryParse(date);
  if (parsed == null) return 'Updated recently';
  final diff = DateTime.now().difference(parsed);
  if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes}m ago';
  if (diff.inHours < 24) return 'Updated ${diff.inHours}h ago';
  if (diff.inDays < 7) return 'Updated ${diff.inDays}d ago';
  return 'Updated ${parsed.month}/${parsed.day}/${parsed.year}';
}
