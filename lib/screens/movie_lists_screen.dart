import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/movie_lists_provider.dart';
import '../repositories/movie_features_repository.dart';
import '../theme/app_theme.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('My Lists')),
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
                    return Card(
                      color: FlixieColors.tabBarBackgroundFocused,
                      child: ListTile(
                        title: Text(list.name),
                        subtitle: Text(list.createdAt ?? ''),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'edit') {
                              await _openListEditor(context,
                                  listId: list.id, initialName: list.name);
                              return;
                            }
                            final ok = await provider.deleteList(list.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(ok
                                      ? 'List deleted'
                                      : (provider.error ??
                                          'Failed to delete list')),
                                ),
                              );
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Rename')),
                            PopupMenuItem(
                                value: 'delete', child: Text('Delete')),
                          ],
                        ),
                        onTap: () => context.push(
                          '/movie-lists/${list.id}?name=${Uri.encodeComponent(list.name)}',
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
  }) async {
    final provider = context.read<MovieListsProvider>();
    final controller = TextEditingController(text: initialName ?? '');
    final isEdit = listId != null;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlixieColors.tabBarBackgroundFocused,
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
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final name = controller.text.trim();
                    if (name.isEmpty) return;
                    final ok = isEdit
                        ? await provider.renameList(listId, name)
                        : (await provider.createList(name)) != null;
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
