import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/models/movie_list.dart';
import 'package:flixie_app/models/movie_list_movie.dart';
import 'package:flixie_app/models/movie_list_membership.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/user.dart' as models;
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/features/social/data/friend_service.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/movies/presentation/controllers/movie_lists_controller.dart';
import 'package:flixie_app/features/movies/data/movie_features_repository.dart';
import 'package:flixie_app/features/movies/data/search_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';

enum _ListSort { recentlyAdded, title, rating }

class MovieListDetailScreen extends StatelessWidget {
  const MovieListDetailScreen({
    super.key,
    required this.listId,
    required this.listName,
    this.ownerUserId,
    this.isOwnerOverride,
    this.canEditOverride,
  });

  final String listId;
  final String listName;
  final String? ownerUserId;
  final bool? isOwnerOverride;
  final bool? canEditOverride;

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthProvider>().dbUser?.id;
    final userId =
        (ownerUserId?.isNotEmpty ?? false) ? ownerUserId : currentUserId;
    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to view list')),
      );
    }
    return ChangeNotifierProvider(
      create: (_) => MovieListsProvider(
        repository: const MovieFeaturesRepository(),
        userId: userId,
      )..loadListMovies(listId),
      child: _MovieListDetailView(
        listId: listId,
        listName: listName,
        ownerUserId: userId,
        isOwner: isOwnerOverride ??
            (currentUserId != null && currentUserId == userId),
        canEdit: canEditOverride ??
            (currentUserId != null && currentUserId == userId),
      ),
    );
  }
}

class _MovieListDetailView extends StatefulWidget {
  const _MovieListDetailView({
    required this.listId,
    required this.listName,
    required this.ownerUserId,
    required this.isOwner,
    required this.canEdit,
  });

  final String listId;
  final String listName;
  final String ownerUserId;
  final bool isOwner;
  final bool canEdit;

  @override
  State<_MovieListDetailView> createState() => _MovieListDetailViewState();
}

class _MovieListDetailViewState extends State<_MovieListDetailView> {
  _ListSort _sort = _ListSort.recentlyAdded;
  models.User? _owner;
  MovieListMembership? _membership;

  @override
  void initState() {
    super.initState();
    if (widget.listName.startsWith('Movie Match with @')) {
      context.read<AnalyticsController>().tasteMatchViewed();
    }
    final currentUser = context.read<AuthProvider>().dbUser;
    if (currentUser?.id == widget.ownerUserId) {
      _owner = currentUser;
    } else {
      _loadOwner(widget.ownerUserId);
    }
    _loadMembership();
  }

  Future<void> _loadMembership() async {
    try {
      final membership = await UserService.getMovieListMembers(
        widget.ownerUserId,
        widget.listId,
      );
      if (mounted) {
        setState(() => _membership = membership);
        if (_owner?.id != membership.ownerId) {
          _loadOwner(membership.ownerId);
        }
      }
    } catch (_) {
      // The collection can still render if membership metadata is unavailable.
    }
  }

  Future<void> _loadOwner(String ownerId) async {
    try {
      final owner = await UserService.getUserById(ownerId);
      if (mounted) setState(() => _owner = owner);
    } catch (_) {
      // The list remains usable if profile details cannot be loaded.
    }
  }

  Future<void> _refresh() {
    _loadMembership();
    return context.read<MovieListsProvider>().loadListMovies(widget.listId);
  }

