import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/movie_list.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/presentation/controllers/movie_lists_controller.dart';
import 'package:flixie_app/features/movies/data/movie_features_repository.dart';
import 'package:flixie_app/features/social/data/friend_service.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_page.dart';

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
                        '/movie-lists/${list.id}?name=${Uri.encodeComponent(list.name)}&isOwner=${list.isOwner}&canEdit=${list.canEdit}',
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
                                    _listCountLabel(list),
                                    style: const TextStyle(
                                      color: FlixieColors.medium,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (list.scope != ListScope.personal) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      list.scope == ListScope.group
                                          ? 'Group list · ${list.groupName ?? 'Group'}'
                                          : 'Shared with ${list.collaborators.length} friend${list.collaborators.length == 1 ? '' : 's'}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: FlixieColors.primary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
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
                            if (list.isOwner)
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
                                      initialScope: list.scope,
                                      initialGroupId: list.groupId,
                                      initialCollaborators: list.collaborators,
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
    String initialScope = ListScope.personal,
    String? initialGroupId,
    List<MovieListCollaborator> initialCollaborators = const [],
  }) async {
    final provider = context.read<MovieListsProvider>();
    final controller = TextEditingController(text: initialName ?? '');
    final descriptionController =
        TextEditingController(text: initialDescription ?? '');
    final friendSearchController = TextEditingController();
    String visibility = initialVisibility ?? ListVisibility.private;
    String whoCanAddMovies = initialWhoCanAddMovies ?? 'owner';
    String scope = initialScope;
    String? selectedGroupId = initialGroupId;
    String friendSearch = '';
    final selectedFriendIds =
        initialCollaborators.map((collaborator) => collaborator.id).toSet();
    final originalFriendIds = Set<String>.from(selectedFriendIds);
    final isEdit = listId != null;
    var friends = const <FriendshipUser>[];
    var groups = const <Group>[];
    if (!isEdit || scope != ListScope.group) {
      final userId = context.read<AuthProvider>().dbUser?.id;
      if (userId != null) {
        final results = await Future.wait([
          FriendService.getFriends(userId).catchError(
            (_) => const FriendsData(
              friendships: [],
              pendingFriends: [],
              requestedFriends: [],
            ),
          ),
          GroupService.getUserGroups(userId).catchError((_) => <Group>[]),
        ]);
        friends = (results[0] as FriendsData)
            .friendships
            .map((friendship) => friendship.friendUser)
            .whereType<FriendshipUser>()
            .toList(growable: false);
        groups = results[1] as List<Group>;
      }
    }
    if (!context.mounted) {
      controller.dispose();
      descriptionController.dispose();
      friendSearchController.dispose();
      return;
    }
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
          child: SingleChildScrollView(
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
                    initialValue: visibility,
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
                if (isEdit)
                  StatefulBuilder(
                    builder: (context, setInnerState) {
                      final query = friendSearch.trim().toLowerCase();
                      final visibleFriends = query.isEmpty
                          ? friends
                          : friends
                              .where((friend) => [
                                    friend.username,
                                    friend.firstName ?? '',
                                    friend.lastName ?? '',
                                  ].join(' ').toLowerCase().contains(query))
                              .toList(growable: false);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: scope,
                            decoration: const InputDecoration(
                              labelText: 'Who can add to this list',
                            ),
                            items: initialScope == ListScope.group
                                ? const [
                                    DropdownMenuItem(
                                      value: ListScope.group,
                                      child: Text('Group members'),
                                    ),
                                  ]
                                : const [
                                    DropdownMenuItem(
                                      value: ListScope.personal,
                                      child: Text('Just me'),
                                    ),
                                    DropdownMenuItem(
                                      value: ListScope.friends,
                                      child: Text('Selected friends'),
                                    ),
                                    DropdownMenuItem(
                                      value: ListScope.group,
                                      child: Text('A group'),
                                    ),
                                  ],
                            onChanged: initialScope == ListScope.group
                                ? null
                                : (value) => setInnerState(() {
                                      scope = value ?? ListScope.personal;
                                      if (scope != ListScope.group) {
                                        selectedGroupId = null;
                                      }
                                      if (scope == ListScope.personal) {
                                        selectedFriendIds.clear();
                                      }
                                    }),
                          ),
                          if (scope == ListScope.friends) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: friendSearchController,
                              onChanged: (value) => setInnerState(
                                () => friendSearch = value,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Search friends',
                                prefixIcon:
                                    Icon(Icons.search_rounded, size: 20),
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (friends.isEmpty)
                              const Text('No accepted friends available.')
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: visibleFriends
                                    .map(
                                      (friend) => FilterChip(
                                        label: Text('@${friend.username}'),
                                        selected: selectedFriendIds
                                            .contains(friend.id),
                                        onSelected: (selected) =>
                                            setInnerState(() {
                                          if (selected) {
                                            selectedFriendIds.add(friend.id);
                                          } else {
                                            selectedFriendIds.remove(friend.id);
                                          }
                                        }),
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                          ],
                          if (scope == ListScope.group &&
                              initialScope != ListScope.group) ...[
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: selectedGroupId,
                              decoration: const InputDecoration(
                                  labelText: 'Choose group'),
                              items: groups
                                  .where((group) => group.id != null)
                                  .map((group) => DropdownMenuItem(
                                        value: group.id,
                                        child: Text(group.name),
                                      ))
                                  .toList(growable: false),
                              onChanged: (value) =>
                                  setInnerState(() => selectedGroupId = value),
                            ),
                          ],
                          if (initialScope == ListScope.group)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'Group lists cannot be changed to solo lists.',
                                style: TextStyle(color: FlixieColors.medium),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                if (!isEdit)
                  StatefulBuilder(
                    builder: (context, setInnerState) {
                      final query = friendSearch.trim().toLowerCase();
                      final visibleFriends = query.isEmpty
                          ? friends
                          : friends.where((friend) {
                              final searchable = [
                                friend.username,
                                friend.firstName ?? '',
                                friend.lastName ?? '',
                              ].join(' ').toLowerCase();
                              return searchable.contains(query);
                            }).toList(growable: false);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: scope,
                            decoration: const InputDecoration(
                                labelText: 'List ownership'),
                            items: const [
                              DropdownMenuItem(
                                value: ListScope.personal,
                                child: Text('Just me'),
                              ),
                              DropdownMenuItem(
                                value: ListScope.friends,
                                child: Text('Me and selected friends'),
                              ),
                              DropdownMenuItem(
                                value: ListScope.group,
                                child: Text('A group'),
                              ),
                            ],
                            onChanged: (value) => setInnerState(() {
                              scope = value ?? ListScope.personal;
                              selectedGroupId = null;
                              selectedFriendIds.clear();
                              friendSearch = '';
                              whoCanAddMovies = scope == ListScope.personal
                                  ? 'owner'
                                  : 'members';
                            }),
                          ),
                          if (scope == ListScope.friends) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'Choose friends',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            if (friends.isEmpty)
                              const Text(
                                'No accepted friends available.',
                                style: TextStyle(color: FlixieColors.medium),
                              )
                            else ...[
                              TextField(
                                controller: friendSearchController,
                                onChanged: (value) => setInnerState(
                                  () => friendSearch = value,
                                ),
                                textInputAction: TextInputAction.search,
                                decoration: InputDecoration(
                                  hintText: 'Search friends',
                                  prefixIcon: const Icon(Icons.search_rounded,
                                      size: 20),
                                  suffixIcon: friendSearch.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: 'Clear search',
                                          onPressed: () {
                                            friendSearchController.clear();
                                            setInnerState(
                                              () => friendSearch = '',
                                            );
                                          },
                                          icon: const Icon(Icons.close_rounded),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (visibleFriends.isEmpty)
                                const Text(
                                  'No friends match your search.',
                                  style: TextStyle(color: FlixieColors.medium),
                                )
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: visibleFriends
                                      .map(
                                        (friend) => FilterChip(
                                          label: Text('@${friend.username}'),
                                          selected: selectedFriendIds
                                              .contains(friend.id),
                                          onSelected: (selected) =>
                                              setInnerState(() {
                                            if (selected) {
                                              selectedFriendIds.add(friend.id);
                                            } else {
                                              selectedFriendIds
                                                  .remove(friend.id);
                                            }
                                          }),
                                        ),
                                      )
                                      .toList(growable: false),
                                ),
                            ],
                          ],
                          if (scope == ListScope.group) ...[
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: selectedGroupId,
                              decoration: const InputDecoration(
                                  labelText: 'Choose group'),
                              items: groups
                                  .where((group) => group.id != null)
                                  .map(
                                    (group) => DropdownMenuItem(
                                      value: group.id,
                                      child: Text(group.name),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (value) =>
                                  setInnerState(() => selectedGroupId = value),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = controller.text.trim();
                      final editorUserId =
                          context.read<AuthProvider>().dbUser?.id;
                      if (name.isEmpty) return;
                      if (scope == ListScope.friends &&
                          selectedFriendIds.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Select at least one friend'),
                          ),
                        );
                        return;
                      }
                      if (scope == ListScope.group && selectedGroupId == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Choose a group')),
                        );
                        return;
                      }
                      var ok = isEdit
                          ? await provider.renameList(
                              listId,
                              name,
                              description: descriptionController.text.trim(),
                              visibility: visibility,
                              whoCanAddMovies: whoCanAddMovies,
                              scope: scope,
                              groupId: selectedGroupId,
                              collaboratorIds: selectedFriendIds.toList(),
                            )
                          : (await provider.createList(
                                name,
                                description: descriptionController.text.trim(),
                                visibility: visibility,
                                whoCanAddMovies: whoCanAddMovies,
                                scope: scope,
                                groupId: selectedGroupId,
                                collaboratorIds: selectedFriendIds.toList(),
                              )) !=
                              null;
                      if (ok && isEdit && scope == ListScope.friends) {
                        if (editorUserId == null) {
                          ok = false;
                        } else {
                          try {
                            final added =
                                selectedFriendIds.difference(originalFriendIds);
                            final removed =
                                originalFriendIds.difference(selectedFriendIds);
                            for (final friendId in added) {
                              await UserService.addMovieListMember(
                                  editorUserId, listId, friendId);
                            }
                            for (final friendId in removed) {
                              await UserService.removeMovieListMember(
                                  editorUserId, listId, friendId);
                            }
                            if (added.isNotEmpty || removed.isNotEmpty) {
                              await provider.loadLists();
                            }
                          } catch (_) {
                            ok = false;
                          }
                        }
                      }
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
          ),
        );
      },
    );
    controller.dispose();
    descriptionController.dispose();
    friendSearchController.dispose();
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
        width: 88,
        height: 118,
        decoration: BoxDecoration(
          color: FlixieColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
        ),
        child:
            const Icon(Icons.local_movies_outlined, color: FlixieColors.medium),
      );
    }
    return SizedBox(
      width: 94,
      height: 122,
      child: Stack(
        children: List.generate(urls.length, (index) {
          final offset = index * 6.0;
          return Positioned(
            left: offset,
            top: offset,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                urls[index],
                width: 72,
                height: 108,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 72,
                  height: 108,
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

String _listCountLabel(MovieList list) {
  final movies = list.movieCount ?? 0;
  final shows = list.showCount ?? 0;
  final total = list.itemCount ?? movies + shows;
  if (movies > 0 && shows > 0) {
    return '$total items · $movies films · $shows shows';
  }
  if (movies > 0) return '$movies films';
  if (shows > 0) return '$shows shows';
  return '$total items';
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
