import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/show.dart';
import '../models/watch_provider.dart';
import '../providers/auth_provider.dart';
import '../services/show_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../widgets/flixie_page.dart';

enum _ShowTab { overview, seasons, episodes, cast, similar }

enum _ShowAction { watchlist, watched, favorite }

class ShowDetailScreen extends StatefulWidget {
  const ShowDetailScreen({super.key, required this.showId});

  final String showId;

  @override
  State<ShowDetailScreen> createState() => _ShowDetailScreenState();
}

class _ShowDetailScreenState extends State<ShowDetailScreen> {
  TvShow? _show;
  List<WatchProvider> _watchProviders = [];
  Set<int> _userProviderIds = {};
  bool _isLoading = true;
  String? _error;
  bool _inWatchlist = false;
  bool _isWatched = false;
  bool _isFavorite = false;
  bool _showFullOverview = false;
  _ShowAction? _updatingAction;
  _ShowTab _selectedTab = _ShowTab.overview;
  int? _selectedSeasonNumber;

  static const _background = FlixieColors.background;
  static const _primary = FlixieColors.primary;
  static const _accent = FlixieColors.primaryTint;
  static const _card = FlixieColors.surface;
  static const _textSecondary = FlixieColors.light;
  static const _success = FlixieColors.success;
  static const _warning = FlixieColors.warning;
  static const _errorColor = FlixieColors.danger;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = int.tryParse(widget.showId);
    if (id == null || id <= 0) {
      setState(() {
        _error = 'Invalid show ID.';
        _isLoading = false;
      });
      return;
    }

    final auth = context.read<AuthProvider>();
    final user = auth.dbUser;
    final region = user?.countryAbbreviation ?? 'GB';