  Future<void> _showAddMovieSheet() async {
    final provider = context.read<MovieListsProvider>();
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlixieColors.surfaceElevated,
      builder: (sheetContext) =>
          ChangeNotifierProvider<MovieListsProvider>.value(
        value: provider,
        child: _AddMovieToListSheet(
          listId: widget.listId,
          listName: widget.listName,
        ),
      ),
    );
    if (added == true && mounted) {
      await _refresh();
    }
  }

  Future<void> _deleteList() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this list?'),
        content: const Text(
          'The collection will be removed for everyone. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep list'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: FlixieColors.danger,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await UserService.deleteMovieList(widget.ownerUserId, widget.listId);
      if (mounted) context.go('/movie-lists');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to delete this list.')),
        );
      }
    }
  }

  Future<void> _leaveList() async {
    final currentUserId = context.read<AuthProvider>().dbUser?.id;
    if (currentUserId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave this list?'),
        content: const Text(
          'It will disappear from your lists, but everyone else keeps access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await UserService.removeMovieListMember(
        currentUserId,
        widget.listId,
        currentUserId,
      );
      if (mounted) context.go('/movie-lists');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to leave this list.')),
        );
      }
    }
  }

  Future<void> _removeMember(MovieListMember member) async {
    final currentUserId = context.read<AuthProvider>().dbUser?.id;
    if (currentUserId == null) return;
    try {
      await UserService.removeMovieListMember(
        currentUserId,
        widget.listId,
        member.id,
      );
      await _loadMembership();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to remove @${member.username}.')),
        );
      }
    }
  }

  Future<void> _addMember() async {
    final currentUserId = context.read<AuthProvider>().dbUser?.id;
    if (currentUserId == null) return;
    final friendsData = await FriendService.getFriends(currentUserId);
    if (!mounted) return;
    final existingIds =
        _membership?.members.map((member) => member.id).toSet() ?? <String>{};
    final available = friendsData.friendships
        .map((friendship) => friendship.friendUser)
        .whereType<FriendshipUser>()
        .where((friend) => !existingIds.contains(friend.id))
        .toList(growable: false);
    final searchController = TextEditingController();
    var query = '';
    final selected = await showModalBottomSheet<FriendshipUser>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlixieColors.surfaceElevated,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final normalized = query.trim().toLowerCase();
          final visible = normalized.isEmpty
              ? available
              : available
                  .where((friend) => [
                        friend.username,
                        friend.firstName ?? '',
                        friend.lastName ?? '',
                      ].join(' ').toLowerCase().contains(normalized))
                  .toList(growable: false);
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.viewInsetsOf(context).bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add a friend',
                    style: TextStyle(
                      color: FlixieColors.light,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchController,
                    autofocus: true,
                    onChanged: (value) => setSheetState(() => query = value),
                    decoration: const InputDecoration(
                      hintText: 'Search friends',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (visible.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No friends available to add.',
                          style: TextStyle(color: FlixieColors.medium),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: visible.length,
                        itemBuilder: (_, index) {
                          final friend = visible[index];
                          return ListTile(
                            onTap: () => Navigator.pop(sheetContext, friend),
                            leading: ProfileAvatarView(
                              avatar: friend.avatar,
                              fallbackText: friend.username.isEmpty
                                  ? '?'
                                  : friend.username[0].toUpperCase(),
                              fallbackColor: FlixieColors.primary,
                              size: 38,
                              profileBadges: friend.profileBadges,
                            ),
                            title: Text('@${friend.username}'),
                            trailing:
                                const Icon(Icons.add_circle_outline_rounded),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
    searchController.dispose();
    if (selected == null || !mounted) return;
    try {
      await UserService.addMovieListMember(
        currentUserId,
        widget.listId,
        selected.id,
      );
      await _loadMembership();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to add @${selected.username}.')),
        );
      }
    }
  }

  Future<void> _showMembersSheet() async {
    final membership = _membership;
    if (membership == null) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: FlixieColors.surfaceElevated,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${membership.members.length} member${membership.members.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: FlixieColors.light,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (membership.canManageMembers)
                    TextButton.icon(
                      onPressed: _addMember,
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Add'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ...membership.members.map(
                (member) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ProfileAvatarView(
                    avatar: member.avatar,
                    fallbackText: member.username.isEmpty
                        ? '?'
                        : member.username[0].toUpperCase(),
                    fallbackColor: FlixieColors.primary,
                    size: 40,
                    profileBadges: member.profileBadges,
                  ),
                  title: Text('@${member.username}'),
                  subtitle: member.id == membership.ownerId
                      ? const Text('Owner')
                      : null,
                  trailing: membership.canManageMembers &&
                          member.id != membership.ownerId
                      ? IconButton(
                          tooltip: 'Remove member',
                          onPressed: () => _removeMember(member),
                          icon: const Icon(
                            Icons.person_remove_outlined,
                            color: FlixieColors.danger,
                          ),
                        )
                      : null,
                ),
              ),
              if (membership.canLeave)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _leaveList();
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Leave list'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MovieListsProvider>();
    final rawMovies =
        provider.listMovies[widget.listId] ?? const <MovieListMovie>[];
    final movies = _sortedMovies(rawMovies);

    return Scaffold(
      backgroundColor: FlixieColors.background,
      appBar: AppBar(
        backgroundColor: FlixieColors.background,
        foregroundColor: FlixieColors.light,
        actions: [
          if (widget.canEdit)
            IconButton(
              tooltip: 'Add movies',
              onPressed: _showAddMovieSheet,
              icon: const Icon(Icons.add_rounded),
            ),
          PopupMenuButton<String>(
            tooltip: 'List actions',
            color: FlixieColors.tabBarBackgroundFocused,
            onSelected: (value) async {
              if (value == 'refresh') {
                _refresh();
              } else if (value == 'members') {
                await _showMembersSheet();
              } else if (value == 'leave') {
                await _leaveList();
              } else if (value == 'delete') {
                await _deleteList();
              } else if (value == 'manage') {
                context.push('/movie-lists');
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Text('Refresh'),
              ),
              if ((_membership?.members.length ?? 0) > 1)
                const PopupMenuItem(
                  value: 'members',
                  child: Text('View members'),
                ),
              if (_membership?.canLeave == true)
                const PopupMenuItem(
                  value: 'leave',
                  child: Text('Leave list'),
                ),
              if (_membership?.isOwner == true)
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete list'),
                ),
              if (_membership?.isOwner == true)
                const PopupMenuItem(
                  value: 'manage',
                  child: Text('Manage lists'),
                ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        color: FlixieColors.primary,
        onRefresh: _refresh,
        child: provider.isLoading && rawMovies.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _ListHeader(
                      listName: widget.listName,
                      owner: _owner,
                      membership: _membership,
                      isOwner: widget.isOwner,
                      movieCount: rawMovies.length,
                      posterUrls: _posterUrls(rawMovies),
                      onAddMovies: _showAddMovieSheet,
                    ),
                  ),
                  if (_membership != null)
                    SliverToBoxAdapter(
                      child: _ListMembersStrip(
                        membership: _membership!,
                        onTap: _showMembersSheet,
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: _SortToolbar(
                      sort: _sort,
                      movieCount: rawMovies
                          .where((entry) => _entryMovieId(entry) > 0)
                          .length,
                      showCount: rawMovies
                          .where((entry) => _entryShowId(entry) > 0)
                          .length,
                      onSortChanged: (sort) => setState(() => _sort = sort),
                    ),
                  ),
                  if (movies.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyListState(
                        isOwner: widget.canEdit,
                        message: provider.error ?? 'No items in this list yet.',
                        onAddMovies: _showAddMovieSheet,
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 190,
                          childAspectRatio: 0.48,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 18,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final entry = movies[index];
                            return _MovieListPosterCard(
                              entry: entry,
                              canEdit: widget.canEdit,
                              showContributor:
                                  _membership?.scope != ListScope.personal,
                              onOpen: () {
                                final movieId = _entryMovieId(entry);
                                if (movieId > 0) {
                                  final source = widget.listName
                                          .startsWith('Movie Match with @')
                                      ? '?source=movie_match'
                                      : '';
                                  context.push('/movies/$movieId$source');
                                  return;
                                }
                                final showId = _entryShowId(entry);
                                if (showId > 0) {
                                  context.push('/shows/$showId');
                                }
                              },
                              onRemove: () => _confirmRemove(
                                context,
                                provider,
                                entry,
                              ),
                            );
                          },
                          childCount: movies.length,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  List<MovieListMovie> _sortedMovies(List<MovieListMovie> movies) {
    final sorted = List<MovieListMovie>.from(movies);
    switch (_sort) {
      case _ListSort.recentlyAdded:
        sorted.sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
        break;
      case _ListSort.title:
        sorted.sort((a, b) => _entryTitle(a).compareTo(_entryTitle(b)));
        break;
      case _ListSort.rating:
        sorted.sort(
            (a, b) => (_entryRating(b) ?? -1).compareTo(_entryRating(a) ?? -1));
        break;
    }
    return sorted;
  }

  List<String> _posterUrls(List<MovieListMovie> movies) {
    return movies
        .map((entry) => entry.movie?.posterPath ?? entry.show?.posterPath)
        .whereType<String>()
        .take(4)
        .map((path) => 'https://image.tmdb.org/t/p/w342$path')
        .toList(growable: false);
  }

  Future<void> _confirmRemove(
    BuildContext context,
    MovieListsProvider provider,
    MovieListMovie entry,
  ) async {
    final movieId = _entryMovieId(entry);
    final showId = _entryShowId(entry);
    if (movieId <= 0 && showId <= 0) return;
    final title = _entryTitle(entry);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove from list?'),
        content: Text('Remove $title from ${widget.listName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final analytics = context.read<AnalyticsController>();
    final ok = movieId > 0
        ? await provider.removeMovieFromList(widget.listId, movieId)
        : await provider.removeShowFromList(widget.listId, showId);
    if (ok) {
      await (movieId > 0
          ? analytics.movieRemovedFromList()
          : analytics.showRemovedFromList());
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Removed from list'
              : (provider.error ?? 'Unable to remove movie'),
        ),
      ),
    );
  }
}

class _AddMovieToListSheet extends StatefulWidget {
  const _AddMovieToListSheet({
    required this.listId,
    required this.listName,
  });

  final String listId;
  final String listName;

  @override
  State<_AddMovieToListSheet> createState() => _AddMovieToListSheetState();
}

class _AddMovieToListSheetState extends State<_AddMovieToListSheet> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<MovieShort> _results = const [];
  bool _searching = false;
  int? _addingMovieId;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _results = const [];
        _searching = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    try {
      final response = await SearchService.search(query, type: 'movie');
      if (!mounted || _controller.text.trim() != query) return;
      setState(() {
        _results = response.results
            .map((item) => item.movie)
            .whereType<MovieShort>()
            .where((movie) => movie.mediaType != 'tv')
            .toList(growable: false);
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = 'Unable to search movies right now.';
      });
    }
  }

  Future<void> _addMovie(MovieShort movie) async {
    final provider = context.read<MovieListsProvider>();
    final analytics = context.read<AnalyticsController>();
    setState(() {
      _addingMovieId = movie.id;
      _error = null;
    });
    final ok = await provider.addMovieToList(widget.listId, movie.id);
    if (ok) await analytics.movieAddedToList();
    if (!mounted) return;
    setState(() => _addingMovieId = null);
    if (ok) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(SnackBar(content: Text('Added ${movie.name}')));
    } else {
      setState(() {
        _error = provider.error ?? 'Unable to add movie.';
      });
    }
  }

  bool _isAlreadyInList(MovieListsProvider provider, int movieId) {
    final entries = provider.listMovies[widget.listId] ?? const [];
    return entries.any((entry) => _entryMovieId(entry) == movieId);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MovieListsProvider>();
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.78;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 16),
        child: SizedBox(
          height: sheetHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add to ${widget.listName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: FlixieColors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onQueryChanged,
                style: const TextStyle(color: FlixieColors.white),
                decoration: InputDecoration(
                  hintText: 'Search movies',
                  hintStyle: const TextStyle(color: FlixieColors.medium),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: FlixieColors.medium,
                  ),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          onPressed: () {
                            _controller.clear();
                            _onQueryChanged('');
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                            color: FlixieColors.medium,
                          ),
                        ),
                  filled: true,
                  fillColor: FlixieColors.tabBarBackgroundFocused,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: FlixieColors.primary),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: FlixieColors.danger,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: _buildResults(provider),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(MovieListsProvider provider) {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.text.trim().length < 2) {
      return const Center(
        child: Text(
          'Search by title to add a movie.',
          style: TextStyle(color: FlixieColors.medium),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Text(
          'No movies found.',
          style: TextStyle(color: FlixieColors.medium),
        ),
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final movie = _results[index];
        final alreadyAdded = _isAlreadyInList(provider, movie.id);
        final isAdding = _addingMovieId == movie.id;
        return _AddMovieResultTile(
          movie: movie,
          alreadyAdded: alreadyAdded,
          isAdding: isAdding,
          onAdd: alreadyAdded || isAdding ? null : () => _addMovie(movie),
        );
      },
    );
  }
}

class _AddMovieResultTile extends StatelessWidget {
  const _AddMovieResultTile({
    required this.movie,
    required this.alreadyAdded,
    required this.isAdding,
    required this.onAdd,
  });

  final MovieShort movie;
  final bool alreadyAdded;
  final bool isAdding;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final posterUrl = movie.poster == null
        ? null
        : 'https://image.tmdb.org/t/p/w185${movie.poster}';
    final year = _extractYear(movie.releaseDate);

    return Material(
      color: FlixieColors.tabBarBackgroundFocused,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onAdd,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 48,
                  height: 72,
                  child: posterUrl == null
                      ? Container(
                          color: const Color(0xFF1E2D40),
                          child: const Icon(
                            Icons.movie_outlined,
                            color: FlixieColors.medium,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: posterUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: const Color(0xFF1E2D40),
                            child: const Icon(
                              Icons.movie_outlined,
                              color: FlixieColors.medium,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: FlixieColors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    if (year != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        year,
                        style: const TextStyle(
                          color: FlixieColors.medium,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (isAdding)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (alreadyAdded)
                const Icon(
                  Icons.check_circle_rounded,
                  color: FlixieColors.primary,
                )
              else
                IconButton.filled(
                  tooltip: 'Add movie',
                  onPressed: onAdd,
                  style: IconButton.styleFrom(
                    backgroundColor: FlixieColors.primary,
                    foregroundColor: Colors.black,
                  ),
                  icon: const Icon(Icons.add_rounded),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListMembersStrip extends StatelessWidget {
  const _ListMembersStrip({
    required this.membership,
    required this.onTap,
  });

  final MovieListMembership membership;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (membership.members.length <= 1) return const SizedBox.shrink();
    final preview = membership.members.take(5).toList(growable: false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: FlixieColors.surfaceElevated.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: FlixieColors.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 44 + (preview.length - 1) * 25,
                height: 44,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var index = 0; index < preview.length; index++)
                      Positioned(
                        left: 3 + index * 25,
                        top: 3,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: FlixieColors.surfaceElevated,
                              width: 2,
                            ),
                          ),
                          child: ProfileAvatarView(
                            avatar: preview[index].avatar,
                            fallbackText: preview[index].username.isEmpty
                                ? '?'
                                : preview[index].username[0].toUpperCase(),
                            fallbackColor: FlixieColors.primary,
                            size: 36,
                            profileBadges: preview[index].profileBadges,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      membership.scope == 'GROUP'
                          ? membership.groupName ?? 'Group list'
                          : '${membership.members.length} people',
                      style: const TextStyle(
                        color: FlixieColors.light,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'Everyone can add titles',
                      style: TextStyle(
                        color: FlixieColors.medium,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: FlixieColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader({
    required this.listName,
    required this.owner,
    required this.membership,
    required this.isOwner,
    required this.movieCount,
    required this.posterUrls,
    required this.onAddMovies,
  });

  final String listName;
  final models.User? owner;
  final MovieListMembership? membership;
  final bool isOwner;
  final int movieCount;
  final List<String> posterUrls;
  final VoidCallback onAddMovies;

  @override
  Widget build(BuildContext context) {
    final isGroupList = membership?.scope == ListScope.group;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _PosterCollage(posterUrls: posterUrls),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isGroupList)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: membership?.groupId == null
                          ? null
                          : () =>
                              context.push('/groups/${membership!.groupId}'),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.groups_2_rounded,
                                  color: FlixieColors.primary,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    membership?.groupName ?? 'Group list',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: FlixieColors.light,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (membership?.groupId != null)
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: FlixieColors.medium,
                                    size: 18,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ProfileAvatarView(
                                  avatar: owner?.avatar,
                                  fallbackText: _ownerInitial(owner),
                                  fallbackColor: FlixieColors.primary,
                                  size: 22,
                                  profileBadges:
                                      owner?.profileBadges ?? const [],
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    owner == null
                                        ? 'Loading creator…'
                                        : 'Created by @${owner!.username}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: FlixieColors.medium,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: owner == null
                          ? null
                          : () => context.push(
                                isOwner ? '/profile' : '/friends/${owner!.id}',
                              ),
                      borderRadius: BorderRadius.circular(999),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 3, 8, 3),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ProfileAvatarView(
                              avatar: owner?.avatar,
                              fallbackText: _ownerInitial(owner),
                              fallbackColor: FlixieColors.primary,
                              size: 34,
                              profileBadges: owner?.profileBadges ?? const [],
                            ),
                            const SizedBox(width: 9),
                            Flexible(
                              child: Text(
                                owner == null
                                    ? 'Loading profile…'
                                    : '@${owner!.username}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: FlixieColors.light,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (owner != null) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: FlixieColors.medium,
                                size: 18,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                Text(
                  listName,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.video_library_outlined,
                      color: FlixieColors.medium,
                      size: 17,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$movieCount ${movieCount == 1 ? 'title' : 'titles'}',
                      style: const TextStyle(
                        color: FlixieColors.medium,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (isOwner) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onAddMovies,
                    icon: const Icon(Icons.add_rounded, size: 17),
                    label: const Text('Add titles'),
                    style: FilledButton.styleFrom(
                      backgroundColor: FlixieColors.primary,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _ownerInitial(models.User? user) {
    final username = user?.username.trim() ?? '';
    return username.isEmpty ? '?' : username[0].toUpperCase();
  }
}

class _PosterCollage extends StatelessWidget {
  const _PosterCollage({required this.posterUrls});

  final List<String> posterUrls;

  @override
  Widget build(BuildContext context) {
    if (posterUrls.isEmpty) {
      return Container(
        width: 108,
        height: 162,
        decoration: BoxDecoration(
          color: FlixieColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.movie_creation_outlined,
          color: FlixieColors.medium,
          size: 34,
        ),
      );
    }

    return SizedBox(
      width: 116,
      height: 166,
      child: Stack(
        children: List.generate(posterUrls.length.clamp(0, 4), (index) {
          final offset = index * 4.0;
          return Positioned(
            left: offset,
            top: offset,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: posterUrls[index],
                width: 104,
                height: 156,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 104,
                  height: 156,
                  color: FlixieColors.surfaceElevated,
                  child: const Icon(
                    Icons.movie_outlined,
                    color: FlixieColors.medium,
                  ),
                ),
              ),
            ),
          );
        }).reversed.toList(),
      ),
    );
  }
}

class _SortToolbar extends StatelessWidget {
  const _SortToolbar({
    required this.sort,
    required this.movieCount,
    required this.showCount,
    required this.onSortChanged,
  });

  final _ListSort sort;
  final int movieCount;
  final int showCount;
  final ValueChanged<_ListSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Text(
            _mediaCountLabel(movieCount, showCount),
            style: const TextStyle(
              color: FlixieColors.medium,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          PopupMenuButton<_ListSort>(
            tooltip: 'Sort list',
            color: FlixieColors.tabBarBackgroundFocused,
            initialValue: sort,
            onSelected: onSortChanged,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _ListSort.recentlyAdded,
                child: Text('Recently added'),
              ),
              PopupMenuItem(
                value: _ListSort.title,
                child: Text('Title'),
              ),
              PopupMenuItem(
                value: _ListSort.rating,
                child: Text('Rating'),
              ),
            ],
            child: Chip(
              label: Text(_sortLabel(sort)),
              avatar: const Icon(Icons.sort_rounded, size: 16),
              backgroundColor: FlixieColors.tabBarBackgroundFocused,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MovieListPosterCard extends StatelessWidget {
  const _MovieListPosterCard({
    required this.entry,
    required this.canEdit,
    required this.showContributor,
    required this.onOpen,
    required this.onRemove,
  });

  final MovieListMovie entry;
  final bool canEdit;
  final bool showContributor;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final movie = entry.movie;
    final show = entry.show;
    final isShow = _entryShowId(entry) > 0;
    final posterPath = movie?.posterPath ?? show?.posterPath;
    final posterUrl = posterPath != null
        ? 'https://image.tmdb.org/t/p/w500$posterPath'
        : null;
    final year = _extractYear(movie?.releaseDate ?? show?.firstAirDate);
    final rating = _entryRating(entry);

    return Material(
      color: FlixieColors.tabBarBackgroundFocused,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  posterUrl == null
                      ? Container(
                          color: const Color(0xFF1E2D40),
                          child: const Center(
                            child: Icon(
                              Icons.movie_outlined,
                              color: FlixieColors.medium,
                            ),
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: posterUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: const Color(0xFF1E2D40),
                            child: const Center(
                              child: Icon(
                                Icons.movie_outlined,
                                color: FlixieColors.medium,
                              ),
                            ),
                          ),
                        ),
                  if (canEdit)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          tooltip: 'List item actions',
                          color: FlixieColors.tabBarBackgroundFocused,
                          icon: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.16),
                              ),
                            ),
                            child: const Icon(
                              Icons.more_horiz_rounded,
                              color: Colors.white,
                              size: 17,
                            ),
                          ),
                          onSelected: (value) {
                            if (value == 'remove') onRemove();
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'remove',
                              height: 40,
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.remove_circle_outline_rounded,
                                    color: FlixieColors.danger,
                                    size: 18,
                                  ),
                                  SizedBox(width: 9),
                                  Text('Remove from list'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (showContributor && entry.addedBy != null)
                    Positioned(
                      left: 7,
                      bottom: 7,
                      child: Tooltip(
                        message: 'Added by @${entry.addedBy!.username}',
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: FlixieColors.primary,
                              width: 1.5,
                            ),
                          ),
                          child: ProfileAvatarView(
                            avatar: entry.addedBy!.avatar,
                            fallbackText: entry.addedBy!.username.isEmpty
                                ? '?'
                                : entry.addedBy!.username[0].toUpperCase(),
                            fallbackColor: FlixieColors.primary,
                            size: 27,
                            profileBadges: entry.addedBy!.profileBadges,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 9, 9, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _entryTitle(entry),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FlixieColors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      if (year != null)
                        Text(
                          isShow ? '$year · Show' : year,
                          style: const TextStyle(
                            color: FlixieColors.medium,
                            fontSize: 12,
                          ),
                        ),
                      const Spacer(),
                      if (rating != null && rating > 0) ...[
                        const Icon(
                          Icons.star_rounded,
                          color: FlixieColors.tertiary,
                          size: 13,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: FlixieColors.tertiary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyListState extends StatelessWidget {
  const _EmptyListState({
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
            const Icon(
              Icons.playlist_add_rounded,
              color: FlixieColors.medium,
              size: 52,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: FlixieColors.medium),
            ),
            if (isOwner) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onAddMovies,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Find movies'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

int _entryMovieId(MovieListMovie entry) {
  return entry.movieId != 0 ? entry.movieId : entry.movie?.id ?? 0;
}

int _entryShowId(MovieListMovie entry) {
  return entry.showId != 0 ? entry.showId : entry.show?.id ?? 0;
}

String _entryTitle(MovieListMovie entry) {
  return entry.movie?.title ?? entry.show?.name ?? 'Unknown title';
}

double? _entryRating(MovieListMovie entry) {
  return entry.movie?.voteAverage ?? entry.show?.voteAverage;
}

String _mediaCountLabel(int movieCount, int showCount) {
  final parts = <String>[];
  if (movieCount > 0) {
    parts.add('$movieCount ${movieCount == 1 ? 'movie' : 'movies'}');
  }
  if (showCount > 0) {
    parts.add('$showCount ${showCount == 1 ? 'show' : 'shows'}');
  }
  return parts.isEmpty ? 'Empty collection' : parts.join(' & ');
}

String? _extractYear(String? releaseDate) {
  if (releaseDate == null || releaseDate.isEmpty) return null;
  final parsed = DateTime.tryParse(releaseDate);
  if (parsed != null) return parsed.year.toString();
  return releaseDate.length >= 4 ? releaseDate.substring(0, 4) : null;
}

String _sortLabel(_ListSort sort) {
  return switch (sort) {
    _ListSort.recentlyAdded => 'Recently added',
    _ListSort.title => 'Title',
    _ListSort.rating => 'Rating',
  };
}
