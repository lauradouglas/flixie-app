import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/models/person.dart';
import 'package:flixie_app/models/search_result.dart';
import 'package:flixie_app/models/show.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';
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
  bool _loadingMore = false;
  bool _searchFailed = false;
  bool _defaultFailed = false;
  List<String> _recentSearches = [];
  late final Future<void> _historyReady;
  static const _historyKey = 'device_recent_searches_v1';

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _recentSearches = prefs.getStringList(_historyKey) ?? []);
    }
  }

  Future<void> _saveHistory(String query) async {
    await _historyReady;
    if (!mounted) return;
    final value = query.trim();
    if (value.isEmpty) return;
    final next = [
      value,
      ..._recentSearches.where((q) => q.toLowerCase() != value.toLowerCase())
    ].take(8).toList();
    setState(() => _recentSearches = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, next);
  }

  Future<void> _removeHistory([String? query]) async {
    await _historyReady;
    if (!mounted) return;
    final next = query == null
        ? <String>[]
        : _recentSearches.where((q) => q != query).toList();
    setState(() => _recentSearches = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, next);
  }

  @override
  void initState() {
    super.initState();
    final cached = context.read<AuthProvider>().cachedTrending;
    if (cached != null) {
      _trendingMovies = cached;
      _isLoadingDefault = false;
    }
    _historyReady = _loadHistory();
    _loadDefaultData();
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadDefaultData() async {
    setState(() {
      _defaultFailed = false;
      _isLoadingDefault = _trendingMovies.isEmpty;
    });
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
        setState(() {
          _isLoadingDefault = false;
          _defaultFailed = true;
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _searchRequestId++;
    final query = value.trim();
    setState(() {
      _query = value;
      _searchResults = null;
      _entityResults = null;
      _searchFailed = false;
      _loadingMore = false;
      _isSearching = query.isNotEmpty;
    });
    if (query.isEmpty) return;
    _debounce =
        Timer(const Duration(milliseconds: 400), () => _performSearch(query));
  }

  void _submitSearch(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    _debounce?.cancel();
    setState(() => _query = value);
    _saveHistory(query);
    _performSearch(query);
  }

  Future<void> _performSearch(String query, {bool loadMore = false}) async {
    if (query.trim().isEmpty) return;
    final requestId = ++_searchRequestId;
    final page =
        loadMore ? (_searchResults?.page ?? _entityResults?.page ?? 1) + 1 : 1;
    setState(() {
      _isSearching = !loadMore;
      _loadingMore = loadMore;
      _searchFailed = false;
    });
    try {
      final SearchResults? results;
      final SearchEntityResults? entityResults;
      switch (_searchMode) {
        case _SearchMode.all:
          results = await SearchService.search(query, page: page);
          entityResults = null;
          break;
        case _SearchMode.movies:
          results =
              await SearchService.search(query, type: 'movie', page: page);
          entityResults = null;
          break;
        case _SearchMode.shows:
          results = await SearchService.search(query, type: 'tv', page: page);
          entityResults = null;
          break;
        case _SearchMode.people:
          results =
              await SearchService.search(query, type: 'person', page: page);
          entityResults = null;
          break;
        case _SearchMode.companies:
          results = null;
          entityResults = await SearchService.searchCompany(query, page: page);
          break;
        case _SearchMode.collections:
          results = null;
          entityResults =
              await SearchService.searchCollection(query, page: page);
          break;
      }
      if (mounted && requestId == _searchRequestId) {
        setState(() {
          _searchResults = loadMore && results != null
              ? SearchResults(
                  page: results.page,
                  results: [...?_searchResults?.results, ...results.results],
                  totalPages: results.totalPages,
                  totalResults: results.totalResults)
              : results;
          _entityResults = entityResults;
          _isSearching = false;
          _loadingMore = false;
        });
      }
    } catch (e) {
      if (mounted && requestId == _searchRequestId) {
        setState(() {
          _isSearching = false;
          _loadingMore = false;
          _searchFailed = true;
        });
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
        title: Text(
          'Search',
          style: TextStyle(
              color: context.colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(unreadCount < 100 ? '$unreadCount' : '99+'),
              backgroundColor: FlixieColors.primaryShade,
              textColor: Colors.white,
              textStyle:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              child: Icon(Icons.notifications_outlined,
                  color: context.colors.white),
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
        style: TextStyle(color: context.colors.white),
        decoration: InputDecoration(
          hintText: _searchMode.hintText,
          hintStyle: TextStyle(color: context.colors.medium),
          prefixIcon: Icon(Icons.search_rounded, color: context.colors.medium),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_query.isNotEmpty)
                IconButton(
                  tooltip: 'Clear search',
                  icon: Icon(Icons.close_rounded, color: context.colors.medium),
                  onPressed: () {
                    _controller.clear();
                    _onSearchChanged('');
                  },
                ),
            ],
          ),
          filled: true,
          fillColor: context.colors.tabBarBackgroundFocused,
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
      height: 42 + MediaQuery.textScalerOf(context).scale(16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
        itemCount: modes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final mode = modes[index];
          final selected = mode == _searchMode;
          return FlixiePill.choice(
              selected: selected,
              showCheckmark: false,
              label: Text(mode.label),
              avatar: mode == _SearchMode.all
                  ? null
                  : Icon(
                      mode.icon,
                      size: 17,
                      color: selected ? Colors.white : context.colors.medium,
                    ),
              onSelected: (_) => _setSearchMode(mode));
        },
      ),
    );
  }

  void _setSearchMode(_SearchMode mode) {
    if (_searchMode == mode) return;
    _debounce?.cancel();
    _searchRequestId++;
    setState(() {
      _searchMode = mode;
      _searchResults = null;
      _entityResults = null;
      _loadingMore = false;
      _searchFailed = false;
      _isSearching = false;
    });
    final query = _controller.text.trim();
    if (query.isNotEmpty) _performSearch(query);
  }

  Widget _buildDefaultView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (_recentSearches.isNotEmpty) ...[
          Row(children: [
            const Expanded(
                child: Text('Recent searches',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            TextButton(
                onPressed: () => _removeHistory(),
                child: const Text('Clear all'))
          ]),
          for (final query in _recentSearches)
            ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history_rounded, size: 20),
                title: Text(query),
                trailing: IconButton(
                    tooltip: 'Remove $query from recent searches',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => _removeHistory(query)),
                onTap: () {
                  _controller.text = query;
                  _submitSearch(query);
                }),
          const SizedBox(height: 16),
        ],
        const _SectionHeader(title: 'Trending movies'),
        const SizedBox(height: 12),
        if (_isLoadingDefault) const Center(child: CircularProgressIndicator()),
        if (_defaultFailed)
          _retryMessage('Couldn’t load trending movies.', _loadDefaultData),
        LayoutBuilder(builder: (context, constraints) {
          final columns = (constraints.maxWidth /
                  (180 * MediaQuery.textScalerOf(context).scale(1)))
              .floor()
              .clamp(2, 5);
          final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
          return Wrap(spacing: 12, runSpacing: 20, children: [
            for (final movie in _trendingMovies)
              SizedBox(
                  width: width,
                  child: _TrendingPosterCard(
                      movie: movie,
                      onTap: () => context.push(movieDetailPath(movie.id,
                          source: DetailSource.trending)))),
          ]);
        }),
      ],
    );
  }

  Widget _retryMessage(String message, VoidCallback retry) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(message),
          TextButton(onPressed: retry, child: const Text('Try again'))
        ]),
      );

  Widget _buildSearchResultsView() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchFailed && _searchResults == null && _entityResults == null) {
      return _retryMessage(
          'Couldn’t load search results.', () => _performSearch(_query.trim()));
    }
    final results = _searchResults?.results ?? [];
    final entityResults = _entityResults?.results ?? [];
    final hasSearchResponse = _searchResults != null || _entityResults != null;

    if (hasSearchResponse && results.isEmpty && entityResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: context.colors.medium),
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

    final total = _searchResults?.totalResults ?? results.length;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      itemCount: results.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: _SearchSummary(query: _query.trim(), total: total));
        }
        if (index == results.length + 1) {
          if (_searchFailed) {
            return _retryMessage('Couldn’t load more results.',
                () => _performSearch(_query.trim(), loadMore: true));
          }
          if ((_searchResults?.page ?? 0) >=
              (_searchResults?.totalPages ?? 0)) {
            return const SizedBox.shrink();
          }
          return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: _loadingMore
                  ? const Center(child: CircularProgressIndicator())
                  : TextButton(
                      onPressed: () =>
                          _performSearch(_query.trim(), loadMore: true),
                      child: const Text('Load more')));
        }
        final item = results[index - 1];
        if (item.isPerson && item.person != null) {
          return _PersonResultTile(
            person: item.person!,
            query: _query.trim(),
            onTap: () {
              _saveHistory(_query);
              context.push(personDetailPath(
                item.person!.id,
                source: DetailSource.search,
              ));
            },
          );
        }
        if (item.isShow && item.show != null) {
          return _SearchMediaTile.show(
            show: item.show!,
            query: _query.trim(),
            onTap: () {
              _saveHistory(_query);
              context.push(showDetailPath(
                item.show!.id,
                source: DetailSource.search,
              ));
            },
          );
        }
        if (item.movie != null) {
          return _SearchMediaTile.movie(
            movie: item.movie!,
            query: _query.trim(),
            onTap: () {
              _saveHistory(_query);
              context.push(movieDetailPath(
                item.movie!.id,
                source: DetailSource.search,
              ));
            },
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
          style: TextStyle(
            color: context.colors.light,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

// ─── Browse-by category data ─────────────────────────────────────────────────

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
            AspectRatio(
              aspectRatio: 2 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: movie.poster != null
                    ? CachedNetworkImage(
                        imageUrl:
                            'https://image.tmdb.org/t/p/w342${movie.poster}',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorWidget: (_, __, ___) => Container(
                          color: context.colors.tabBarBackgroundFocused,
                          child: Icon(Icons.movie_outlined,
                              color: context.colors.medium),
                        ),
                      )
                    : Container(
                        color: context.colors.tabBarBackgroundFocused,
                        child: Icon(Icons.movie_outlined,
                            color: context.colors.medium),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              movie.name,
              style: TextStyle(
                  color: context.colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14),
            ),
            const SizedBox(height: 3),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (year != null)
                  Text(year,
                      style: TextStyle(
                          color: context.colors.medium, fontSize: 12)),
                if (year != null && vote != null && vote > 0) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.star_rounded,
                      size: 12, color: context.colors.tertiary),
                  const SizedBox(width: 2),
                  Text(
                    vote.toStringAsFixed(1),
                    style: TextStyle(
                        color: context.colors.tertiary,
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
                          ?.copyWith(color: context.colors.medium),
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
                            ?.copyWith(color: context.colors.light),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.search_rounded, color: context.colors.medium),
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
    return FlixiePill.label(label: Text(label));
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
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(Icons.search_rounded,
              color: context.colors.medium, size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                style: TextStyle(color: context.colors.light, fontSize: 14),
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
              style: TextStyle(color: context.colors.medium, fontSize: 13),
            ),
          ],
        )),
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
                      baseStyle: TextStyle(
                        color: context.colors.white,
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
                              : context.colors.danger,
                        ),
                        if (year != null)
                          Text(year!,
                              style: TextStyle(
                                  color: context.colors.medium, fontSize: 13)),
                        if (rating != null && rating! > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded,
                                  color: context.colors.warning, size: 17),
                              const SizedBox(width: 3),
                              Text(rating!.toStringAsFixed(1),
                                  style: TextStyle(
                                      color: context.colors.medium,
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
                        style: TextStyle(
                          color: context.colors.light,
                          fontSize: 12.5,
                          height: 1.28,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: context.colors.medium),
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
        color: context.colors.surfaceElevated,
        child: Icon(
          isShow ? Icons.live_tv_rounded : Icons.movie_outlined,
          color: context.colors.medium,
        ),
      );
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.query,
    required this.baseStyle,
  });

  final String text;
  final String query;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    final start = text.toLowerCase().indexOf(query.toLowerCase());
    if (query.isEmpty || start < 0) {
      return Text(text, style: baseStyle);
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
                  child: person.profileImgUrl != null
                      ? CachedNetworkImage(
                          imageUrl:
                              'https://image.tmdb.org/t/p/w185${person.profileImgUrl}',
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _placeholder(context),
                        )
                      : _placeholder(context),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HighlightedText(
                      text: person.name,
                      query: query,
                      baseStyle: TextStyle(
                        color: context.colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 10,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _MediaTypePill(
                          label: 'Person',
                          color: context.colors.secondary,
                        ),
                        if (person.department?.isNotEmpty ?? false)
                          Text(
                            person.department!,
                            style: TextStyle(
                              color: context.colors.medium,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: context.colors.medium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
        color: context.colors.secondary.withValues(alpha: .3),
        child: Icon(Icons.person, color: context.colors.secondary),
      );
}
