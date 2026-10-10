import 'package:flixie_app/core/widgets/flixie_back_button.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/movie_list_movie.dart';
import 'package:flixie_app/models/movie_list_membership.dart';
import 'package:flixie_app/models/user.dart' as models;
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/presentation/controllers/movie_lists_controller.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';

import 'package:flixie_app/features/movies/presentation/movie_list_selection.dart';
import '../controllers/movie_list_detail_controller.dart';
import '../movie_list_detail_actions.dart';
import '../widgets/movie_list_detail/movie_list_header.dart';
import '../widgets/movie_list_detail/movie_list_members_strip.dart';
import '../widgets/movie_list_detail/movie_list_sort_toolbar.dart';
import '../widgets/movie_list_detail/movie_list_poster_card.dart';
import '../widgets/movie_list_detail/empty_movie_list_state.dart';

class MovieListDetailScreen extends StatelessWidget {
  const MovieListDetailScreen({
    super.key,
    required this.listId,
    required this.listName,
    this.ownerUserId,
    this.isOwnerOverride,
    this.canEditOverride,
    this.addOnOpen = false,
  });

  final String listId;
  final String listName;
  final String? ownerUserId;
  final bool? isOwnerOverride;
  final bool? canEditOverride;
  final bool addOnOpen;

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        context.select<AuthProvider, String?>((auth) => auth.dbUser?.id);
    final userId =
        (ownerUserId?.isNotEmpty ?? false) ? ownerUserId : currentUserId;
    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to view list')),
      );
    }
    return ChangeNotifierProvider(
      key: ValueKey((currentUserId, userId, listId)),
      create: (_) => MovieListsProvider(
        userId: userId,
      )..loadListMovies(listId),
      child: _MovieListDetailView(
        listId: listId,
        addOnOpen: addOnOpen,
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
    this.addOnOpen = false,
  });

  final String listId;
  final String listName;
  final String ownerUserId;
  final bool isOwner;
  final bool canEdit;
  final bool addOnOpen;

  @override
  State<_MovieListDetailView> createState() => _MovieListDetailViewState();
}

class _MovieListDetailViewState extends State<_MovieListDetailView> {
  MovieListSort _sort = MovieListSort.recentlyAdded;
  String? _addedByUserId;
  late final MovieListDetailController _controller;
  late final MovieListDetailActions _actions;
  models.User? get _owner => _controller.owner;
  MovieListMembership? get _membership => _controller.membership;
  bool get _canEdit => _membership?.canEdit ?? widget.canEdit;
  bool get _isOwner => _membership?.isOwner ?? widget.isOwner;
  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.listName.startsWith('Movie Match with @')) {
      context.read<AnalyticsController>().tasteMatchViewed();
    }
    _controller = MovieListDetailController(
        listId: widget.listId,
        ownerId: widget.ownerUserId,
        viewer: context.read<AuthProvider>().dbUser,
        currentViewer: () => context.read<AuthProvider>().dbUser?.id)
      ..addListener(_changed);
    _actions = MovieListDetailActions(
        context: context,
        listId: widget.listId,
        listName: widget.listName,
        ownerUserId: widget.ownerUserId,
        controller: _controller,
        refresh: _refresh);
    _controller.refresh();
    if (widget.addOnOpen && widget.canEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _actions.showAddMovies();
      });
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      _controller.refresh(),
      context.read<MovieListsProvider>().loadListMovies(widget.listId)
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MovieListsProvider>();
    final rawMovies =
        provider.listMovies[widget.listId] ?? const <MovieListMovie>[];
    if (_controller.accessDenied) {
      return Scaffold(
          appBar: AppBar(leading: const FlixieBackButton()),
          body: RefreshIndicator(
              onRefresh: _refresh,
              child: const CustomScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                            child: Text('This list is no longer available.')))
                  ])));
    }
    final movies = sortedMovieList(
      rawMovies
          .where((entry) =>
              _addedByUserId == null || entry.addedBy?.id == _addedByUserId)
          .toList(growable: false),
      _sort,
    );

    final width = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(13) / 13;
    final columns =
        ((width - 32) / (140 * textScale.clamp(1, 1.5))).floor().clamp(1, 4);
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        leading: const FlixieBackButton(),
        backgroundColor: context.colors.background,
        foregroundColor: context.colors.light,
        actions: [
          if (_canEdit)
            IconButton(
              tooltip: 'Add titles',
              onPressed: _actions.showAddMovies,
              icon: const Icon(Icons.add_rounded),
            ),
          PopupMenuButton<String>(
            tooltip: 'List actions',
            color: context.colors.tabBarBackgroundFocused,
            onSelected: (value) async {
              if (value == 'refresh') {
                _refresh();
              } else if (value == 'members') {
                await _actions.showMembers();
              } else if (value == 'leave') {
                await _actions.leaveList();
              } else if (value == 'delete') {
                await _actions.deleteList();
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
                    child: MovieListHeader(
                      listName: widget.listName,
                      owner: _owner,
                      membership: _membership,
                      canEdit: _canEdit,
                      isOwner: _isOwner,
                      movieCount: rawMovies.length,
                      posterUrls: movieListPosterUrls(rawMovies),
                      onAddMovies: _actions.showAddMovies,
                    ),
                  ),
                  if (_membership != null)
                    SliverToBoxAdapter(
                      child: MovieListMembersStrip(
                        membership: _membership!,
                        onTap: _actions.showMembers,
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: MovieListSortToolbar(
                      sort: _sort,
                      movieCount: rawMovies
                          .where((entry) => entryMovieId(entry) > 0)
                          .length,
                      showCount: rawMovies
                          .where((entry) => entryShowId(entry) > 0)
                          .length,
                      onSortChanged: (sort) => setState(() => _sort = sort),
                      contributors: movieListContributors(rawMovies),
                      selectedContributorId: _addedByUserId,
                      onContributorChanged: (id) =>
                          setState(() => _addedByUserId = id),
                    ),
                  ),
                  if (movies.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyMovieListState(
                        isOwner: _canEdit,
                        message: provider.error ??
                            (rawMovies.isNotEmpty && _addedByUserId != null
                                ? 'No titles added by this contributor yet.'
                                : 'Start building this list.'),
                        onAddMovies: _actions.showAddMovies,
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisExtent:
                              ((width - 32 - 12 * (columns - 1)) / columns) *
                                      1.5 +
                                  MediaQuery.textScalerOf(context).scale(160),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 18,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final entry = movies[index];
                            return MovieListPosterCard(
                              entry: entry,
                              canEdit: _canEdit,
                              currentUserId:
                                  context.read<AuthProvider>().dbUser?.id,
                              onOpen: () {
                                final movieId = entryMovieId(entry);
                                if (movieId > 0) {
                                  context.push(movieDetailPath(
                                    movieId,
                                    source: DetailSource.list,
                                    fromMovieMatch: widget.listName
                                        .startsWith('Movie Match with @'),
                                  ));
                                  return;
                                }
                                final showId = entryShowId(entry);
                                if (showId > 0) {
                                  context.push(showDetailPath(
                                    showId,
                                    source: DetailSource.list,
                                  ));
                                }
                              },
                              onRemove: () => _actions.remove(
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
}
