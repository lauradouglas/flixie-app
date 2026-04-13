import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/watchlist_movie.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

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

  void _load() {
    final raw = context.read<AuthProvider>().dbUser?.watchedMovies;
    if (raw == null) {
      setState(() => _loading = false);
      return;
    }
    final entries = raw
        .whereType<Map<String, dynamic>>()
        .where((m) => m['removed'] != true)
        .map((m) {
          // movie details are embedded the same way as WatchlistMovie
          WatchlistMovieDetails? movie;
          if (m['movie'] != null) {
            try {
              movie = WatchlistMovieDetails.fromJson(
                  m['movie'] as Map<String, dynamic>);
            } catch (_) {}
          }
          return _WatchedEntry(
            id: m['id'] as String? ?? '',
            movieId: m['movieId'] is int
                ? m['movieId'] as int
                : int.tryParse(m['movieId'].toString()) ?? 0,
            watchedAt: m['watchedAt'] as String? ?? m['createdAt'] as String?,
            movie: movie,
          );
        })
        .where((e) => e.movie != null)
        .toList();

    setState(() {
      _all = entries;
      _loading = false;
    });
    _applyFilter();
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
                    childAspectRatio: 0.52,
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
  final WatchlistMovieDetails? movie;

  const _WatchedEntry({
    required this.id,
    required this.movieId,
    this.watchedAt,
    this.movie,
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
  });

  final _WatchedEntry entry;
  final String formattedDate;
  final VoidCallback onTap;

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
            // Poster
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: posterUrl != null
                    ? CachedNetworkImage(
                        imageUrl: posterUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: const Color(0xFF1E2D40),
                          child: const Center(
                            child: Icon(Icons.movie_outlined,
                                color: FlixieColors.medium),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: const Color(0xFF1E2D40),
                          child: const Center(
                            child: Icon(Icons.movie_outlined,
                                color: FlixieColors.medium),
                          ),
                        ),
                      )
                    : Container(
                        color: const Color(0xFF1E2D40),
                        child: const Center(
                          child: Icon(Icons.movie_outlined,
                              color: FlixieColors.medium),
                        ),
                      ),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
