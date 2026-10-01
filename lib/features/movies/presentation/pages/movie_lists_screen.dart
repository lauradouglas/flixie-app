import 'package:flixie_app/core/widgets/load_failure_notice.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/movie_list.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/presentation/controllers/movie_lists_controller.dart';
import 'package:flixie_app/features/social/data/friend_service.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_page.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';

class MovieListsScreen extends StatelessWidget {
  const MovieListsScreen({super.key, this.createOnOpen = false});
  final bool createOnOpen;

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
        userId: userId,
      )..loadLists(),
      child: _MovieListsView(createOnOpen: createOnOpen),
    );
  }
}

class _MovieListsView extends StatefulWidget {
  const _MovieListsView({this.createOnOpen = false});
  final bool createOnOpen;

  @override
  State<_MovieListsView> createState() => _MovieListsViewState();
}

enum _ListFilter { all, private, shared }

enum _ListSort { updated, name }

class _MovieListsViewState extends State<_MovieListsView> {
  @override
  void initState() {
    super.initState();
    if (widget.createOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openListEditor(context);
      });
    }
  }

  _ListFilter _filter = _ListFilter.all;
  _ListSort _sort = _ListSort.updated;
  bool _showSearch = false;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MovieListsProvider>();
    final visibleLists = provider.lists.where((list) {
      final matchesFilter = switch (_filter) {
        _ListFilter.all => true,
        _ListFilter.private => list.visibility == ListVisibility.private &&
            list.scope == ListScope.personal,
        _ListFilter.shared => list.visibility != ListVisibility.private ||
            list.scope != ListScope.personal,
      };
      final query = _query.trim().toLowerCase();
      return matchesFilter &&
          (query.isEmpty || list.name.toLowerCase().contains(query));
    }).toList();
    if (_sort == _ListSort.name) {
      visibleLists
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else {
      visibleLists.sort((a, b) => (b.updatedAt ?? b.createdAt ?? '')
          .compareTo(a.updatedAt ?? a.createdAt ?? ''));
    }

    return FlixiePageScaffold(
      appBar: const FlixieTitleAppBar(title: Text('Your lists')),
      body: provider.isLoading
          ? const MovieListsScreenSkeleton()
          : provider.error != null && provider.lists.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                      child: LoadFailureNotice(
                          message: 'Couldn’t load your lists.',
                          onRetry: provider.loadLists)))
              : provider.lists.isEmpty
                  ? const _EmptyState(
                      message: 'No lists yet. Create your first one.',
                    )
                  : Column(
                      children: [
                        if (provider.error != null)
                          LoadFailureNotice(
                              message:
                                  'Couldn’t refresh your lists. Your saved lists are still here.',
                              onRetry: provider.loadLists),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size(0, 44),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                      textStyle: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    onPressed: () => _openListEditor(context),
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('New list'),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    onPressed: () => setState(
                                        () => _showSearch = !_showSearch),
                                    icon: const Icon(Icons.search_rounded),
                                  ),
                                ],
                              ),
                              if (_showSearch) ...[
                                const SizedBox(height: 8),
                                TextField(
                                  autofocus: true,
                                  onChanged: (value) =>
                                      setState(() => _query = value),
                                  decoration: const InputDecoration(
                                    hintText: 'Search lists',
                                    prefixIcon: Icon(Icons.search_rounded),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(child: _buildFilterControl()),
                                  const SizedBox(width: 10),
                                  PopupMenuButton<_ListSort>(
                                    initialValue: _sort,
                                    onSelected: (value) =>
                                        setState(() => _sort = value),
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: _ListSort.updated,
                                        child: Text('Recently updated'),
                                      ),
                                      PopupMenuItem(
                                        value: _ListSort.name,
                                        child: Text('List name'),
                                      ),
                                    ],
                                    tooltip: 'Sort lists',
                                    icon: const Icon(Icons.sort_rounded,
                                        size: 21),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: visibleLists.isEmpty
                              ? const _EmptyState(
                                  message: 'No lists match these filters.')
                              : ListView.builder(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 28),
                                  itemCount: visibleLists.length,
                                  itemBuilder: (_, index) => _ListGridCard(
                                    list: visibleLists[index],
                                    onOpen: () =>
                                        _openList(context, visibleLists[index]),
                                    onMenu: (value) => _handleListMenu(context,
                                        provider, visibleLists[index], value),
                                  ),
                                ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildFilterControl() => Row(children: [
        for (final filter in _ListFilter.values)
          Expanded(
              child: Semantics(
            selected: _filter == filter,
            child: InkWell(
              onTap: () => setState(() => _filter = filter),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                alignment: Alignment.center,
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            color: _filter == filter
                                ? context.colors.primaryText
                                : context.colors.tabBarBorder,
                            width: _filter == filter ? 2 : 1))),
                child: Text(
                    switch (filter) {
                      _ListFilter.all => 'All',
                      _ListFilter.private => 'Private',
                      _ListFilter.shared => 'Shared'
                    },
                    style: TextStyle(
                        fontSize: 14,
                        color: _filter == filter
                            ? context.colors.textPrimary
                            : context.colors.medium,
                        fontWeight: _filter == filter
                            ? FontWeight.w700
                            : FontWeight.w500)),
              ),
            ),
          )),
      ]);

  void _openList(BuildContext context, MovieList list) => context.push(
        '/movie-lists/${list.id}?name=${Uri.encodeComponent(list.name)}&isOwner=${list.isOwner}&canEdit=${list.canEdit}',
      );

  Future<void> _handleListMenu(BuildContext context,
      MovieListsProvider provider, MovieList list, String value) async {
    if (value == 'edit') {
      await _openListEditor(context,
          listId: list.id,
          initialName: list.name,
          initialDescription: list.description,
          initialVisibility: list.visibility,
          initialWhoCanAddMovies: list.whoCanAddMovies,
          initialScope: list.scope,
          initialGroupId: list.groupId,
          initialCollaborators: list.collaborators);
      return;
    }
    final ok = await provider.deleteList(list.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
          type: FlixieToastType.error,
          content: Text(ok
              ? 'List deleted'
              : (provider.error ?? 'Failed to delete list'))));
    }
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
    MovieList? createdList;
    ModalRoute<dynamic>? editorRoute;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) {
        editorRoute = ModalRoute.of(ctx);
        return ConstrainedBox(
            constraints:
                BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * .9),
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: _ListEditorLayout(
                children: [
                  Text(isEdit ? 'Edit list' : 'Make a little collection.',
                      style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: false,
                    maxLength: 50,
                    decoration: const InputDecoration(
                        labelText: 'List name',
                        hintText: 'Films for a rainy Sunday'),
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
                    builder: (context, setInnerState) => _ListChoiceGroup(
                      value: visibility,
                      title: 'Who can see it?',
                      items: const [
                        DropdownMenuItem(
                          value: ListVisibility.private,
                          child: Text('Private'),
                        ),
                        DropdownMenuItem(
                          value: ListVisibility.friends,
                          child: Text('Friends only'),
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
                                        child: Text('With a group'),
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
                                        (friend) => FlixiePill.filter(
                                            label: Text('@${friend.username}'),
                                            selected: selectedFriendIds
                                                .contains(friend.id),
                                            onSelected: (selected) =>
                                                setInnerState(() {
                                                  if (selected) {
                                                    selectedFriendIds
                                                        .add(friend.id);
                                                  } else {
                                                    selectedFriendIds
                                                        .remove(friend.id);
                                                  }
                                                })),
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
                                onChanged: (value) => setInnerState(
                                    () => selectedGroupId = value),
                              ),
                            ],
                            if (initialScope == ListScope.group)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Group lists cannot be changed to solo lists.',
                                  style:
                                      TextStyle(color: context.colors.medium),
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
                            _ListChoiceGroup(
                              value: scope,
                              title: 'Who’s making it?',
                              items: const [
                                DropdownMenuItem(
                                  value: ListScope.personal,
                                  child: Text('Just me'),
                                ),
                                DropdownMenuItem(
                                  value: ListScope.friends,
                                  child: Text('With friends'),
                                ),
                                DropdownMenuItem(
                                  value: ListScope.group,
                                  child: Text('With a group'),
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
                                Text(
                                  'No accepted friends available.',
                                  style:
                                      TextStyle(color: context.colors.medium),
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
                                            icon:
                                                const Icon(Icons.close_rounded),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (visibleFriends.isEmpty)
                                  Text(
                                    'No friends match your search.',
                                    style:
                                        TextStyle(color: context.colors.medium),
                                  )
                                else
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: visibleFriends
                                        .map(
                                          (friend) => FlixiePill.filter(
                                              label:
                                                  Text('@${friend.username}'),
                                              selected: selectedFriendIds
                                                  .contains(friend.id),
                                              onSelected: (selected) =>
                                                  setInnerState(() {
                                                    if (selected) {
                                                      selectedFriendIds
                                                          .add(friend.id);
                                                    } else {
                                                      selectedFriendIds
                                                          .remove(friend.id);
                                                    }
                                                  })),
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
                                onChanged: (value) => setInnerState(
                                    () => selectedGroupId = value),
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
                          ScaffoldMessenger.of(ctx).showFlixieToast(
                            FlixieToast(
                              type: FlixieToastType.warning,
                              content: const Text('Select at least one friend'),
                            ),
                          );
                          return;
                        }
                        if (scope == ListScope.group &&
                            selectedGroupId == null) {
                          ScaffoldMessenger.of(ctx).showFlixieToast(
                            FlixieToast(
                                type: FlixieToastType.warning,
                                content: const Text('Choose a group')),
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
                            : (createdList = await provider.createList(
                                  name,
                                  description:
                                      descriptionController.text.trim(),
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
                              final added = selectedFriendIds
                                  .difference(originalFriendIds);
                              final removed = originalFriendIds
                                  .difference(selectedFriendIds);
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
                          ScaffoldMessenger.of(context).showFlixieToast(
                            FlixieToast(
                              type: ok
                                  ? FlixieToastType.success
                                  : FlixieToastType.error,
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
            ));
      },
    );
    await editorRoute?.completed;
    controller.dispose();
    descriptionController.dispose();
    friendSearchController.dispose();
    if (createdList != null && context.mounted) {
      await context.push(Uri(
          path: '/movie-lists/${createdList!.id}',
          queryParameters: {
            'name': createdList!.name,
            'isOwner': 'true',
            'canEdit': 'true',
            'add': 'true'
          }).toString());
      if (context.mounted) await provider.loadLists();
    }
  }
}

class _ListGridCard extends StatelessWidget {
  const _ListGridCard({
    required this.list,
    required this.onOpen,
    required this.onMenu,
  });

  final MovieList list;
  final VoidCallback onOpen;
  final ValueChanged<String> onMenu;

  @override
  Widget build(BuildContext context) {
    final shared = list.scope != ListScope.personal;
    final group = list.scope == ListScope.group;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 22),
          decoration: BoxDecoration(
            border:
                Border(bottom: BorderSide(color: context.colors.tabBarBorder)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                  height: 165,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Row(children: [
                      if (list.previewPosterUrls.isEmpty)
                        Expanded(
                            child: ColoredBox(
                                color: context.colors.surfaceElevated,
                                child: const Center(
                                    child:
                                        Icon(Icons.movie_outlined, size: 32)))),
                      for (final url in list.previewPosterUrls.take(3))
                        SizedBox(
                            width: ((MediaQuery.sizeOf(context).width - 32) / 3)
                                .clamp(0.0, 110.0),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Image.network(
                                  url.startsWith('http')
                                      ? url
                                      : 'https://image.tmdb.org/t/p/w342$url',
                                  height: 165,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(Icons.movie_outlined))),
                            )),
                    ]),
                  )),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      list.name,
                      style: TextStyle(
                        color: context.colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: context.colors.light, size: 20),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '${_compactListCountLabel(list)} · ${_visibilityName(list.visibility)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: context.colors.medium, fontSize: 11.5),
                    ),
                  ),
                  Icon(_privacyIcon(list.visibility),
                      color: context.colors.medium, size: 15),
                ],
              ),
              if (shared) ...[
                const SizedBox(height: 7),
                Row(
                  children: [
                    _CollaboratorStack(
                      collaborators: list.participants.isNotEmpty
                          ? list.participants
                          : list.collaborators,
                      group: group,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        group
                            ? list.groupName ?? 'Group list'
                            : 'Shared with ${list.collaborators.length}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: FlixieColors.primary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _updatedLabel(list.updatedAt ?? list.createdAt),
                      style: TextStyle(
                          color: context.colors.medium, fontSize: 10.5),
                    ),
                  ),
                  if (list.isOwner)
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 18,
                      onSelected: onMenu,
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollaboratorStack extends StatelessWidget {
  const _CollaboratorStack({
    required this.collaborators,
    required this.group,
  });
  final List<MovieListCollaborator> collaborators;
  final bool group;

  @override
  Widget build(BuildContext context) {
    final people = collaborators.take(3).toList();
    if (people.isEmpty) {
      return Icon(group ? Icons.groups_rounded : Icons.people_outline_rounded,
          color: FlixieColors.primary, size: 20);
    }
    return SizedBox(
      width: 25 + (people.length - 1) * 16,
      height: 27,
      child: Stack(
        clipBehavior: Clip.none,
        children: people.asMap().entries.map((entry) {
          final username = entry.value.username;
          return Positioned(
            left: entry.key * 16,
            child: Container(
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: context.colors.background,
                shape: BoxShape.circle,
              ),
              foregroundDecoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: FlixieColors.primary, width: 1.3),
              ),
              child: ProfileAvatarView(
                avatar: entry.value.avatar,
                fallbackText:
                    username.isEmpty ? '?' : username[0].toUpperCase(),
                fallbackColor: FlixieColors.primary,
                profileBadges: entry.value.profileBadges,
                size: 22,
              ),
            ),
          );
        }).toList(),
      ),
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
          style: TextStyle(color: context.colors.medium),
        ),
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

String _visibilityName(String visibility) {
  switch (visibility.toUpperCase()) {
    case ListVisibility.public:
      return 'Public';
    case ListVisibility.friends:
      return 'Shared';
    default:
      return 'Private';
  }
}

// ignore: unused_element
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

String _compactListCountLabel(MovieList list) {
  final movies = list.movieCount ?? 0;
  final shows = list.showCount ?? 0;
  final total = list.itemCount ?? movies + shows;
  if (movies > 0 && shows > 0) {
    return '$movies ${movies == 1 ? 'movie' : 'movies'} & '
        '$shows ${shows == 1 ? 'show' : 'shows'}';
  }
  if (movies > 0) return '$movies ${movies == 1 ? 'movie' : 'movies'}';
  if (shows > 0) return '$shows ${shows == 1 ? 'show' : 'shows'}';
  return '$total ${total == 1 ? 'title' : 'titles'}';
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

/// Keeps the submission action reachable while the editor body scrolls.
class _ListEditorLayout extends StatelessWidget {
  const _ListEditorLayout({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
              child: Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: context.colors.medium,
                      borderRadius: BorderRadius.circular(3)))),
          Flexible(
              child: SingleChildScrollView(
                  child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children.sublist(0, children.length - 1),
          ))),
          const SizedBox(height: 12),
          children.last,
        ],
      );
}

class _ListChoiceGroup extends StatelessWidget {
  const _ListChoiceGroup(
      {required this.value,
      required this.title,
      required this.items,
      required this.onChanged});
  final String value;
  final String title;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final item in items)
              ChoiceChip(
                label: item.child,
                selected: item.value == value,
                onSelected: (_) => onChanged(item.value),
                materialTapTargetSize: MaterialTapTargetSize.padded,
              ),
          ]),
        ],
      );
}
