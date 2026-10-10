import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/app/theme/flixie_typography.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/navigation/tab_refresh_controller.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/core/widgets/flixie_page.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/features/settings/presentation/pages/settings_screen.dart'
    show showSettingsEditDetailsSheet;
import 'package:flixie_app/features/watchlist/domain/release_status.dart';
import 'package:flixie_app/features/watchlist/domain/tonight_filters.dart';
import 'package:flixie_app/features/watchlist/presentation/widgets/filter_sheet.dart';
import 'package:flixie_app/features/watchlist/presentation/widgets/tonight_filters_panel.dart';
import 'package:flixie_app/features/watchlist/presentation/widgets/watchlist_navigation_button.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/models/watchlist_movie.dart';

import '../../models/watchlist_show_entry.dart';
import '../controllers/watchlist_controller.dart';
import '../watchlist_action_flow.dart';
import '../widgets/watchlist_movie_row.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen>
    with WidgetsBindingObserver {
  final _tonightPanelKey = GlobalKey();
  void _clearFilters() {
    _searchController.clear();
    _watchlist.clearFilters();
  }

  final TextEditingController _searchController = TextEditingController();

  WatchlistActionFlow get _actions =>
      WatchlistActionFlow(context: context, watchlist: _watchlist);

  late final WatchlistController _watchlist;
  AuthProvider? _authProvider;

  @override
  void initState() {
    super.initState();
    _authProvider = context.read<AuthProvider>();
    _watchlist = WatchlistController(
      auth: _authProvider!,
      scheduleAfterFrame: (callback) =>
          WidgetsBinding.instance.addPostFrameCallback((_) => callback()),
    );
    _watchlist.addListener(_onWatchlistChanged);
    _authProvider!.addListener(_watchlist.onUserChanged);
    WidgetsBinding.instance.addObserver(this);
    TabRefreshController.watchlist.addListener(_watchlist.refreshWatchlist);
    _watchlist.loadWatchlist();
    _searchController.addListener(_onSearchChanged);
  }

  void _onWatchlistChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    if (!identical(auth, _authProvider)) {
      _authProvider?.removeListener(_watchlist.onUserChanged);
      _authProvider = auth;
      _authProvider!.addListener(_watchlist.onUserChanged);
      _watchlist.bindAuth(auth);
    }
  }

  void _onSearchChanged() => _watchlist.setSearchQuery(_searchController.text);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _watchlist.refreshWatchlist();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    TabRefreshController.watchlist.removeListener(_watchlist.refreshWatchlist);
    _authProvider?.removeListener(_watchlist.onUserChanged);
    _watchlist.removeListener(_onWatchlistChanged);
    _watchlist.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WatchlistFilterSheet(
        genres: _watchlist.allGenres(),
        years: _watchlist.allYears(),
        currentGenre: _watchlist.filters.genre,
        currentMinRating: _watchlist.filters.minRating,
        currentYear: _watchlist.filters.year,
        currentMaxRuntime: _watchlist.filters.maxRuntime,
        currentSort: _watchlist.filters.sort,
        onApply: (genre, minRating, year, maxRuntime, sort) {
          _watchlist.updateFilters((filters) {
            filters.genre = genre;
            filters.minRating = minRating;
            filters.year = year;
            filters.maxRuntime = maxRuntime;
            filters.sort = sort;
          });
        },
      ),
    );
  }

  Widget _buildStatsRow() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              Text(
                  '${_watchlist.allWatchlist.length + _watchlist.allShowWatchlist.length} saved titles',
                  style: TextStyle(color: context.colors.light)),
              TextButton(
                  onPressed: () => context.push('/watch-history'),
                  child: const Text('Watch history')),
            ]),
      );

  Future<void> _editPreferences() async {
    Navigator.of(context, rootNavigator: true).pop();
    await showSettingsEditDetailsSheet(context);
    if (mounted) _watchlist.loadWatchlist();
  }

  Widget _buildSortFilterRow({VoidCallback? onChange}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildCheckboxFilter(
                label: 'Friends watched',
                selected: _watchlist.filters.friendsOnly,
                onChanged: (value) {
                  _watchlist
                      .updateFilters((filters) => filters.friendsOnly = value);
                  onChange?.call();
                },
              ),
              TextButton.icon(
                  onPressed: _openFilterSheet,
                  icon: const Icon(Icons.tune),
                  label: Text(_watchlist.sortByLabel())),
              PopupMenuButton<int>(
                  tooltip: 'Viewing status',
                  onSelected: (value) {
                    _watchlist.updateFilters((filters) {
                      filters.tab = value;
                      if (value == 2) filters.release = null;
                    });
                  },
                  itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: 0, child: Text('All viewing states')),
                        PopupMenuItem(value: 2, child: Text('Coming soon')),
                        PopupMenuItem(value: 3, child: Text('Watched'))
                      ],
                  child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(Icons.filter_list,
                          color: context.colors.light))),
              IconButton(
                  tooltip: 'Refresh watchlist',
                  onPressed: _watchlist.refreshWatchlist,
                  icon: const Icon(Icons.refresh_rounded)),
              if (_watchlist.filters.tab == 3)
                TextButton(
                    onPressed: _actions.clearWatchedMovies,
                    child: const Text('Clear watched movies')),
              if (_watchlist.hasActiveFilters ||
                  _watchlist.filters.friendsOnly ||
                  _watchlist.filters.tab != 0)
                TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Clear filters')),
            ]),
      );

  Widget _buildReleaseFilters() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Wrap(spacing: 8, runSpacing: 4, children: [
          for (final (status, label) in <(ReleaseStatus?, String)>[
            (null, 'All releases'),
            (ReleaseStatus.outNow, 'Out now'),
            (ReleaseStatus.comingSoon, 'Coming soon'),
          ])
            FlixiePill.choice(
              label: Text(label),
              selected: (_watchlist.filters.tab == 2
                      ? ReleaseStatus.comingSoon
                      : _watchlist.filters.release) ==
                  status,
              onSelected: (_) {
                _watchlist.updateFilters((filters) {
                  filters.release = status;
                  if (filters.tab == 2) filters.tab = 0;
                });
              },
            ),
        ]),
      );

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: context.colors.textPrimary, fontSize: 15),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search watchlist',
          hintStyle: TextStyle(color: context.colors.medium),
          prefixIcon: Icon(Icons.search_rounded,
              color: context.colors.medium, size: 21),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: Icon(Icons.close_rounded,
                      color: context.colors.medium, size: 20),
                  onPressed: () => _searchController.clear(),
                ),
          filled: true,
          fillColor: context.colors.surfaceElevated,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: FlixieColors.primary),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FlixiePageScaffold(
      appBar: AppBar(
        leading: const WatchlistNavigationButton(),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: (MediaQuery.textScalerOf(context).scale(24) + 12)
            .clamp(48.0, double.infinity),
        title: Text('Watchlist',
            style: TextStyle(
                fontFamily: FlixieTypography.fontFamily,
                color: context.colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: context.colors.white),
            tooltip: 'Add movie',
            onPressed: _actions.addMovie,
          ),
        ],
      ),
      body: _watchlist.loading
          ? const ContentListSkeleton(label: 'Loading watchlist')
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final items = _watchlist.visibleItems;
    _watchlist.prepareEnrichment(items);
    final user = context.read<AuthProvider>().dbUser;
    final hasItems = _watchlist.allWatchlist.isNotEmpty ||
        _watchlist.allShowWatchlist.isNotEmpty;

    final header = <Widget>[
      if (_watchlist.loadError != null)
        TextButton(
            onPressed: _watchlist.refreshWatchlist,
            child: Text('${_watchlist.loadError} · Retry')),
      if (_watchlist.experienceError != null)
        TextButton(
            onPressed: _watchlist.retryExperience,
            child: Text('${_watchlist.experienceError} Retry')),
      _buildStatsRow(),
      _buildSearchBar(),
      _buildMediaFilter(),
      if (hasItems) _buildReleaseFilters(),
      if (hasItems)
        TonightFiltersPanel(
          key: _tonightPanelKey,
          minutes: _watchlist.filters.maxRuntime,
          mood: _watchlist.filters.mood,
          avoid: _watchlist.filters.avoid,
          genre: _watchlist.filters.genre,
          genres: _watchlist.allGenres(),
          onGenre: (genre) => _watchlist.updateFilters((filters) {
            filters.genre = genre;
            filters.findingToday = false;
            filters.request = '';
            filters.mood = WatchlistMood.any;
            filters.avoid = {};
          }),
          providers: {
            for (final p in [
              ..._watchlist.savedProviders,
              ..._watchlist.searchProviders
            ])
              p.id: p
          }.values.toList(),
          selectedProviders:
              _watchlist.filters.providerIds ?? _watchlist.userWatchProviderIds,
          savedProviderIds: _watchlist.userWatchProviderIds,
          servicesOnly: _watchlist.filters.servicesOnly,
          rentals: _watchlist.filters.includeRentals,
          count: items.length,
          region: user?.watchProviderRegion ?? 'GB',
          loading: _watchlist.experienceLoading ||
              _watchlist.filters.servicesOnly &&
                  (_watchlist.loadingWatchProviderAvailability ||
                      _watchlist.loadingShowWatchProviderAvailability),
          onTime: (value) => _watchlist.updateFilters((filters) {
            filters.maxRuntime = value;
          }),
          onMood: (value) => _watchlist.updateFilters((filters) {
            filters.mood = value;
          }),
          onServices: _watchlist.setProviders,
          onSort: _openFilterSheet,
          sortLabel: _watchlist.usesExperience && !_watchlist.comingSoonOnly
              ? 'Best fit'
              : _watchlist.sortByLabel(),
          onMore: () => showModalBottomSheet<void>(
              context: context,
              useRootNavigator: true,
              useSafeArea: true,
              isScrollControlled: true,
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .8),
              builder: (context) => SingleChildScrollView(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('More watchlist filters',
                            style: Theme.of(context).textTheme.titleLarge),
                        StatefulBuilder(
                            builder: (context, update) => _buildSortFilterRow(
                                onChange: () => update(() {}))),
                      ])))),
          onClear: _clearFilters,
          onPick: () => _pickFromTonight(items),
        ),
      if (_watchlist.usesExperience &&
          !_watchlist.experienceLoading &&
          _watchlist.experienceMessage != null)
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(_watchlist.experienceMessage!)),
      if (_watchlist.usesExperience &&
          !_watchlist.experienceLoading &&
          items.isEmpty &&
          (_watchlist.filters.avoid.isNotEmpty ||
              _watchlist.hasUncheckedExclusions))
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
                'Some titles were left out because we couldn’t check the content you want to avoid.')),
      if (_watchlist.filters.friendsOnly &&
          (_watchlist.loadingFriends || _watchlist.hasPendingEnrichment))
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ContentPlaceholder(
                label: 'Loading friends',
                style: ContentPlaceholderStyle.compact)),
      if (_watchlist.filters.friendsOnly &&
          !_watchlist.loadingFriends &&
          !_watchlist.hasPendingEnrichment &&
          (_watchlist.recommendationsByMovieId.length <
                  _watchlist.allWatchlist.length ||
              _watchlist.friendsByShowId.length <
                  _watchlist.allShowWatchlist.length))
        TextButton(
            onPressed: () {
              _watchlist.resetEnrichment();
              _watchlist.filterWatchlist();
            },
            child: const Text('Some friends couldn’t load · Retry')),
      if ((_watchlist.filters.tab == 1 || _watchlist.filters.servicesOnly) &&
          !_watchlist.loadingWatchProviderAvailability &&
          !_watchlist.loadingShowWatchProviderAvailability &&
          !_watchlist.hasPendingEnrichment &&
          (_watchlist.movieWatchProviders.length <
                  _watchlist.allWatchlist.length ||
              _watchlist.showWatchProviders.length <
                  _watchlist.allShowWatchlist.length))
        TextButton(
            onPressed: () {
              _watchlist.resetEnrichment();
              _watchlist.filterWatchlist();
            },
            child: const Text('Some availability couldn’t load · Retry')),
    ];

    if (items.isEmpty) {
      if (_watchlist.experienceLoading ||
          (_watchlist.filters.tab == 1 &&
              (_watchlist.loadingWatchProviderAvailability ||
                  _watchlist.loadingShowWatchProviderAvailability))) {
        return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          ...header,
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: ContentPlaceholder(
                  label: 'Loading watchlist picks', rows: 3)),
        ]);
      }
      final emptyLabel = _watchlist.experienceLoading
          ? 'Finding your picks…'
          : _watchlist.experienceError != null
              ? 'Your picks couldn’t load'
              : _watchlist.usesExperience
                  ? 'Nothing fits all of this yet. Try a different description or adjust your filters.'
                  : switch (_watchlist.filters.tab) {
                      1 => _watchlist.loadingWatchProviderAvailability ||
                              _watchlist.loadingShowWatchProviderAvailability
                          ? 'Checking your providers...'
                          : 'Nothing you can watch right now',
                      2 => 'No upcoming titles in your watchlist',
                      3 => 'No watched movies in your watchlist',
                      _ => hasItems || _searchController.text.isNotEmpty
                          ? 'No watchlist matches'
                          : 'Your watchlist is empty',
                    };
      return ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ...header,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _watchlist.filters.tab == 3
                        ? Icons.check_circle_outline
                        : _watchlist.filters.tab == 1
                            ? Icons.play_circle_outline_rounded
                            : Icons.movie_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    emptyLabel,
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  if (hasItems)
                    TextButton(
                        onPressed: _clearFilters,
                        child: const Text('Clear filters')),
                  if (_watchlist.filters.tab == 0 &&
                      _searchController.text.isEmpty &&
                      !hasItems) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Add movies or shows to start building your watchlist',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      key: const ValueKey('watchlist-cards'),
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: header.length + items.length,
      separatorBuilder: (context, index) => index < header.length
          ? const SizedBox.shrink()
          : const SizedBox(height: 4),
      itemBuilder: (context, index) {
        if (index < header.length) return header[index];

        final itemIndex = index - header.length;
        final pageStart = (itemIndex ~/ 20) * 20;
        _watchlist.scheduleEnrichment(
            items.skip(pageStart).take(itemIndex % 20 >= 15 ? 40 : 20));
        final item = items[itemIndex];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_watchlist.usesExperience &&
                _watchlist.experienceFits[_watchlist.experienceKey(item)] !=
                    null)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text([
                    ..._watchlist
                        .experienceFits[_watchlist.experienceKey(item)]!
                        .reasons,
                  ].join(' · '))),
            item is WatchlistMovie
                ? _buildWatchlistRow(item, user)
                : _buildShowWatchlistRow(item as WatchlistShowEntry),
          ]),
        );
      },
    );
  }

  Future<void> _pickFromTonight(List<Object> items) async {
    if (items.isEmpty) return;
    final item = _watchlist.usesExperience
        ? items.first
        : items[Random().nextInt(items.length)];
    final movie = item is WatchlistMovie ? item : null;
    final show = item is WatchlistShowEntry ? item : null;
    final title = movie?.movie?.title ?? show!.title;
    final runtime = movie?.movie?.runtime ?? show?.runtime;
    await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .8),
        builder: (sheetContext) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tonight’s pick',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Text([
                    if (runtime != null && runtime > 0)
                      '$runtime min${show != null ? ' per episode (estimated)' : ''}',
                    if (_watchlist.filters.mood != WatchlistMood.any)
                      ...(_watchlist
                              .experienceFits[_watchlist.experienceKey(item)]
                              ?.reasons ??
                          []),
                    _watchlist.usesExperience
                        ? 'Best available fit from ${items.length} matching titles'
                        : 'Randomly chosen from your ${items.length} matching titles'
                  ].join(' · ')),
                  const SizedBox(height: 20),
                  FilledButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        context.push(movie != null
                            ? '/movies/${movie.movieId}'
                            : '/shows/${show!.showId}');
                      },
                      child: const Text('View watch options')),
                ])));
  }

  Widget _buildCheckboxFilter({
    required String label,
    required bool selected,
    required ValueChanged<bool> onChanged,
  }) =>
      Semantics(
        label: label,
        checked: selected,
        onTap: () => onChanged(!selected),
        excludeSemantics: true,
        child: InkWell(
          onTap: () => onChanged(!selected),
          borderRadius: BorderRadius.circular(4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IgnorePointer(
                  child: Checkbox(
                    value: selected,
                    onChanged: (value) => onChanged(value ?? false),
                    activeColor: FlixieColors.primary,
                    checkColor: Colors.white,
                    side: BorderSide(color: context.colors.light),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(3)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(label,
                        style: TextStyle(
                          fontFamily: FlixieTypography.fontFamily,
                          fontSize: 13,
                          color: selected
                              ? context.colors.white
                              : context.colors.light,
                        )),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildMediaFilter() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: context.colors.light.withValues(alpha: .2))),
          ),
          child: SizedBox(
            width: double.infinity,
            child: Wrap(spacing: 16, children: [
              for (final (index, label) in ['All', 'Movies', 'Shows'].indexed)
                Semantics(
                  selected: _watchlist.filters.media == index,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(
                        color: _watchlist.filters.media == index
                            ? context.colors.primaryText
                            : Colors.transparent,
                        width: 3,
                      )),
                    ),
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: _watchlist.filters.media == index
                            ? context.colors.white
                            : context.colors.light,
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 12),
                        shape: const RoundedRectangleBorder(),
                        textStyle: TextStyle(
                          fontFamily: FlixieTypography.fontFamily,
                          fontSize: 15,
                          fontWeight: _watchlist.filters.media == index
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      onPressed: () => _watchlist
                          .updateFilters((filters) => filters.media = index),
                      child: Text(label),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      );

  Widget _buildWatchlistRow(WatchlistMovie item, dynamic user) {
    final isWatched = user?.isMovieWatched(item.movieId) ?? false;
    final pending =
        !_watchlist.completedEnrichment.contains('movie:${item.movieId}');
    final isLoadingProviders =
        pending && !_watchlist.movieWatchProviders.containsKey(item.movieId);
    final providers =
        _watchlist.movieWatchProviders[item.movieId] ?? const <WatchProvider>[];
    final canWatchNow = _watchlist.isAvailableOnUserProviders(item.movieId);
    return WatchlistMovieRow(
      watchlistItem: item,
      isWatched: isWatched,
      availableProviders: providers,
      userWatchProviderIds: _watchlist.filters.servicesOnly
          ? (_watchlist.filters.providerIds ?? _watchlist.userWatchProviderIds)
          : _watchlist.userWatchProviderIds,
      userWatchProviderMatchKeys: _watchlist.filters.servicesOnly
          ? [..._watchlist.savedProviders, ..._watchlist.searchProviders]
              .where((p) => (_watchlist.filters.providerIds ??
                      _watchlist.userWatchProviderIds)
                  .contains(p.id))
              .map((p) => p.matchKey)
              .toSet()
          : _watchlist.userWatchProviderMatchKeys,
      canWatchNow: canWatchNow,
      isLoadingProviders: isLoadingProviders,
      providersFailed: !isLoadingProviders &&
          !_watchlist.movieWatchProviders.containsKey(item.movieId),
      region: context.read<AuthProvider>().dbUser?.watchProviderRegion ?? 'GB',
      onEditPreferences: _editPreferences,
      onRetryProviders: () => _watchlist.retryEnrichment(item),
      isLoadingFriends: pending &&
          !_watchlist.recommendationsByMovieId.containsKey(item.movieId),
      friendsFailed: !pending &&
          !_watchlist.recommendationsByMovieId.containsKey(item.movieId),
      onRetryFriends: () => _watchlist.retryEnrichment(item),
      recommendations:
          _watchlist.recommendationsByMovieId[item.movieId] ?? const [],
      onTap: () => context.push(
          movieDetailPath(
            item.movieId,
            source: DetailSource.watchlist,
          ),
          extra: {
            'title': item.movie?.title,
            'poster': item.movie?.posterPath
          }),
      onMarkAsWatched: () => _actions.markAsWatched(item),
      onAddToFavourites: () => _actions.addToFavourites(item),
      onAddToList: () => _actions.addToList(item),
      onRequestToWatch: () => _actions.requestWatch(item),
      onRemove: () => _actions.removeMovie(item),
    );
  }

  Widget _buildShowWatchlistRow(WatchlistShowEntry item) {
    void details() => context.push(
        showDetailPath(item.showId, source: DetailSource.watchlist),
        extra: {'title': item.title, 'poster': item.posterPath});
    return WatchlistMovieRow(
      isShow: true,
      watchlistItem: WatchlistMovie(
          id: 'show-${item.showId}',
          userId: '',
          movieId: item.showId,
          createdAt: item.createdAt,
          movie: WatchlistMovieDetails(
              id: item.showId,
              title: item.title,
              posterPath: item.posterPath,
              releaseDate: item.firstAirDate)),
      metadataOverride: [
        if (item.firstAirDate?.isNotEmpty == true)
          item.firstAirDate!.split('-').first,
        if (item.runtime != null && item.runtime! > 0)
          '${item.runtime} min / episode (est.)',
        if (item.numberOfSeasons != null)
          '${item.numberOfSeasons} seasons'
        else if (item.numberOfEpisodes != null)
          '${item.numberOfEpisodes} episodes',
        if (item.status?.isNotEmpty == true) item.status!,
        if (item.watched) 'Watched'
      ].join(' · '),
      isWatched: item.watched,
      onTap: details,
      onMarkAsWatched: details,
      onRemove: () => _actions.removeShow(item),
      availableProviders:
          _watchlist.showWatchProviders[item.showId] ?? const [],
      userWatchProviderIds: _watchlist.filters.servicesOnly
          ? (_watchlist.filters.providerIds ?? _watchlist.userWatchProviderIds)
          : _watchlist.userWatchProviderIds,
      userWatchProviderMatchKeys: _watchlist.filters.servicesOnly
          ? [..._watchlist.savedProviders, ..._watchlist.searchProviders]
              .where((p) => (_watchlist.filters.providerIds ??
                      _watchlist.userWatchProviderIds)
                  .contains(p.id))
              .map((p) => p.matchKey)
              .toSet()
          : _watchlist.userWatchProviderMatchKeys,
      region: context.read<AuthProvider>().dbUser?.watchProviderRegion ?? 'GB',
      isLoadingProviders:
          !_watchlist.completedEnrichment.contains('show:${item.showId}') &&
              !_watchlist.showWatchProviders.containsKey(item.showId),
      providersFailed:
          _watchlist.completedEnrichment.contains('show:${item.showId}') &&
              !_watchlist.showWatchProviders.containsKey(item.showId),
      onEditPreferences: _editPreferences,
      onRetryProviders: () => _watchlist.retryEnrichment(item),
      recommendations: _watchlist.friendsByShowId[item.showId] ?? const [],
      isLoadingFriends:
          !_watchlist.completedEnrichment.contains('show:${item.showId}') &&
              !_watchlist.friendsByShowId.containsKey(item.showId),
      friendsFailed:
          _watchlist.completedEnrichment.contains('show:${item.showId}') &&
              !_watchlist.friendsByShowId.containsKey(item.showId),
      onRetryFriends: () => _watchlist.retryEnrichment(item),
    );
  }
}