    try {
      final results = await Future.wait([
        ShowService.getShowById(id, userId: user?.id),
        ShowService.getShowWatchProviders(id, region).catchError(
          (_) => <WatchProvider>[],
        ),
        if (user != null)
          UserService.getUserWatchProviders(user.id)
              .catchError((_) => <WatchProvider>[])
        else
          Future.value(<WatchProvider>[]),
      ]);

      if (!mounted) return;
      final show = results[0] as TvShow;
      final providersFromEndpoint = results[1] as List<WatchProvider>;
      final userProviders = results[2] as List<WatchProvider>;
      setState(() {
        _show = show;
        _watchProviders = providersFromEndpoint.isNotEmpty
            ? providersFromEndpoint
            : show.watchProviders;
        _userProviderIds = userProviders.map((provider) => provider.id).toSet();
        _selectedSeasonNumber =
            show.seasons.isNotEmpty ? show.seasons.first.seasonNumber : 1;
        _inWatchlist = _containsShowId(user?.showWatchlist, id);
        _isWatched = _containsShowId(user?.watchedShows, id);
        _isFavorite = _containsShowId(user?.favoriteShows, id);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  bool _containsShowId(List<dynamic>? items, int showId) {
    if (items == null) return false;
    return items.any((item) {
      if (item is int) return item == showId;
      if (item is String) return int.tryParse(item) == showId;
      if (item is Map<String, dynamic>) {
        return item['showId'] == showId || item['id'] == showId;
      }
      return false;
    });
  }

  Future<void> _toggleWatchlist() async {
    final user = context.read<AuthProvider>().dbUser;
    final showId = _show?.id;
    if (user == null || showId == null) return;

    setState(() => _updatingAction = _ShowAction.watchlist);
    try {
      if (_inWatchlist) {
        await ShowService.removeFromWatchlist(user.id, showId);
      } else {
        await ShowService.addToWatchlist(user.id, showId);
      }
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _inWatchlist = !_inWatchlist;
        _updatingAction = null;
      });
      context.read<AuthProvider>().markActivityChanged();
    } catch (e) {
      if (!mounted) return;
      setState(() => _updatingAction = null);
      _showSnack('Unable to update watchlist');
    }
  }

  Future<void> _toggleFavorite() async {
    final user = context.read<AuthProvider>().dbUser;
    final showId = _show?.id;
    if (user == null || showId == null) return;

    setState(() => _updatingAction = _ShowAction.favorite);
    try {
      if (_isFavorite) {
        await ShowService.removeFromFavourites(user.id, showId);
      } else {
        await ShowService.addToFavourites(user.id, showId);
      }
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _isFavorite = !_isFavorite;
        _updatingAction = null;
      });
      context.read<AuthProvider>().markActivityChanged();
    } catch (_) {
      if (!mounted) return;
      setState(() => _updatingAction = null);
      _showSnack('Unable to update favourites');
    }
  }

  void _toggleWatched() {
    HapticFeedback.lightImpact();
    setState(() => _isWatched = !_isWatched);
    _showSnack(_isWatched ? 'Marked as watched' : 'Marked as unwatched');
  }

  Future<void> _setSeasonWatched(TvSeason season, bool watched) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    final showId = _show?.id;
    if (userId == null || showId == null) return;

    try {
      await ShowService.updateSeasonProgress(
        userId: userId,
        showId: showId,
        seasonNumber: season.seasonNumber,
        watched: watched,
        watchedAt: watched ? DateTime.now().toUtc().toIso8601String() : null,
      );
      if (!mounted) return;
      HapticFeedback.lightImpact();
      await _load();
      if (mounted) {
        _showSnack(watched
            ? 'Season ${season.seasonNumber} marked watched'
            : 'Season ${season.seasonNumber} marked unwatched');
      }
    } catch (_) {
      if (mounted) _showSnack('Unable to update season progress');
    }
  }

  Future<void> _setEpisodeWatched(TvEpisode episode, bool watched) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    final showId = _show?.id;
    if (userId == null || showId == null) return;

    try {
      await ShowService.updateEpisodeProgress(
        userId: userId,
        showId: showId,
        episodeId: episode.id,
        watched: watched,
        watchedAt: watched ? DateTime.now().toUtc().toIso8601String() : null,
      );
      if (!mounted) return;
      HapticFeedback.selectionClick();
      await _load();
      if (mounted) {
        _showSnack(
            watched ? 'Episode marked watched' : 'Episode marked unwatched');
      }
    } catch (_) {
      if (mounted) _showSnack('Unable to update episode progress');
    }
  }

  Future<void> _rateEpisode(TvEpisode episode) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    final showId = _show?.id;
    if (userId == null || showId == null) return;

    var rating = (episode.userRating ?? 8).round().clamp(1, 10);
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Rate ${episode.name}',
            style: const TextStyle(color: FlixieColors.light),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$rating/10',
                style: const TextStyle(
                  color: FlixieColors.primary,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Slider(
                min: 1,
                max: 10,
                divisions: 9,
                value: rating.toDouble(),
                label: '$rating',
                onChanged: (value) =>
                    setDialogState(() => rating = value.round()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(rating),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;

    try {
      await ShowService.updateEpisodeProgress(
        userId: userId,
        showId: showId,
        episodeId: episode.id,
        watched: true,
        watchedAt: DateTime.now().toUtc().toIso8601String(),
        rating: selected,
      );
      if (!mounted) return;
      HapticFeedback.selectionClick();
      await _load();
      if (mounted) _showSnack('Episode rating saved');
    } catch (_) {
      if (mounted) _showSnack('Unable to save episode rating');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return FlixiePageScaffold(
      backgroundColor: _background,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _primary),
            )
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final show = _show!;
    return RefreshIndicator(
      color: _primary,
      backgroundColor: _card,
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHero(context, show)),
          SliverToBoxAdapter(child: _buildProviderSection(show)),
          SliverToBoxAdapter(child: _buildActions()),
          SliverToBoxAdapter(child: _buildProgressSection(show)),
          SliverToBoxAdapter(child: _buildFriendSummary(show)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _ShowTabsHeader(
              selected: _selectedTab,
              onSelected: (tab) => setState(() => _selectedTab = tab),
            ),
          ),
          SliverToBoxAdapter(child: _buildSelectedTab(show)),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, TvShow show) {
    final backdrop = _tmdbImage(show.backdropPath, 'w780');
    final years = _yearRange(show);
    final meta = <String>[
      if (years.isNotEmpty) years,
      if ((show.numberOfSeasons ?? show.seasons.length) > 0)
        '${show.numberOfSeasons ?? show.seasons.length} Seasons',
      if (show.resolvedEpisodeCount > 0)
        '${show.resolvedEpisodeCount} Episodes',
    ];

    return SizedBox(
      height: 560,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (backdrop != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 22,
              left: 0,
              right: 0,
              child: CachedNetworkImage(
                imageUrl: backdrop,
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
              ),
            )
          else
            Container(color: _card),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).padding.top + 104,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _background.withValues(alpha: 0.92),
                      _background.withValues(alpha: 0.38),
                      _background.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.42, 0.72, 1.0],
                colors: [
                  _background.withValues(alpha: 0.0),
                  _background.withValues(alpha: 0.08),
                  _background.withValues(alpha: 0.88),
                  _background,
                ],
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 14,
            right: 14,
            child: Row(
              children: [
                _CircleIconButton(
                  icon: Icons.arrow_back_rounded,
                  onPressed: () => context.pop(),
                  tooltip: 'Back',
                ),
                const Spacer(),
                _CircleIconButton(
                  icon: _isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  onPressed: _toggleFavorite,
                  tooltip: 'Favourite',
                  color: _isFavorite ? _errorColor : Colors.white,
                ),
                const SizedBox(width: 10),
                _CircleIconButton(
                  icon: Icons.ios_share_rounded,
                  onPressed: () => _showSnack('Share coming soon'),
                  tooltip: 'Share',
                ),
              ],
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            bottom: 26,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  show.name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    height: 0.98,
                  ),
                ),
                const SizedBox(height: 12),
                if (meta.isNotEmpty)
                  Text(
                    meta.join('  •  '),
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if ((show.status ?? '').isNotEmpty) ...[
                  const SizedBox(height: 9),
                  _StatusPill(label: show.status!),
                ],
                const SizedBox(height: 14),
                _RatingsStrip(show: show),
                if (show.genres.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: show.genres
                        .take(5)
                        .map((genre) => _GenreChip(label: genre))
                        .toList(),
                  ),
                ],
                if ((show.overview ?? '').isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    show.overview!,
                    maxLines: _showFullOverview ? null : 3,
                    overflow: _showFullOverview ? null : TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(
                      () => _showFullOverview = !_showFullOverview,
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 30),
                    ),
                    child: Text(_showFullOverview ? 'Show less' : 'Show more'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderSection(TvShow show) {
    final sorted = [..._watchProviders]..sort((a, b) {
        final aMatch = _userProviderIds.contains(a.id);
        final bMatch = _userProviderIds.contains(b.id);
        if (aMatch != bMatch) return aMatch ? -1 : 1;
        return a.displayPriority.compareTo(b.displayPriority);
      });
    final providers = sorted.take(8).toList();

    return _SectionShell(
      title: 'Watch On Your Providers',
      trailing: providers.length < sorted.length ? 'All providers' : null,
      child: providers.isEmpty
          ? const Text(
              'No provider availability yet',
              style:
                  TextStyle(color: _textSecondary, fontWeight: FontWeight.w700),
            )
          : SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: providers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final provider = providers[index];
                  final isMine = _userProviderIds.contains(provider.id);
                  return _ProviderTile(provider: provider, isMine: isMine);
                },
              ),
            ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        decoration: _cardDecoration(),
        child: Row(
          children: [
            _ActionButton(
              icon: _inWatchlist ? Icons.bookmark_rounded : Icons.add_rounded,
              label: 'Watchlist',
              active: _inWatchlist,
              busy: _updatingAction == _ShowAction.watchlist,
              onTap: _toggleWatchlist,
            ),
            _ActionButton(
              icon: Icons.check_circle_outline_rounded,
              label: 'Watched',
              active: _isWatched,
              busy: _updatingAction == _ShowAction.watched,
              onTap: _toggleWatched,
            ),
            _ActionButton(
              icon: _isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              label: 'Favourite',
              active: _isFavorite,
              busy: _updatingAction == _ShowAction.favorite,
              onTap: _toggleFavorite,
            ),
            _ActionButton(
              icon: Icons.star_border_rounded,
              label: 'Rate',
              onTap: () => _showSnack('Episode and show rating coming soon'),
            ),
            _ActionButton(
              icon: Icons.group_add_outlined,
              label: 'Recommend',
              onTap: () => _showSnack('Recommendations coming soon'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection(TvShow show) {
    final total = show.resolvedEpisodeCount;
    final watched = _watchedEpisodeCount(show).clamp(0, total == 0 ? 0 : total);
    final percent = total == 0 ? 0.0 : watched / total;
    final resume = _resumeEpisode(show);
    final seasonLabel = resume == null
        ? 'Ready to start'
        : 'Season ${resume.seasonNumber} Episode ${resume.episodeNumber}';

    return _SectionShell(
      title: 'Your Progress',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      seasonLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      total == 0
                          ? 'Episode progress is not available yet'
                          : '$watched / $total Episodes Watched',
                      style: const TextStyle(
                        color: _textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(percent * 100).round()}%',
                style: const TextStyle(
                  color: _success,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : percent,
              minHeight: 9,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation(_success),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: resume == null
                  ? null
                  : () => setState(() {
                        _selectedSeasonNumber = resume.seasonNumber;
                        _selectedTab = _ShowTab.episodes;
                      }),
              icon: const Icon(Icons.play_arrow_rounded),
              label:
                  Text(resume == null ? 'No Episode Data' : 'Resume Episode'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendSummary(TvShow show) {
    final summary = show.friendSummary;
    if (summary == null && show.friendActivity.isEmpty) {
      return const SizedBox.shrink();
    }
    return _SectionShell(
      title: 'Friend Summary',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _MiniMetric(
              label: 'Friends Watched', value: '${summary?.watchedCount ?? 0}'),
          _MiniMetric(
            label: 'Average Rating',
            value: summary?.averageRating == null
                ? '—'
                : summary!.averageRating!.toStringAsFixed(1),
          ),
          _MiniMetric(
              label: 'Following', value: '${summary?.followingCount ?? 0}'),
          _MiniMetric(
            label: 'Highest',
            value: summary?.highestRating == null
                ? '—'
                : '${summary!.highestName ?? 'Friend'} ${summary.highestRating!.toStringAsFixed(0)}/10',
          ),
          _MiniMetric(
            label: 'Lowest',
            value: summary?.lowestRating == null
                ? '—'
                : '${summary!.lowestName ?? 'Friend'} ${summary.lowestRating!.toStringAsFixed(0)}/10',
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedTab(TvShow show) {
    return switch (_selectedTab) {
      _ShowTab.overview => _buildOverviewTab(show),
      _ShowTab.seasons => _buildSeasonsTab(show),
      _ShowTab.episodes => _buildEpisodesTab(show),
      _ShowTab.cast => _buildCastTab(show),
      _ShowTab.similar => _buildSimilarTab(show),
    };
  }

  Widget _buildOverviewTab(TvShow show) {
    final backdrop = _tmdbImage(show.backdropPath, 'w300');
    final fallbackPoster = _tmdbImage(show.posterPath, 'w342');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: _cardDecoration(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 150,
                    height: 92,
                    child: (backdrop ?? fallbackPoster) == null
                        ? const ColoredBox(color: _background)
                        : CachedNetworkImage(
                            imageUrl: backdrop ?? fallbackPoster!,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Wrap(
                    runSpacing: 12,
                    children: [
                      _InfoCell(label: 'Status', value: show.status),
                      _InfoCell(
                          label: 'First Air Date',
                          value: _dateLabel(show.firstAirDate)),
                      _InfoCell(
                          label: 'Last Air Date',
                          value: _dateLabel(show.lastAirDate)),
                      _InfoCell(
                          label: 'Language',
                          value: show.originalLanguage?.toUpperCase()),
                      _InfoCell(
                          label: 'Country',
                          value: show.originCountry.join(', ')),
                      _InfoCell(
                          label: 'Episodes',
                          value: '${show.resolvedEpisodeCount}'),
                      _InfoCell(
                        label: 'Seasons',
                        value: '${show.numberOfSeasons ?? show.seasons.length}',
                      ),
                      _InfoCell(
                          label: 'Network', value: show.networks.join(', ')),
                      _InfoCell(
                          label: 'Created By',
                          value: show.createdBy.join(', ')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _RatingsGrid(show: show),
          const SizedBox(height: 18),
          _FriendActivityList(show: show),
          const SizedBox(height: 18),
          _ReviewsPlaceholder(),
        ],
      ),
    );
  }

  Widget _buildSeasonsTab(TvShow show) {
    if (show.seasons.isEmpty) {
      return const _EmptyTab(label: 'No seasons available yet');
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 0, 0),
      child: SizedBox(
        height: 214,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: show.seasons.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final season = show.seasons[index];
            final selected = season.seasonNumber == _selectedSeasonNumber;
            return _SeasonCard(
              season: season,
              selected: selected,
              onMarkWatched: () => _setSeasonWatched(season, true),
              onMarkUnwatched: () => _setSeasonWatched(season, false),
              onTap: () => setState(() {
                _selectedSeasonNumber = season.seasonNumber;
                _selectedTab = _ShowTab.episodes;
              }),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEpisodesTab(TvShow show) {
    final seasonNumber = _selectedSeasonNumber ??
        (show.seasons.isNotEmpty ? show.seasons.first.seasonNumber : 1);
    final selectedSeason = show.seasons
        .where((season) => season.seasonNumber == seasonNumber)
        .firstOrNull;
    final episodes = show.episodesForSeason(seasonNumber);
    if (episodes.isEmpty) {
      return const _EmptyTab(label: 'No episodes available yet');
    }
    final seasonComplete = selectedSeason != null &&
        selectedSeason.resolvedEpisodeCount > 0 &&
        selectedSeason.watchedEpisodeCount >=
            selectedSeason.resolvedEpisodeCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButton<int>(
                  value: seasonNumber,
                  dropdownColor: _card,
                  iconEnabledColor: _primary,
                  isExpanded: true,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                  items: show.seasons
                      .map((season) => DropdownMenuItem(
                            value: season.seasonNumber,
                            child: Text('Season ${season.seasonNumber}'),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedSeasonNumber = value),
                ),
              ),
              const SizedBox(width: 10),
              if (selectedSeason != null)
                OutlinedButton.icon(
                  onPressed: () =>
                      _setSeasonWatched(selectedSeason, !seasonComplete),
                  icon: Icon(
                    seasonComplete
                        ? Icons.check_circle
                        : Icons.check_circle_outline,
                    size: 18,
                  ),
                  label: Text(seasonComplete ? 'Unwatch season' : 'Watch all'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...episodes.map((episode) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _EpisodeCard(
                  episode: episode,
                  onToggleWatched: () =>
                      _setEpisodeWatched(episode, !episode.watched),
                  onRate: () => _rateEpisode(episode),
                  onReview: () => _showSnack('Episode reviews coming soon'),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildCastTab(TvShow show) {
    final creators = show.createdBy;
    final directors = show.crew
        .where((crew) => (crew.role ?? '').toLowerCase().contains('director'))
        .map((crew) => crew.name)
        .toSet()
        .toList();
    final writers = show.crew
        .where((crew) => (crew.role ?? '').toLowerCase().contains('writer'))
        .map((crew) => crew.name)
        .toSet()
        .toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (show.cast.isNotEmpty)
            SizedBox(
              height: 188,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: show.cast.take(12).length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) =>
                    _CastTile(credit: show.cast[index]),
              ),
            )
          else
            const _EmptyTab(label: 'No cast data available yet'),
          const SizedBox(height: 16),
          _CrewLine(label: 'Created By', values: creators),
          _CrewLine(label: 'Directors', values: directors),
          _CrewLine(label: 'Writers', values: writers),
        ],
      ),
    );
  }

  Widget _buildSimilarTab(TvShow show) {
    if (show.similarShows.isEmpty) {
      return const _EmptyTab(label: 'No similar shows yet');
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 0, 0),
      child: SizedBox(
        height: 240,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: show.similarShows.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final similar = show.similarShows[index];
            return _SimilarShowCard(
              show: similar,
              onTap: () => context.push('/shows/${similar.id}'),
            );
          },
        ),
      ),
    );
  }

  int _watchedEpisodeCount(TvShow show) {
    if ((show.watchedEpisodeCount ?? 0) > 0) return show.watchedEpisodeCount!;
    final watchedFromEpisodes =
        show.episodes.where((episode) => episode.watched).length;
    if (watchedFromEpisodes > 0) return watchedFromEpisodes;
    return show.seasons.fold<int>(
      0,
      (total, season) => total + season.watchedEpisodeCount,
    );
  }

  TvEpisode? _resumeEpisode(TvShow show) {
    final allEpisodes = show.seasons
        .expand((season) => season.episodes)
        .followedBy(show.episodes)
        .toList()
      ..sort((a, b) {
        final seasonCompare = a.seasonNumber.compareTo(b.seasonNumber);
        if (seasonCompare != 0) return seasonCompare;
        return a.episodeNumber.compareTo(b.episodeNumber);
      });
    if (allEpisodes.isEmpty) return null;
    return allEpisodes.firstWhere((episode) => !episode.watched,
        orElse: () => allEpisodes.last);
  }

  String _yearRange(TvShow show) {
    final first = _year(show.firstAirDate);
    final last = _year(show.lastAirDate);
    if (first == null) return '';
    if (last == null || last == first) return '$first';
    return '$first - $last';
  }
}

String? _tmdbImage(String? path, String size) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http')) return path;
  return 'https://image.tmdb.org/t/p/$size$path';
}

int? _year(String? date) {
  if (date == null || date.length < 4) return null;
  return int.tryParse(date.substring(0, 4));
}

String _dateLabel(String? date) {
  if (date == null || date.isEmpty) return '—';
  final parsed = DateTime.tryParse(date);
  if (parsed == null) return date;
  const months = [
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
    'Dec'
  ];
  return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
}

String? _scoreLabel(double? value) => value?.toStringAsFixed(1);

BoxDecoration _cardDecoration({Color borderColor = Colors.transparent}) {
  return BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        FlixieColors.cardGradientTop,
        FlixieColors.cardGradientBottom,
      ],
    ),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(
      color: borderColor == Colors.transparent
          ? FlixieColors.tabBarBorder
          : borderColor,
    ),
  );
}

class _ShowTabsHeader extends SliverPersistentHeaderDelegate {
  const _ShowTabsHeader({required this.selected, required this.onSelected});

  final _ShowTab selected;
  final ValueChanged<_ShowTab> onSelected;

  @override
  double get minExtent => 58;

  @override
  double get maxExtent => 58;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: _ShowDetailScreenState._background.withValues(alpha: 0.98),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _ShowTab.values.map((tab) {
          final active = selected == tab;
          return Padding(
            padding: const EdgeInsets.only(right: 22),
            child: InkWell(
              onTap: () => onSelected(tab),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    switch (tab) {
                      _ShowTab.overview => 'OVERVIEW',
                      _ShowTab.seasons => 'SEASONS',
                      _ShowTab.episodes => 'EPISODES',
                      _ShowTab.cast => 'CAST & CREW',
                      _ShowTab.similar => 'SIMILAR',
                    },
                    style: TextStyle(
                      color: active
                          ? _ShowDetailScreenState._accent
                          : _ShowDetailScreenState._textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 2,
                    width: active ? 52 : 0,
                    color: _ShowDetailScreenState._accent,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ShowTabsHeader oldDelegate) {
    return selected != oldDelegate.selected;
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.color = Colors.white,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon, color: color, size: 22),
          ),
        ),
      ),
    );
  }
}

class _RatingsStrip extends StatelessWidget {
  const _RatingsStrip({required this.show});

  final TvShow show;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'Flixie',
        _scoreLabel(show.flixieScore ?? show.voteAverage),
        Icons.star_rounded,
        _ShowDetailScreenState._accent
      ),
      (
        'IMDb',
        show.imdbRatingLabel ?? _scoreLabel(show.imdbRating),
        Icons.movie_creation_rounded,
        _ShowDetailScreenState._warning
      ),
      (
        'TMDB',
        _scoreLabel(show.tmdbRating ?? show.voteAverage),
        Icons.star_rounded,
        _ShowDetailScreenState._success
      ),
      (
        'Friends',
        show.friendRecommendPercent == null
            ? null
            : '${show.friendRecommendPercent}%',
        Icons.favorite_rounded,
        _ShowDetailScreenState._errorColor
      ),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: items.where((item) => item.$2 != null).map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.$3, color: item.$4, size: 18),
            const SizedBox(width: 5),
            Text(
              '${item.$2} ${item.$1}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _ShowDetailScreenState._success.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
            color: _ShowDetailScreenState._success.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _ShowDetailScreenState._success,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell(
      {required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      color: _ShowDetailScreenState._accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                if (trailing != null)
                  Text(
                    trailing!,
                    style: const TextStyle(
                      color: _ShowDetailScreenState._accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({required this.provider, required this.isMine});

  final WatchProvider provider;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final label = provider.isRental
        ? 'Rent'
        : provider.hasExplicitAvailabilityType
            ? 'Included'
            : 'Subscription';
    return Container(
      width: 112,
      padding: const EdgeInsets.all(10),
      decoration: _cardDecoration(
        borderColor: isMine
            ? _ShowDetailScreenState._success
            : Colors.white.withValues(alpha: 0.08),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CachedNetworkImage(
            imageUrl: provider.logoUrl,
            width: 42,
            height: 42,
            fit: BoxFit.cover,
          ),
          const SizedBox(height: 8),
          Text(
            provider.providerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
          const SizedBox(height: 3),
          Text(
            isMine ? 'You have this' : label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isMine
                  ? _ShowDetailScreenState._success
                  : _ShowDetailScreenState._textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  icon,
                  color: active
                      ? _ShowDetailScreenState._accent
                      : _ShowDetailScreenState._textSecondary,
                  size: 22,
                ),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active
                      ? Colors.white
                      : _ShowDetailScreenState._textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
                color: _ShowDetailScreenState._textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  const _InfoCell({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: _ShowDetailScreenState._textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            (value == null || value!.isEmpty) ? '—' : value!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingsGrid extends StatelessWidget {
  const _RatingsGrid({required this.show});

  final TvShow show;

  @override
  Widget build(BuildContext context) {
    final ratings = [
      ('IMDb', show.imdbRatingLabel ?? _ratingLabel(show.imdbRating)),
      ('TMDB', _ratingLabel(show.tmdbRating ?? show.voteAverage)),
      ('Rotten', show.rottenTomatoRatingLabel),
      ('Metascore', show.metascoreRatingLabel),
      ('Flixie', _ratingLabel(show.flixieScore)),
      ('Friends', _ratingLabel(show.friendRating)),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ratings.map((rating) {
        return SizedBox(
          width: 112,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: _cardDecoration(),
            child: Column(
              children: [
                Text(
                  rating.$1,
                  style: const TextStyle(
                    color: _ShowDetailScreenState._accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  rating.$2 ?? '—',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  static String? _ratingLabel(double? value) {
    return value == null ? null : '${value.toStringAsFixed(1)}/10';
  }
}

class _SeasonCard extends StatelessWidget {
  const _SeasonCard({
    required this.season,
    required this.selected,
    required this.onTap,
    required this.onMarkWatched,
    required this.onMarkUnwatched,
  });

  final TvSeason season;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onMarkWatched;
  final VoidCallback onMarkUnwatched;

  @override
  Widget build(BuildContext context) {
    final poster = _tmdbImage(season.posterPath, 'w342');
    final total = season.resolvedEpisodeCount;
    final watched = total > 0 && season.watchedEpisodeCount >= total;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 124,
        decoration: _cardDecoration(
          borderColor:
              selected ? _ShowDetailScreenState._accent : Colors.transparent,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (poster != null)
                CachedNetworkImage(imageUrl: poster, fit: BoxFit.cover)
              else
                const ColoredBox(color: _ShowDetailScreenState._card),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.86)
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'S${season.seasonNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '$total Episodes',
                      style: const TextStyle(
                          color: _ShowDetailScreenState._textSecondary,
                          fontSize: 12),
                    ),
                    Text(
                      '${season.watchedEpisodeCount}/$total Watched',
                      style: const TextStyle(
                          color: _ShowDetailScreenState._success, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Positioned(
                  right: 8,
                  bottom: 8,
                  child: Icon(Icons.check_circle,
                      color: _ShowDetailScreenState._accent),
                ),
              Positioned(
                top: 7,
                right: 7,
                child: Tooltip(
                  message:
                      watched ? 'Mark season unwatched' : 'Mark season watched',
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.46),
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: watched ? onMarkUnwatched : onMarkWatched,
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: Icon(
                          watched
                              ? Icons.check_circle
                              : Icons.check_circle_outline,
                          color: watched
                              ? _ShowDetailScreenState._success
                              : Colors.white,
                          size: 21,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({
    required this.episode,
    required this.onToggleWatched,
    required this.onRate,
    required this.onReview,
  });

  final TvEpisode episode;
  final VoidCallback onToggleWatched;
  final VoidCallback onRate;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final still = _tmdbImage(episode.stillPath, 'w342');
    return Container(
      decoration: _cardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 122,
                    height: 78,
                    child: still == null
                        ? const ColoredBox(
                            color: _ShowDetailScreenState._background)
                        : CachedNetworkImage(
                            imageUrl: still, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${episode.episodeNumber}. ${episode.name}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        [
                          _dateLabel(episode.airDate),
                          if (episode.runtime != null) '${episode.runtime}m',
                        ].where((item) => item != '—').join('  •  '),
                        style: const TextStyle(
                            color: _ShowDetailScreenState._textSecondary,
                            fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        episode.overview ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _ShowDetailScreenState._textSecondary,
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onToggleWatched,
                    icon: Icon(episode.watched
                        ? Icons.check_circle
                        : Icons.check_circle_outline),
                    label: Text(
                        episode.watched ? 'Mark Unwatched' : 'Mark Watched'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Rate episode',
                  onPressed: onRate,
                  icon: const Icon(Icons.star_border_rounded),
                ),
                IconButton(
                  tooltip: 'Add review',
                  onPressed: onReview,
                  icon: const Icon(Icons.rate_review_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CastTile extends StatelessWidget {
  const _CastTile({required this.credit});

  final TvShowCredit credit;

  @override
  Widget build(BuildContext context) {
    final image = _tmdbImage(credit.profilePath, 'w185');
    return SizedBox(
      width: 104,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 104,
              height: 128,
              child: image == null
                  ? const ColoredBox(color: _ShowDetailScreenState._card)
                  : CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            credit.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
          ),
          Text(
            credit.character ?? credit.role ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: _ShowDetailScreenState._textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _CrewLine extends StatelessWidget {
  const _CrewLine({required this.label, required this.values});

  final String label;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _InfoCell(label: label, value: values.join(', ')),
    );
  }
}

class _SimilarShowCard extends StatelessWidget {
  const _SimilarShowCard({required this.show, required this.onTap});

  final TvShow show;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backdrop = _tmdbImage(show.backdropPath, 'w300');
    final fallbackPoster = _tmdbImage(show.posterPath, 'w342');
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 180,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 180,
                height: 102,
                child: (backdrop ?? fallbackPoster) == null
                    ? const ColoredBox(color: _ShowDetailScreenState._card)
                    : CachedNetworkImage(
                        imageUrl: backdrop ?? fallbackPoster!,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              show.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w900),
            ),
            Text(
              '${show.voteAverage?.toStringAsFixed(1) ?? '—'} • ${show.numberOfSeasons ?? show.seasons.length} Seasons',
              style: const TextStyle(
                  color: _ShowDetailScreenState._textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendActivityList extends StatelessWidget {
  const _FriendActivityList({required this.show});

  final TvShow show;

  @override
  Widget build(BuildContext context) {
    if (show.friendActivity.isEmpty) return const SizedBox.shrink();
    return _SectionShell(
      title: 'Friend Activity',
      child: Column(
        children: show.friendActivity.take(5).map((activity) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor:
                  _ShowDetailScreenState._accent.withValues(alpha: 0.24),
              child: Text(activity.userName.characters.first.toUpperCase()),
            ),
            title: Text(
              '${activity.userName} ${activity.details ?? activity.action}',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800),
            ),
            subtitle: activity.rating == null
                ? null
                : Text(
                    '${activity.rating!.toStringAsFixed(0)}/10',
                    style: const TextStyle(
                        color: _ShowDetailScreenState._textSecondary),
                  ),
          );
        }).toList(),
      ),
    );
  }
}

class _ReviewsPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const _SectionShell(
      title: 'Reviews',
      child: Text(
        'User reviews, friend reviews and critic ratings will appear here when available.',
        style: TextStyle(
            color: _ShowDetailScreenState._textSecondary, height: 1.35),
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
              color: _ShowDetailScreenState._textSecondary,
              fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: FlixieColors.danger, size: 44),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: FlixieColors.light),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
