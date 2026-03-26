import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/movie_short.dart';
import '../models/person.dart';
import '../models/search_result.dart';
import '../services/movie_service.dart';
import '../services/search_service.dart';
import '../services/trending_service.dart';
import '../theme/app_theme.dart';

/// Extracts a 4-digit year string from a release date in various formats.
String? _extractYear(String? releaseDate) {
  if (releaseDate == null || releaseDate.isEmpty) return null;
  final iso = DateTime.tryParse(releaseDate);
  if (iso != null) return iso.year.toString();
  final parts = releaseDate.split(' ');
  if (parts.length == 4) return parts[3];
  if (releaseDate.length >= 4) return releaseDate.substring(0, 4);
  return null;
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';
  Timer? _debounce;

  // Default view data
  List<MovieShort> _trendingMovies = [];
  List<MovieShort> _topRatedMovies = [];
  bool _isLoadingDefault = true;

  // Discover section filter
  bool _discoverAll = true;

  // Search results
  SearchResults? _searchResults;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadDefaultData();
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadDefaultData() async {
    try {
      final results = await Future.wait([
        TrendingService.getTrendingMovies(),
        MovieService.getTopRatedMovies(),
      ]);
      if (mounted) {
        setState(() {
          _trendingMovies = results[0] as List<MovieShort>;
          _topRatedMovies = results[1] as List<MovieShort>;
          _isLoadingDefault = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDefault = false);
      }
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    setState(() => _query = value);
    if (value.trim().isEmpty) {
      setState(() {
        _searchResults = null;
        _isSearching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(value.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);
    try {
      final results = await SearchService.search(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: _query.trim().isEmpty
                  ? _buildDefaultView()
                  : _buildSearchResultsView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: _controller,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Movies, actors, directors...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _controller.clear();
                    _onSearchChanged('');
                  },
                )
              : const Icon(Icons.tune),
        ),
      ),
    );
  }

  Widget _buildDefaultView() {
    if (_isLoadingDefault) {
      return const Center(child: CircularProgressIndicator());
    }

    final discoverMovies = _discoverAll
        ? _trendingMovies
        : _trendingMovies
            .where((m) => m.mediaType == null || m.mediaType == 'movie')
            .toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trending section
          if (_trendingMovies.isNotEmpty) ...[
            const SizedBox(height: 16),
            const _SectionHeader(title: 'Trending'),
            const SizedBox(height: 8),
            ..._trendingMovies.take(5).map(
                  (m) => _TrendingListItem(
                    movie: m,
                    onTap: () => context.push('/movies/${m.id}'),
                  ),
                ),
          ],

          // Top Rated section
          if (_topRatedMovies.isNotEmpty) ...[
            const SizedBox(height: 20),
            const _SectionHeader(title: 'Top Rated'),
            const SizedBox(height: 8),
            ..._topRatedMovies.take(5).map(
                  (m) => _TopRatedListItem(
                    movie: m,
                    onTap: () => context.push('/movies/${m.id}'),
                  ),
                ),
          ],

          // Discover section
          const SizedBox(height: 24),
          _buildDiscoverSection(discoverMovies),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDiscoverSection(List<MovieShort> movies) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Discover',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    'Hand-picked for your taste',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: FlixieColors.medium,
                        ),
                  ),
                ],
              ),
              Row(
                children: [
                  _DiscoverFilterChip(
                    label: 'ALL',
                    selected: _discoverAll,
                    onTap: () => setState(() => _discoverAll = true),
                  ),
                  const SizedBox(width: 8),
                  _DiscoverFilterChip(
                    label: 'MOVIES',
                    selected: !_discoverAll,
                    onTap: () => setState(() => _discoverAll = false),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (movies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.65,
              ),
              itemCount: movies.length,
              itemBuilder: (context, index) => _DiscoverCard(
                movie: movies[index],
                onTap: () => context.push('/movies/${movies[index].id}'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchResultsView() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    final results = _searchResults?.results ?? [];

    if (_searchResults != null && results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: FlixieColors.medium),
            const SizedBox(height: 16),
            Text(
              'No results for "$_query"',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    if (results.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = results[index];
        if (item.isPerson && item.person != null) {
          return _PersonResultTile(person: item.person!);
        } else if (item.movie != null) {
          return _MovieResultTile(
            movie: item.movie!,
            onTap: () => context.push('/movies/${item.movie!.id}'),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

// ─── Section header with left accent bar ───────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: FlixieColors.tertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

// ─── Discover filter chip (ALL / MOVIES) ────────────────────────────────────

class _DiscoverFilterChip extends StatelessWidget {
  const _DiscoverFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? FlixieColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? FlixieColors.primary : FlixieColors.medium,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : FlixieColors.medium,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ─── Trending list item ─────────────────────────────────────────────────────

class _TrendingListItem extends StatelessWidget {
  const _TrendingListItem({required this.movie, this.onTap});

  final MovieShort movie;
  final VoidCallback? onTap;

  String? _formatMediaType(String? mediaType) {
    if (mediaType == null) return null;
    switch (mediaType.toLowerCase()) {
      case 'movie':
        return 'Movie';
      case 'tv':
        return 'TV';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final year = _extractYear(movie.releaseDate);
    final type = _formatMediaType(movie.mediaType);
    final subtitle = [if (type != null) type, if (year != null) year].join(' • ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 60,
                height: 80,
                child: movie.poster != null
                    ? CachedNetworkImage(
                        imageUrl:
                            'https://image.tmdb.org/t/p/w92${movie.poster}',
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: FlixieColors.primary.withValues(alpha: 0.3),
                          child: const Icon(Icons.movie,
                              color: FlixieColors.primary),
                        ),
                      )
                    : Container(
                        color: FlixieColors.primary.withValues(alpha: 0.3),
                        child:
                            const Icon(Icons.movie, color: FlixieColors.primary),
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
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: FlixieColors.medium),
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

// ─── Top-rated list item ────────────────────────────────────────────────────

class _TopRatedListItem extends StatelessWidget {
  const _TopRatedListItem({required this.movie, this.onTap});

  final MovieShort movie;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final voteAvg = movie.voteAverage;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 60,
                height: 80,
                child: movie.poster != null
                    ? CachedNetworkImage(
                        imageUrl:
                            'https://image.tmdb.org/t/p/w92${movie.poster}',
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: FlixieColors.primary.withValues(alpha: 0.3),
                          child: const Icon(Icons.movie,
                              color: FlixieColors.primary),
                        ),
                      )
                    : Container(
                        color: FlixieColors.primary.withValues(alpha: 0.3),
                        child:
                            const Icon(Icons.movie, color: FlixieColors.primary),
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
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star,
                          size: 14, color: FlixieColors.warning),
                      const SizedBox(width: 4),
                      Text(
                        voteAvg != null
                            ? voteAvg.toStringAsFixed(1)
                            : '—',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: FlixieColors.warning),
                      ),
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

// ─── Discover grid card ─────────────────────────────────────────────────────

class _DiscoverCard extends StatelessWidget {
  const _DiscoverCard({required this.movie, this.onTap});

  final MovieShort movie;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (movie.poster != null)
              CachedNetworkImage(
                imageUrl: 'https://image.tmdb.org/t/p/w342${movie.poster}',
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: FlixieColors.primary.withValues(alpha: 0.3),
                  child:
                      const Icon(Icons.movie_outlined, size: 48),
                ),
              )
            else
              Container(
                color: FlixieColors.primary.withValues(alpha: 0.3),
                child: const Icon(Icons.movie_outlined, size: 48),
              ),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.5, 1.0],
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
            // Title and media type
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      movie.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (movie.mediaType != null &&
                        movie.mediaType!.toLowerCase() == 'tv') ...[
                      const SizedBox(height: 4),
                      Text(
                        'TV Series',
                        style: TextStyle(
                          color: FlixieColors.tertiary,
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

// ─── Search result: movie tile ───────────────────────────────────────────────

class _MovieResultTile extends StatelessWidget {
  const _MovieResultTile({required this.movie, this.onTap});

  final MovieShort movie;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final year = _extractYear(movie.releaseDate);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 50,
                  height: 75,
                  child: movie.poster != null
                      ? CachedNetworkImage(
                          imageUrl:
                              'https://image.tmdb.org/t/p/w92${movie.poster}',
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color:
                                FlixieColors.secondary.withValues(alpha: 0.3),
                            child: const Icon(Icons.movie,
                                color: FlixieColors.secondary),
                          ),
                        )
                      : Container(
                          color: FlixieColors.secondary.withValues(alpha: 0.3),
                          child: const Icon(Icons.movie,
                              color: FlixieColors.secondary),
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
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (year != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        year,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: FlixieColors.medium),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: FlixieColors.medium),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Search result: person tile ──────────────────────────────────────────────

class _PersonResultTile extends StatelessWidget {
  const _PersonResultTile({required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 50,
                height: 75,
                child: person.profilePath != null
                    ? CachedNetworkImage(
                        imageUrl:
                            'https://image.tmdb.org/t/p/w185${person.profilePath}',
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: FlixieColors.secondary.withValues(alpha: 0.3),
                          child: const Icon(Icons.person,
                              color: FlixieColors.secondary),
                        ),
                      )
                    : Container(
                        color: FlixieColors.secondary.withValues(alpha: 0.3),
                        child: const Icon(Icons.person,
                            color: FlixieColors.secondary),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (person.knownForDepartment != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      person.knownForDepartment!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: FlixieColors.medium),
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
