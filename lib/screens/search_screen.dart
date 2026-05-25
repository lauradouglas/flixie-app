import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/movie_short.dart';
import '../models/person.dart';
import '../models/search_result.dart';
import '../providers/auth_provider.dart';
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
  final List<String> _recentSearches = [];
  static const List<String> _popularSearches = [
    'New releases',
    'Marvel',
    'Christopher Nolan',
    'Sci-Fi',
    'Action',
    'Horror',
    'Comedy',
    'Drama',
    'Animated',
  ];

  // Default view data
  List<MovieShort> _trendingMovies = [];
  List<MovieShort> _topRatedMovies = [];
  bool _isLoadingDefault = true;

  // Discover section filter
  final bool _discoverAll = true;

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
      final movieService = context.read<MovieService>();
      final results = await Future.wait([
        TrendingService.getTrendingMovies(),
        movieService.getTopRatedMovies(),
      ]);
      if (mounted) {
        setState(() {
          _trendingMovies = results[0];
          _topRatedMovies = results[1];
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
    if (value.trim().length < 3) {
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
          _recentSearches.remove(query);
          _recentSearches.insert(0, query);
          if (_recentSearches.length > 8) _recentSearches.removeLast();
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
    final unreadCount = context.watch<AuthProvider>().unreadNotificationCount;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Search',
          style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(unreadCount < 100 ? '$unreadCount' : '99+'),
              backgroundColor: FlixieColors.tertiary,
              textColor: Colors.black,
              child: const Icon(Icons.notifications_outlined,
                  color: Colors.white),
            ),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _query.trim().isEmpty
                ? _buildDefaultView()
                : _buildSearchResultsView(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: TextField(
        controller: _controller,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search movies, people, genres...',
          hintStyle: const TextStyle(color: FlixieColors.medium),
          prefixIcon:
              const Icon(Icons.search_rounded, color: FlixieColors.medium),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon:
                      const Icon(Icons.close_rounded, color: FlixieColors.medium),
                  onPressed: () {
                    _controller.clear();
                    _onSearchChanged('');
                  },
                )
              : const Icon(Icons.mic_none_rounded, color: FlixieColors.medium),
          filled: true,
          fillColor: FlixieColors.tabBarBackgroundFocused,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: FlixieColors.primary),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildDefaultView() {
    if (_isLoadingDefault) {
      return const Center(
          child: CircularProgressIndicator(color: FlixieColors.primary));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent Searches
          Row(
            children: [
              const _SectionHeader(title: 'Recent searches'),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _recentSearches.clear()),
                style: TextButton.styleFrom(
                  foregroundColor: FlixieColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                child: const Text('Clear all', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_recentSearches.isEmpty)
            const Text(
              'No recent searches yet.',
              style: TextStyle(color: FlixieColors.medium, fontSize: 14),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recentSearches
                  .map((term) => _RecentSearchChip(
                        term: term,
                        onTap: () {
                          _controller.text = term;
                          _onSearchChanged(term);
                        },
                        onRemove: () =>
                            setState(() => _recentSearches.remove(term)),
                      ))
                  .toList(),
            ),
          const SizedBox(height: 22),
          // Popular Searches
          const _SectionHeader(title: 'Popular searches'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _popularSearches
                .map((term) => GestureDetector(
                      onTap: () {
                        _controller.text = term;
                        _onSearchChanged(term);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: FlixieColors.tabBarBackgroundFocused,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Text(
                          term,
                          style:
                              const TextStyle(color: FlixieColors.light, fontSize: 13),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 22),
          // Browse By
          const _SectionHeader(title: 'Browse by'),
          const SizedBox(height: 10),
          _buildBrowseByGrid(),
          const SizedBox(height: 22),
          // Trending Now
          if (_trendingMovies.isNotEmpty) ...[
            Row(
              children: [
                const _SectionHeader(title: 'Trending now'),
                const Spacer(),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    foregroundColor: FlixieColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  child:
                      const Text('See all', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 225,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemCount: _trendingMovies.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) => _TrendingPosterCard(
                  movie: _trendingMovies[i],
                  onTap: () =>
                      context.push('/movies/${_trendingMovies[i].id}'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBrowseByGrid() {
    const categories = [
      _BrowseCategory(
          label: 'Movies',
          icon: Icons.movie_filter_rounded,
          color: Color(0xFFEF4444)),
      _BrowseCategory(
          label: 'Genres',
          icon: Icons.theater_comedy_outlined,
          color: Color(0xFF14B8A6)),
      _BrowseCategory(
          label: 'People',
          icon: Icons.person_outline_rounded,
          color: Color(0xFFF59E0B)),
      _BrowseCategory(
          label: 'Collections',
          icon: Icons.folder_special_outlined,
          color: Color(0xFF8B5CF6)),
      _BrowseCategory(
          label: 'Studios',
          icon: Icons.business_outlined,
          color: Color(0xFF14B8A6)),
      _BrowseCategory(
          label: 'Keywords',
          icon: Icons.label_outline_rounded,
          color: Color(0xFF10B981)),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.7,
      children: categories
          .map((cat) => GestureDetector(
                onTap: () {
                  _controller.text = cat.label;
                  _onSearchChanged(cat.label);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: FlixieColors.tabBarBackgroundFocused,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.07)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(cat.icon, color: cat.color, size: 20),
                      const SizedBox(width: 7),
                      Text(
                        cat.label,
                        style: const TextStyle(
                          color: FlixieColors.light,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
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

    final filtered = results.where((item) {
      if (item.isPerson) return true;
      return item.movie?.mediaType != 'tv';
    }).toList();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = filtered[index];
        if (item.isPerson && item.person != null) {
          return _PersonResultTile(
            person: item.person!,
            onTap: () => context.push('/people/${item.person!.id}'),
          );
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
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: FlixieColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: FlixieColors.light,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

// ─── Recent search chip ──────────────────────────────────────────────────────

class _RecentSearchChip extends StatelessWidget {
  const _RecentSearchChip(
      {required this.term, required this.onTap, required this.onRemove});

  final String term;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: FlixieColors.tabBarBackgroundFocused,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(term,
                style: const TextStyle(
                    color: FlixieColors.light, fontSize: 13)),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close_rounded,
                  size: 14, color: FlixieColors.medium),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Browse-by category data ─────────────────────────────────────────────────

class _BrowseCategory {
  const _BrowseCategory(
      {required this.label, required this.icon, required this.color});
  final String label;
  final IconData icon;
  final Color color;
}

// ─── Trending poster card ────────────────────────────────────────────────────

class _TrendingPosterCard extends StatelessWidget {
  const _TrendingPosterCard({required this.movie, this.onTap});

  final MovieShort movie;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final year = _extractYear(movie.releaseDate);
    final vote = movie.voteAverage;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 130,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: movie.poster != null
                    ? CachedNetworkImage(
                        imageUrl:
                            'https://image.tmdb.org/t/p/w342${movie.poster}',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorWidget: (_, __, ___) => Container(
                          color: FlixieColors.tabBarBackgroundFocused,
                          child: const Icon(Icons.movie_outlined,
                              color: FlixieColors.medium),
                        ),
                      )
                    : Container(
                        color: FlixieColors.tabBarBackgroundFocused,
                        child: const Icon(Icons.movie_outlined,
                            color: FlixieColors.medium),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              movie.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: FlixieColors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                if (year != null)
                  Text(year,
                      style: const TextStyle(
                          color: FlixieColors.medium, fontSize: 12)),
                if (year != null && vote != null && vote > 0) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.star_rounded,
                      size: 12, color: FlixieColors.tertiary),
                  const SizedBox(width: 2),
                  Text(
                    vote.toStringAsFixed(1),
                    style: const TextStyle(
                        color: FlixieColors.tertiary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ],
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
                        child: const Icon(Icons.movie,
                            color: FlixieColors.primary),
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
                        voteAvg != null ? voteAvg.toStringAsFixed(1) : '—',
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
                  child: const Icon(Icons.movie_outlined, size: 48),
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
                      const Text(
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
  const _PersonResultTile({required this.person, this.onTap});

  final Person person;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
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
                  child: person.profileImgUrl != null
                      ? CachedNetworkImage(
                          imageUrl:
                              'https://image.tmdb.org/t/p/w185${person.profileImgUrl}',
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color:
                                FlixieColors.secondary.withValues(alpha: 0.3),
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
                    if (person.department != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        person.department!,
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
      ),
    );
  }
}
