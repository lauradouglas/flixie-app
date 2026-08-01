import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/models/person.dart';
import 'package:flixie_app/models/search_result.dart';
import 'package:flixie_app/models/show.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/data/search_service.dart';
import 'package:flixie_app/features/home/data/trending_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

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
  int _searchRequestId = 0;

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
    final cached = context.read<AuthProvider>().cachedTrending;
    if (cached != null) {
      _trendingMovies = cached;
      _isLoadingDefault = false;
    }
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
    final query = value.trim();
    setState(() => _query = value);
    if (query.length < 3) {
      _searchRequestId++;
      setState(() {
        _searchResults = null;
        _entityResults = null;
        _isSearching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  void _submitSearch(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    _debounce?.cancel();
    setState(() => _query = value);
    _performSearch(query);
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    final requestId = ++_searchRequestId;
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
      if (mounted && requestId == _searchRequestId) {
        setState(() {
          _searchResults = results;
          _entityResults = entityResults;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted && requestId == _searchRequestId) {
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
        onSubmitted: _submitSearch,
        textInputAction: TextInputAction.search,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: _searchMode.hintText,
          hintStyle: const TextStyle(color: FlixieColors.medium),
          prefixIcon:
              const Icon(Icons.search_rounded, color: FlixieColors.medium),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_query.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: FlixieColors.medium),
                  onPressed: () {
                    _controller.clear();
                    _onSearchChanged('');
                  },
                ),
              IconButton(
                tooltip: 'Search filters',
                icon:
                    const Icon(Icons.tune_rounded, color: FlixieColors.medium),
                onPressed: () {},
              ),
            ],
          ),
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
              const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
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
      // TODO: Re-add Studios and Collections when their search experiences
      // are ready for users.
      // _SearchMode.companies,
      // _SearchMode.collections,
    ];

    return SizedBox(
      height: 54,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
        itemCount: modes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final mode = modes[index];
          final selected = mode == _searchMode;
          return ChoiceChip(
            selected: selected,
            showCheckmark: false,
            label: Text(mode.label),
            avatar: mode == _SearchMode.all
                ? null
                : Icon(
                    mode.icon,
                    size: 17,
                    color: selected ? Colors.black : FlixieColors.medium,
                  ),
            selectedColor: FlixieColors.primary,
            backgroundColor: FlixieColors.tabBarBackgroundFocused,
            labelStyle: TextStyle(
              color: selected ? Colors.black : FlixieColors.light,
              fontWeight: FontWeight.w700,
              fontSize: 13,
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
    final hadSearchResponse = _searchResults != null || _entityResults != null;
    setState(() {
      _searchMode = mode;
      _searchResults = null;
      _entityResults = null;
    });
    final query = _controller.text.trim();
    if (query.length >= 3 || hadSearchResponse) {
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
          // Browse By
          const _SectionHeader(title: 'Browse by'),
          const SizedBox(height: 10),
          _buildBrowseByGrid(),
          const SizedBox(height: 22),
          // Trending Now
          if (_trendingMovies.isNotEmpty) ...[
            const _SectionHeader(title: 'Trending now'),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 16,
                childAspectRatio: 0.52,
              ),
              itemCount: _trendingMovies.length,
              itemBuilder: (context, i) => _TrendingPosterCard(
                movie: _trendingMovies[i],
                onTap: () => context.push('/movies/${_trendingMovies[i].id}'),
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
      // TODO: Re-add Collections and Studios when their search experiences
      // are ready for users.
      // _BrowseCategory(
      //     label: 'Collections',
      //     icon: Icons.folder_special_outlined,
      //     color: Color(0xFF6366F1),
      //     mode: _SearchMode.collections),
      // _BrowseCategory(
      //     label: 'Studios',
      //     icon: Icons.business_outlined,
      //     color: Color(0xFF14B8A6),
      //     mode: _SearchMode.companies),
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

    final people = results
        .where((item) => item.isPerson && item.person != null)
        .map((item) => item.person!)
        .toList();
    final media = results.where((item) => !item.isPerson).toList();
    final total = _searchResults?.totalResults ?? results.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _SearchSummary(query: _query.trim(), total: total),
        if (people.isNotEmpty) ...[
          const SizedBox(height: 24),
          _ResultsSectionHeader(
            icon: Icons.person_outline_rounded,
            title: 'People',
            onSeeAll: _searchMode == _SearchMode.all
                ? () => _setSearchMode(_SearchMode.people)
                : null,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: people.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) => _PersonResultTile(
                person: people[index],
                query: _query.trim(),
                onTap: () => context.push('/people/${people[index].id}'),
              ),
            ),
          ),
        ],
        if (media.isNotEmpty) ...[
          const SizedBox(height: 24),
          _ResultsSectionHeader(
            icon: Icons.movie_filter_outlined,
            title: _searchMode == _SearchMode.movies
                ? 'Movies'
                : _searchMode == _SearchMode.shows
                    ? 'Shows'
                    : 'Movies & shows',
          ),
          const SizedBox(height: 10),
          ...media.map((item) {
            if (item.isShow && item.show != null) {
              return _SearchMediaTile.show(
                show: item.show!,
                query: _query.trim(),
                onTap: () => context.push('/shows/${item.show!.id}'),
              );
            }
            if (item.movie != null) {
              return _SearchMediaTile.movie(
                movie: item.movie!,
                query: _query.trim(),
                onTap: () => context.push('/movies/${item.movie!.id}'),
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ],
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

class _SearchSummary extends StatelessWidget {
  const _SearchSummary({required this.query, required this.total});

  final String query;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child:
              Icon(Icons.search_rounded, color: FlixieColors.medium, size: 22),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                style: const TextStyle(color: FlixieColors.light, fontSize: 14),
                children: [
                  const TextSpan(text: 'Search for '),
                  TextSpan(
                    text: '‘$query’',
                    style: const TextStyle(
                      color: FlixieColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '$total ${total == 1 ? 'result' : 'results'}',
              style: const TextStyle(color: FlixieColors.medium, fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }
}

class _ResultsSectionHeader extends StatelessWidget {
  const _ResultsSectionHeader({
    required this.icon,
    required this.title,
    this.onSeeAll,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: FlixieColors.primary, size: 20),
        const SizedBox(width: 9),
        Text(
          title,
          style: const TextStyle(
            color: FlixieColors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: const Text(
              'See all',
              style: TextStyle(
                color: FlixieColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _SearchMediaTile extends StatelessWidget {
  const _SearchMediaTile._({
    required this.name,
    required this.posterPath,
    required this.year,
    required this.overview,
    required this.rating,
    required this.isShow,
    required this.query,
    this.onTap,
  });

  factory _SearchMediaTile.movie({
    required MovieShort movie,
    required String query,
    VoidCallback? onTap,
  }) =>
      _SearchMediaTile._(
        name: movie.name,
        posterPath: movie.poster,
        year: _extractYear(movie.releaseDate),
        overview: movie.overview,
        rating: movie.voteAverage,
        isShow: false,
        query: query,
        onTap: onTap,
      );

  factory _SearchMediaTile.show({
    required TvShow show,
    required String query,
    VoidCallback? onTap,
  }) =>
      _SearchMediaTile._(
        name: show.name,
        posterPath: show.posterPath,
        year: _extractYear(show.firstAirDate),
        overview: show.overview,
        rating: show.voteAverage,
        isShow: true,
        query: query,
        onTap: onTap,
      );

  final String name;
  final String? posterPath;
  final String? year;
  final String? overview;
  final double? rating;
  final bool isShow;
  final String query;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 112),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: .07)),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 67,
                  height: 100,
                  child: posterPath == null
                      ? _MediaPlaceholder(isShow: isShow)
                      : CachedNetworkImage(
                          imageUrl:
                              'https://image.tmdb.org/t/p/w185$posterPath',
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _MediaPlaceholder(isShow: isShow),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _HighlightedText(
                      text: name,
                      query: query,
                      maxLines: 2,
                      baseStyle: const TextStyle(
                        color: FlixieColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 11,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _MediaTypePill(
                          label: isShow ? 'Show' : 'Movie',
                          color: isShow
                              ? FlixieColors.primary
                              : FlixieColors.danger,
                        ),
                        if (year != null)
                          Text(year!,
                              style: const TextStyle(
                                  color: FlixieColors.medium, fontSize: 13)),
                        if (rating != null && rating! > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: FlixieColors.warning, size: 17),
                              const SizedBox(width: 3),
                              Text(rating!.toStringAsFixed(1),
                                  style: const TextStyle(
                                      color: FlixieColors.medium,
                                      fontSize: 13)),
                            ],
                          ),
                      ],
                    ),
                    if ((overview ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        overview!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FlixieColors.light,
                          fontSize: 12.5,
                          height: 1.28,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded,
                  color: FlixieColors.medium),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder({required this.isShow});
  final bool isShow;

  @override
  Widget build(BuildContext context) => Container(
        color: FlixieColors.surfaceElevated,
        child: Icon(
          isShow ? Icons.live_tv_rounded : Icons.movie_outlined,
          color: FlixieColors.medium,
        ),
      );
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.query,
    required this.baseStyle,
    this.maxLines = 1,
  });

  final String text;
  final String query;
  final TextStyle baseStyle;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final start = text.toLowerCase().indexOf(query.toLowerCase());
    if (query.isEmpty || start < 0) {
      return Text(text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: baseStyle);
    }
    final end = start + query.length;
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: text.substring(0, start)),
          TextSpan(
              text: text.substring(start, end),
              style: const TextStyle(color: FlixieColors.primary)),
          TextSpan(text: text.substring(end)),
        ],
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _PersonResultTile extends StatelessWidget {
  const _PersonResultTile(
      {required this.person, required this.query, this.onTap});

  final Person person;
  final String query;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 188,
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 64,
                    height: 96,
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
                            color:
                                FlixieColors.secondary.withValues(alpha: 0.3),
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
                      _HighlightedText(
                        text: person.name,
                        query: query,
                        maxLines: 2,
                        baseStyle: const TextStyle(
                          color: FlixieColors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
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
      ),
    );
  }
}
