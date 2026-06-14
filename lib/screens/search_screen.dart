import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/movie_short.dart';
import '../models/person.dart';
import '../models/search_result.dart';
import '../models/show.dart';
import '../providers/auth_provider.dart';
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
  _SearchMode _searchMode = _SearchMode.all;
  Timer? _debounce;
  final List<String> _recentSearches = [];

  // Default view data
  List<MovieShort> _trendingMovies = [];
  bool _isLoadingDefault = true;

  // Search results
  SearchResults? _searchResults;
  SearchEntityResults? _entityResults;
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
      final trending = await TrendingService.getTrendingMovies();
      if (mounted) {
        setState(() {
          _trendingMovies = trending;
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
        _entityResults = null;
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
      final SearchResults? results;
      final SearchEntityResults? entityResults;
      switch (_searchMode) {
        case _SearchMode.all:
          results = await SearchService.search(query);
          entityResults = null;
          break;
        case _SearchMode.movies:
          results = await SearchService.search(query, type: 'movie');
          entityResults = null;
          break;
        case _SearchMode.shows:
          results = await SearchService.search(query, type: 'tv');
          entityResults = null;
          break;
        case _SearchMode.people:
          results = await SearchService.search(query, type: 'person');
          entityResults = null;
          break;
        case _SearchMode.companies:
          results = null;
          entityResults = await SearchService.searchCompany(query);
          break;
        case _SearchMode.collections:
          results = null;
          entityResults = await SearchService.searchCollection(query);
          break;
      }
      if (mounted) {
        setState(() {
          _searchResults = results;
          _entityResults = entityResults;
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
              color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(unreadCount < 100 ? '$unreadCount' : '99+'),
              backgroundColor: FlixieColors.tertiary,
              textColor: Colors.black,
              child:
                  const Icon(Icons.notifications_outlined, color: Colors.white),
            ),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildSearchModeSelector(),
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
          hintText: _searchMode.hintText,
          hintStyle: const TextStyle(color: FlixieColors.medium),
          prefixIcon:
              const Icon(Icons.search_rounded, color: FlixieColors.medium),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: FlixieColors.medium),
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
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
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

  Widget _buildSearchModeSelector() {
    final modes = [
      _SearchMode.all,
      _SearchMode.movies,
      _SearchMode.shows,
      _SearchMode.people,
      _SearchMode.companies,
      _SearchMode.collections,
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        itemCount: modes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final mode = modes[index];
          final selected = mode == _searchMode;
          return ChoiceChip(
            selected: selected,
            label: Text(mode.label),
            avatar: Icon(
              mode.icon,
              size: 16,
              color: selected ? Colors.black : FlixieColors.medium,
            ),
            selectedColor: FlixieColors.primary,
            backgroundColor: FlixieColors.tabBarBackgroundFocused,
            labelStyle: TextStyle(
              color: selected ? Colors.black : FlixieColors.light,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            side: BorderSide(
              color: selected
                  ? FlixieColors.primary
                  : Colors.white.withValues(alpha: 0.08),
            ),
            onSelected: (_) => _setSearchMode(mode),
          );
        },
      ),
    );
  }

  void _setSearchMode(_SearchMode mode) {
    if (_searchMode == mode) return;
    setState(() {
      _searchMode = mode;
      _searchResults = null;
      _entityResults = null;
    });
    final query = _controller.text.trim();
    if (query.length >= 3) {
      _performSearch(query);
    }
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
                  child: const Text('See all', style: TextStyle(fontSize: 13)),
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
                  onTap: () => context.push('/movies/${_trendingMovies[i].id}'),
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
          color: Color(0xFFEF4444),
          mode: _SearchMode.movies),
      _BrowseCategory(
          label: 'Shows',
          icon: Icons.live_tv_rounded,
          color: Color(0xFF8B5CF6),
          mode: _SearchMode.shows),
      _BrowseCategory(
          label: 'People',
          icon: Icons.person_outline_rounded,
          color: Color(0xFFF59E0B),
          mode: _SearchMode.people),
      _BrowseCategory(
          label: 'Collections',
          icon: Icons.folder_special_outlined,
          color: Color(0xFF6366F1),
          mode: _SearchMode.collections),
      _BrowseCategory(
          label: 'Studios',
          icon: Icons.business_outlined,
          color: Color(0xFF14B8A6),
          mode: _SearchMode.companies),
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
                  _setSearchMode(cat.mode);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: _searchMode == cat.mode
                        ? cat.color.withValues(alpha: 0.16)
                        : FlixieColors.tabBarBackgroundFocused,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _searchMode == cat.mode
                          ? cat.color.withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.07),
                    ),
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
    final entityResults = _entityResults?.results ?? [];
    final hasSearchResponse = _searchResults != null || _entityResults != null;

    if (hasSearchResponse && results.isEmpty && entityResults.isEmpty) {
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

    if (results.isEmpty && entityResults.isEmpty) {
      return const SizedBox.shrink();
    }

    if (entityResults.isNotEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: entityResults.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = entityResults[index];
          return _EntityResultTile(
            result: item,
            onTap: () {
              _controller.text = item.name;
              setState(() {
                _searchMode = _SearchMode.movies;
                _searchResults = null;
                _entityResults = null;
              });
              _onSearchChanged(item.name);
            },
          );
        },
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = results[index];
        if (item.isPerson && item.person != null) {
          return _PersonResultTile(
            person: item.person!,
            onTap: () => context.push('/people/${item.person!.id}'),
          );
        } else if (item.isShow && item.show != null) {
          return _ShowResultTile(
            show: item.show!,
            onTap: () => context.push('/shows/${item.show!.id}'),
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
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(term,
                style:
                    const TextStyle(color: FlixieColors.light, fontSize: 13)),
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
  const _BrowseCategory({
    required this.label,
    required this.icon,
    required this.color,
    required this.mode,
  });

  final String label;
  final IconData icon;
  final Color color;
  final _SearchMode mode;
}

enum _SearchMode {
  all,
  movies,
  shows,
  people,
  companies,
  collections,
}

extension _SearchModeView on _SearchMode {
  String get label => switch (this) {
        _SearchMode.all => 'All',
        _SearchMode.movies => 'Movies',
        _SearchMode.shows => 'Shows',
        _SearchMode.people => 'People',
        _SearchMode.companies => 'Studios',
        _SearchMode.collections => 'Collections',
      };

  String get hintText => switch (this) {
        _SearchMode.all => 'Search movies, shows or people...',
        _SearchMode.movies => 'Search movies...',
        _SearchMode.shows => 'Search shows...',
        _SearchMode.people => 'Search people...',
        _SearchMode.companies => 'Search production companies...',
        _SearchMode.collections => 'Search collections...',
      };

  IconData get icon => switch (this) {
        _SearchMode.all => Icons.search_rounded,
        _SearchMode.movies => Icons.movie_filter_rounded,
        _SearchMode.shows => Icons.live_tv_rounded,
        _SearchMode.people => Icons.person_outline_rounded,
        _SearchMode.companies => Icons.business_outlined,
        _SearchMode.collections => Icons.folder_special_outlined,
      };
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

// ─── Search result: entity tile ──────────────────────────────────────────────

class _EntityResultTile extends StatelessWidget {
  const _EntityResultTile({required this.result, this.onTap});

  final SearchEntityResult result;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final imagePath =
        result.posterPath ?? result.logoPath ?? result.backdropPath;
    final subtitle = switch (result.type) {
      SearchEntityType.company => [
          'Production company',
          if (result.originCountry != null) result.originCountry!,
        ].join(' · '),
      SearchEntityType.collection => 'Collection',
    };

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: imagePath != null
                      ? CachedNetworkImage(
                          imageUrl: 'https://image.tmdb.org/t/p/w185$imagePath',
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _EntityIconPlaceholder(type: result.type),
                        )
                      : _EntityIconPlaceholder(type: result.type),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: FlixieColors.medium),
                    ),
                    if (result.overview != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        result.overview!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: FlixieColors.light),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.search_rounded, color: FlixieColors.medium),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntityIconPlaceholder extends StatelessWidget {
  const _EntityIconPlaceholder({required this.type});

  final SearchEntityType type;

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      SearchEntityType.company => Icons.business_outlined,
      SearchEntityType.collection => Icons.folder_special_outlined,
    };

    return Container(
      color: FlixieColors.primary.withValues(alpha: 0.18),
      child: Icon(icon, color: FlixieColors.primary),
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

// ─── Search result: show tile ────────────────────────────────────────────────

class _ShowResultTile extends StatelessWidget {
  const _ShowResultTile({required this.show, this.onTap});

  final TvShow show;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final year = _extractYear(show.firstAirDate);
    final posterUrl = show.posterPath == null
        ? null
        : 'https://image.tmdb.org/t/p/w92${show.posterPath}';

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
                  child: posterUrl != null
                      ? CachedNetworkImage(
                          imageUrl: posterUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: FlixieColors.primary.withValues(alpha: 0.3),
                            child: const Icon(Icons.live_tv_rounded,
                                color: FlixieColors.primary),
                          ),
                        )
                      : Container(
                          color: FlixieColors.primary.withValues(alpha: 0.3),
                          child: const Icon(Icons.live_tv_rounded,
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
                      show.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 7,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const _MediaTypePill(
                          label: 'Show',
                          color: FlixieColors.primary,
                        ),
                        if (year != null)
                          Text(
                            year,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: FlixieColors.medium),
                          ),
                        if (show.voteAverage != null &&
                            show.voteAverage! > 0) ...[
                          const Icon(Icons.star_rounded,
                              size: 14, color: FlixieColors.warning),
                          Text(
                            show.voteAverage!.toStringAsFixed(1),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: FlixieColors.warning),
                          ),
                        ],
                      ],
                    ),
                    if ((show.overview ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        show.overview!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: FlixieColors.light),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  color: FlixieColors.medium),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaTypePill extends StatelessWidget {
  const _MediaTypePill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
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
