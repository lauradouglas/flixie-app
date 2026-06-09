import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/movie_list_movie.dart';
import '../providers/auth_provider.dart';
import '../providers/movie_lists_provider.dart';
import '../repositories/movie_features_repository.dart';
import '../theme/app_theme.dart';

enum _ListSort { recentlyAdded, title, rating }

class MovieListDetailScreen extends StatelessWidget {
  const MovieListDetailScreen({
    super.key,
    required this.listId,
    required this.listName,
    this.ownerUserId,
  });

  final String listId;
  final String listName;
  final String? ownerUserId;

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
        isOwner: currentUserId != null && currentUserId == userId,
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
  });

  final String listId;
  final String listName;
  final String ownerUserId;
  final bool isOwner;

  @override
  State<_MovieListDetailView> createState() => _MovieListDetailViewState();
}

class _MovieListDetailViewState extends State<_MovieListDetailView> {
  _ListSort _sort = _ListSort.recentlyAdded;

  Future<void> _refresh() {
    return context.read<MovieListsProvider>().loadListMovies(widget.listId);
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
        title: Text(widget.listName),
        actions: [
          if (widget.isOwner)
            IconButton(
              tooltip: 'Search movies',
              onPressed: () => context.push('/search'),
              icon: const Icon(Icons.add_rounded),
            ),
          PopupMenuButton<String>(
            tooltip: 'List actions',
            color: FlixieColors.tabBarBackgroundFocused,
            onSelected: (value) {
              if (value == 'refresh') {
                _refresh();
              } else if (value == 'manage') {
                context.push('/movie-lists');
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Text('Refresh'),
              ),
              if (widget.isOwner)
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
                      ownerLabel: widget.isOwner ? 'Your list' : 'Profile list',
                      movieCount: rawMovies.length,
                      posterUrls: _posterUrls(rawMovies),
                      isOwner: widget.isOwner,
                      onAddMovies: () => context.push('/search'),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _SortToolbar(
                      sort: _sort,
                      movieCount: rawMovies.length,
                      onSortChanged: (sort) => setState(() => _sort = sort),
                    ),
                  ),
                  if (movies.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyListState(
                        isOwner: widget.isOwner,
                        message:
                            provider.error ?? 'No movies in this list yet.',
                        onAddMovies: () => context.push('/search'),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.crossAxisExtent;
                          final columns = width >= 720
                              ? 4
                              : width >= 520
                                  ? 3
                                  : 2;
                          return SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              childAspectRatio: 0.57,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 14,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final entry = movies[index];
                                return _MovieListPosterCard(
                                  entry: entry,
                                  canEdit: widget.isOwner,
                                  onOpen: () {
                                    final movieId = _entryMovieId(entry);
                                    if (movieId > 0) {
                                      context.push('/movies/$movieId');
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
                          );
                        },
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
        sorted.sort(
            (a, b) => (a.movie?.title ?? '').compareTo(b.movie?.title ?? ''));
        break;
      case _ListSort.rating:
        sorted.sort((a, b) =>
            (b.movie?.voteAverage ?? -1).compareTo(a.movie?.voteAverage ?? -1));
        break;
    }
    return sorted;
  }

  List<String> _posterUrls(List<MovieListMovie> movies) {
    return movies
        .map((entry) => entry.movie?.posterPath)
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
    if (movieId <= 0) return;
    final title = entry.movie?.title ?? 'this movie';
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
    final ok = await provider.removeMovieFromList(widget.listId, movieId);
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

class _ListHeader extends StatelessWidget {
  const _ListHeader({
    required this.listName,
    required this.ownerLabel,
    required this.movieCount,
    required this.posterUrls,
    required this.isOwner,
    required this.onAddMovies,
  });

  final String listName;
  final String ownerLabel;
  final int movieCount;
  final List<String> posterUrls;
  final bool isOwner;
  final VoidCallback onAddMovies;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _PosterCollage(posterUrls: posterUrls),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ownerLabel,
                  style: const TextStyle(
                    color: FlixieColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  listName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.local_movies_outlined,
                      color: FlixieColors.medium,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$movieCount ${movieCount == 1 ? 'movie' : 'movies'}',
                      style: const TextStyle(
                        color: FlixieColors.medium,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                if (isOwner) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: onAddMovies,
                    icon: const Icon(Icons.add_rounded, size: 17),
                    label: const Text('Add movies'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FlixieColors.primary,
                      side: const BorderSide(color: FlixieColors.primary),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
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
}

class _PosterCollage extends StatelessWidget {
  const _PosterCollage({required this.posterUrls});

  final List<String> posterUrls;

  @override
  Widget build(BuildContext context) {
    if (posterUrls.isEmpty) {
      return Container(
        width: 92,
        height: 128,
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
      width: 96,
      height: 132,
      child: Stack(
        children: List.generate(posterUrls.length.clamp(0, 4), (index) {
          final offset = index * 8.0;
          return Positioned(
            left: offset,
            top: offset,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: posterUrls[index],
                width: 70,
                height: 104,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 70,
                  height: 104,
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
    required this.onSortChanged,
  });

  final _ListSort sort;
  final int movieCount;
  final ValueChanged<_ListSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Text(
            movieCount == 0 ? 'Collection' : '$movieCount in this collection',
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
    required this.onOpen,
    required this.onRemove,
  });

  final MovieListMovie entry;
  final bool canEdit;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final movie = entry.movie;
    final posterPath = movie?.posterPath;
    final posterUrl = posterPath != null
        ? 'https://image.tmdb.org/t/p/w500$posterPath'
        : null;
    final year = _extractYear(movie?.releaseDate);
    final rating = movie?.voteAverage;

    return Material(
      color: FlixieColors.tabBarBackgroundFocused,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
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
                      right: 6,
                      top: 6,
                      child: PopupMenuButton<String>(
                        tooltip: 'Movie actions',
                        color: FlixieColors.tabBarBackgroundFocused,
                        icon: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.58),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            Icons.more_horiz_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        onSelected: (value) {
                          if (value == 'remove') onRemove();
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'remove',
                            child: Text('Remove from list'),
                          ),
                        ],
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
                    movie?.title ?? 'Unknown movie',
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
                          year,
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
