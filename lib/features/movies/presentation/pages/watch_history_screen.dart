import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/watchlist_movie.dart';
import 'package:flixie_app/models/watched_movie.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/watchlist/presentation/controllers/watchlist_actions_controller.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/write_review_sheet.dart';

const List<String> _kMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

class WatchHistoryScreen extends StatefulWidget {
  const WatchHistoryScreen({super.key});

  @override
  State<WatchHistoryScreen> createState() => _WatchHistoryScreenState();
}

class _WatchHistoryScreenState extends State<WatchHistoryScreen> {
  final _searchController = TextEditingController();

  List<_WatchedEntry> _all = [];
  List<_WatchedEntry> _filtered = [];
  bool _loading = true;
  // Sort options: dateDesc, dateAsc, titleAsc, titleDesc
  String _sortBy = 'dateDesc';

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }
    try {
      final results = await Future.wait<dynamic>([
        UserService.getUserWatchedMovies(userId),
        UserService.getUserMovieReviews(userId),
      ]);
      final watched = results[0] as List<WatchedMovie>;
      final reviews = results[1] as List<Review>;
      final history = await Future.wait(watched.map((item) async {
        try {
          return await WatchlistActionsController.instance
              .getMovieWatchHistory(userId, item.movieId);
        } catch (_) {
          return <MovieWatchEntry>[];
        }
      }));
      final reviewsByMovie = <int, Review>{
        for (final review in reviews)
          if (review.movieId != null) review.movieId!: review,
      };
      final entries = <_WatchedEntry>[
        for (var index = 0; index < watched.length; index++)
          _toWatchedEntry(
            watched[index],
            watches: history[index],
            review: reviewsByMovie[watched[index].movieId],
          ),
      ].where((entry) => entry.movie != null).toList();
      if (!mounted) return;
      setState(() {
        _all = entries;
        _loading = false;
      });
      _applyFilter();
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  _WatchedEntry _toWatchedEntry(
    WatchedMovie item, {
    required List<MovieWatchEntry> watches,
    Review? review,
  }) {
    WatchlistMovieDetails? movie;
    final rawMovie = item.movie;
    if (rawMovie != null) {
      try {
        movie = WatchlistMovieDetails.fromJson(rawMovie);
      } catch (_) {}
    }
    final sortedWatches = [...watches]..sort(
        (a, b) => _parseDate(b.watchedAt).compareTo(_parseDate(a.watchedAt)));
    final latestWatch = sortedWatches.isEmpty ? null : sortedWatches.first;
    return _WatchedEntry(
      id: item.id,
      movieId: item.movieId,
      watchedAt: latestWatch?.watchedAt ?? item.watchedAt ?? item.createdAt,
      rating: latestWatch?.rating ?? item.rating,
      notes: latestWatch?.notes ?? item.notes,
      movie: movie,
      watches: sortedWatches,
      review: review,
    );
  }

  Future<void> _openWatchEntry(_WatchedEntry entry,
      {MovieWatchEntry? initial}) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RewatchLogSheet(
        initial: initial,
        onSubmit: ({
          required String watchedAt,
          required double? rating,
          required bool? recommended,
          required String? notes,
        }) async {
          if (initial == null) {
            await WatchlistActionsController.instance.logMovieWatch(
              userId,
              LogMovieWatchRequest(
                movieId: entry.movieId,
                watchedAt: watchedAt,
                rating: rating,
                recommended: recommended,
                notes: notes,
              ),
            );
          } else {
            await WatchlistActionsController.instance.updateMovieWatch(
              userId,
              initial.id,
              UpdateMovieWatchRequest(
                watchedAt: watchedAt,
                rating: rating,
                recommended: recommended,
                notes: notes,
              ),
            );
          }
          if (mounted) context.read<AuthProvider>().markActivityChanged();
        },
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _writeReview(_WatchedEntry entry) async {
    final auth = context.read<AuthProvider>();
    final userId = auth.dbUser?.id;
    if (userId == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WriteReviewSheet(
        movieId: entry.movieId,
        userId: userId,
        onSubmitted: (_) {
          auth.invalidateCachedReviews();
          auth.markActivityChanged();
        },
      ),
    );
    if (mounted) await _load();
  }

  void _applyFilter() {
    final q = _searchController.text.toLowerCase();
    var list = _all.where((e) {
      if (q.isEmpty) return true;
      return (e.movie?.title.toLowerCase().contains(q)) ?? false;
    }).toList();

    switch (_sortBy) {
      case 'dateDesc':
        list.sort((a, b) =>
            _parseDate(b.watchedAt).compareTo(_parseDate(a.watchedAt)));
        break;
      case 'dateAsc':
        list.sort((a, b) =>
            _parseDate(a.watchedAt).compareTo(_parseDate(b.watchedAt)));
        break;
      case 'titleAsc':
        list.sort(
            (a, b) => (a.movie?.title ?? '').compareTo(b.movie?.title ?? ''));
        break;
      case 'titleDesc':
        list.sort(
            (a, b) => (b.movie?.title ?? '').compareTo(a.movie?.title ?? ''));
        break;
    }
    setState(() => _filtered = list);
  }

  DateTime _parseDate(String? iso) =>
      DateTime.tryParse(iso ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);

  String _formatDate(String? iso) {
    final dt = DateTime.tryParse(iso ?? '');
    if (dt == null) return '';
    return '${dt.day} ${_kMonths[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: FlixieColors.background,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Watch History',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            if (!_loading)
              Text('${_all.length} movies watched',
                  style: const TextStyle(
                      color: FlixieColors.medium, fontSize: 12)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: FlixieColors.tabBarBackgroundFocused,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: _sortBy,
              underline: const SizedBox(),
              dropdownColor: FlixieColors.tabBarBackgroundFocused,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
              items: const [
                DropdownMenuItem(
                    value: 'dateDesc', child: Text('Newest First')),
                DropdownMenuItem(value: 'dateAsc', child: Text('Oldest First')),
                DropdownMenuItem(value: 'titleAsc', child: Text('Title A-Z')),
                DropdownMenuItem(value: 'titleDesc', child: Text('Title Z-A')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _sortBy = v);
                _applyFilter();
              },
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search watched movies...',
                hintStyle: const TextStyle(color: FlixieColors.medium),
                prefixIcon:
                    const Icon(Icons.search, color: FlixieColors.medium),
                filled: true,
                fillColor: FlixieColors.tabBarBackgroundFocused,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _filtered.isEmpty
              ? _buildEmpty()
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.48,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final entry = _filtered[i];
                    return _WatchedMovieCard(
                      entry: entry,
                      formattedDate: _formatDate(entry.watchedAt),
                      onTap: () => context.push('/movies/${entry.movieId}'),
                      onLogAgain: () => _openWatchEntry(entry),
                      onEditEntry: entry.watches.isEmpty
                          ? null
                          : () => _openWatchEntry(
                                entry,
                                initial: entry.watches.first,
                              ),
                      onWriteReview: entry.review == null
                          ? () => _writeReview(entry)
                          : null,
                    );
                  },
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history, size: 64, color: FlixieColors.medium),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isNotEmpty
                ? 'No movies found'
                : 'No watch history yet',
            style: const TextStyle(color: FlixieColors.medium, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Internal data class
// ---------------------------------------------------------------------------

class _WatchedEntry {
  final String id;
  final int movieId;
  final String? watchedAt;
  final double? rating;
  final String? notes;
  final WatchlistMovieDetails? movie;
  final List<MovieWatchEntry> watches;
  final Review? review;

  const _WatchedEntry({
    required this.id,
    required this.movieId,
    this.watchedAt,
    this.rating,
    this.notes,
    this.movie,
    this.watches = const [],
    this.review,
  });
}

// ---------------------------------------------------------------------------
// Card widget
// ---------------------------------------------------------------------------

class _WatchedMovieCard extends StatelessWidget {
  const _WatchedMovieCard({
    required this.entry,
    required this.formattedDate,
    required this.onTap,
    required this.onLogAgain,
    this.onEditEntry,
    this.onWriteReview,
  });

  final _WatchedEntry entry;
  final String formattedDate;
  final VoidCallback onTap;
  final VoidCallback onLogAgain;
  final VoidCallback? onEditEntry;
  final VoidCallback? onWriteReview;

  @override
  Widget build(BuildContext context) {
    final movie = entry.movie!;
    final posterUrl = movie.posterPath != null
        ? 'https://image.tmdb.org/t/p/w500${movie.posterPath}'
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: FlixieColors.tabBarBackgroundFocused,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    posterUrl != null
                        ? CachedNetworkImage(
                            imageUrl: posterUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => _PosterFallback(),
                            errorWidget: (_, __, ___) => _PosterFallback(),
                          )
                        : _PosterFallback(),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: PopupMenuButton<String>(
                        color: FlixieColors.surfaceElevated,
                        onSelected: (value) {
                          if (value == 'log') onLogAgain();
                          if (value == 'edit') onEditEntry?.call();
                          if (value == 'review') onWriteReview?.call();
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'log',
                            child: Text('Log another watch'),
                          ),
                          if (onEditEntry != null)
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit latest entry'),
                            ),
                          if (onWriteReview != null)
                            const PopupMenuItem(
                              value: 'review',
                              child: Text('Write a review'),
                            ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.68),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.more_horiz,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 7,
                      bottom: 7,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${entry.watches.isEmpty ? 1 : entry.watches.length}× watched',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: 102,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 38,
                      child: Text(
                        movie.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          height: 1.24,
                        ),
                      ),
                    ),
                    if (formattedDate.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.check_circle,
                              size: 12, color: FlixieColors.success),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              formattedDate,
                              style: const TextStyle(
                                color: FlixieColors.medium,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (entry.rating != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Your rating: ${entry.rating!.toStringAsFixed(1)}/10${entry.review != null ? ' • Reviewed' : ''}',
                        style: const TextStyle(
                          color: FlixieColors.tertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ] else if (entry.review != null) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Review added',
                        style: TextStyle(
                          color: FlixieColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PosterFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E2D40),
      child: const Center(
        child: Icon(Icons.movie_outlined, color: FlixieColors.medium),
      ),
    );
  }
}
