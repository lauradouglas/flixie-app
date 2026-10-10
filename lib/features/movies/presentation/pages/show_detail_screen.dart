import '../widgets/show_detail_metadata.dart';
import '../show_detail_action_flow.dart';
import '../controllers/show_detail_controller.dart';
import '../widgets/show_friends_section.dart';
import '../widgets/show_episode_sheet.dart';
import '../widgets/show_episodes_section.dart';
import '../widgets/show_watch_providers_section.dart';
import '../widgets/show_detail_hero.dart';
import 'package:flixie_app/features/movies/presentation/widgets/show_detail_images.dart';
import 'package:flixie_app/core/widgets/flixie_back_button.dart';
import 'package:flixie_app/core/widgets/flixie_section_header.dart';
import 'package:flixie_app/features/movies/presentation/widgets/media_detail_action.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/features/settings/data/episode_spoiler_preference.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/show.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/movies/presentation/widgets/media_reviews_section.dart';
import 'package:flixie_app/features/movies/presentation/widgets/media_lists_section.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';
import 'package:flixie_app/core/utils/skeleton.dart';

enum _ShowDetailTab { overview, episodes, reviews, activity }

class ShowDetailScreen extends StatefulWidget {
  const ShowDetailScreen({
    super.key,
    required this.showId,
    this.source = DetailSource.unknown,
    this.initialTitle,
    this.initialPoster,
  });

  final String showId;
  final DetailSource source;
  final String? initialTitle;
  final String? initialPoster;

  @override
  State<ShowDetailScreen> createState() => _ShowDetailScreenState();
}

class _ShowDetailScreenState extends State<ShowDetailScreen> {
  late final ShowDetailController _data;
  ShowDetailActionFlow get _flow =>
      ShowDetailActionFlow(context: context, data: _data);
  bool _hideEpisodeSpoilers = true;
  bool _savingSpoilerPreference = false;

  bool _showFullOverview = false;
  bool _showAllSeasons = false;
  final _tabContentKey = GlobalKey();
  _ShowDetailTab _selectedTab = _ShowDetailTab.overview;

  static const _primary = FlixieColors.primary;

  @override
  void initState() {
    super.initState();
    _data = ShowDetailController(auth: context.read<AuthProvider>())
      ..addListener(_dataChanged);
    EpisodeSpoilerPreference.instance.addListener(_spoilerPreferenceChanged);
    final id = int.tryParse(widget.showId);
    if (id != null && id > 0) {
      context.read<AnalyticsController?>()?.contentOpened(
            contentType: 'show',
            contentId: id,
            source: widget.source.value,
          );
    }
    _restoreSpoilerPreference();
  }

  void _dataChanged() {
    if (mounted) setState(() {});
  }

  void _spoilerPreferenceChanged() {
    if (!mounted) return;
    setState(() {
      _hideEpisodeSpoilers = EpisodeSpoilerPreference.instance.hide;
      _savingSpoilerPreference = EpisodeSpoilerPreference.instance.saving;
    });
  }

  @override
  void dispose() {
    EpisodeSpoilerPreference.instance.removeListener(_spoilerPreferenceChanged);
    _data.removeListener(_dataChanged);
    _data.dispose();
    super.dispose();
  }

  Future<void> _restoreSpoilerPreference() async {
    try {
      if (!EpisodeSpoilerPreference.instance.loaded) {
        await EpisodeSpoilerPreference.instance.load();
      }
      _spoilerPreferenceChanged();
    } catch (_) {
      // Keep spoiler protection on when storage is unavailable.
    }
    if (mounted) await _load();
  }

  Future<void> _setHideEpisodeSpoilers(bool value) async {
    try {
      await EpisodeSpoilerPreference.instance.setHidden(value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
            type: FlixieToastType.error,
            content: const Text(
                'Couldn’t save your spoiler preference. Please try again.')));
      }
    }
  }

  @override
  void didUpdateWidget(covariant ShowDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showId != widget.showId) {
      _showFullOverview = false;
      _showAllSeasons = false;
      _data.load(widget.showId);
    }
  }

  Future<void> _load() => _data.load(widget.showId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: !_data.isLoading && _data.error != null
          ? AppBar(leading: const FlixieBackButton())
          : null,
      body: _data.isLoading
          ? widget.initialTitle != null
              ? MediaDetailPreview(
                  title: widget.initialTitle!, poster: widget.initialPoster)
              : const SafeArea(child: MediaDetailScreenSkeleton())
          : _data.error != null
              ? _ErrorState(message: _data.error!, onRetry: _load)
              : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final show = _data.show!;
    return RefreshIndicator(
      color: _primary,
      onRefresh: _load,
      child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildSliverAppBar(context, show),
              if (_data.detailErrors.isNotEmpty)
                SliverToBoxAdapter(
                    child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    const Expanded(child: Text('Some details couldn’t load.')),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ]),
                )),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildActions(),
                      const SizedBox(height: 18),
                      if (TvShowEpisodeProgress(show).hasStarted) ...[
                        _buildEpisodeProgressBanner(show),
                        const SizedBox(height: 18),
                      ],
                      _buildProviderSection(show),
                      const SizedBox(height: 18),
                      if (!TvShowEpisodeProgress(show).hasStarted) ...[
                        _buildEpisodeProgressBanner(show),
                        const SizedBox(height: 18),
                      ],
                    ],
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _ShowTabsHeaderDelegate(
                  selected: _selectedTab,
                  onSelected: (tab) => setState(() => _selectedTab = tab),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  key: _tabContentKey,
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
                  child: _buildSelectedTab(context, show),
                ),
              ),
            ],
          )),
    );
  }

  Widget _buildSelectedTab(BuildContext context, TvShow show) {
    switch (_selectedTab) {
      case _ShowDetailTab.overview:
        final sections = [
          _buildSynopsis(context, show),
          _buildFriendSummary(show),
          _buildSeasonOverview(show),
          _buildCastSection(context, show),
          _buildSimilarSection(context, show),
          _buildShowInfoSection(context, show),
        ]
            .where((child) => !(child is SizedBox &&
                child.child == null &&
                child.height == 0))
            .toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var index = 0; index < sections.length; index++) ...[
            if (index > 0) _sectionGap(),
            sections[index],
          ],
        ]);
      case _ShowDetailTab.episodes:
        return _buildSeasonsAndEpisodesSection(show);
      case _ShowDetailTab.reviews:
        return _buildReviewsTab();
      case _ShowDetailTab.activity:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildProgressSection(show),
          const SizedBox(height: 24),
          _buildListsSection(context),
        ]);
    }
  }

  Widget _sectionGap() => const SizedBox(height: 24);

  Widget _buildReviewsTab() => MediaReviewsSection(
        reviews: _data.reviews,
        currentUserId: context.read<AuthProvider>().dbUser?.id,
        onWriteReview: _flow.showWriteReviewSheet,
        loading: _data.reviewsLoading,
        failed: _data.reviewsFailed,
        onRetry: _data.reloadReviews,
      );

  Widget _buildSliverAppBar(BuildContext context, TvShow show) =>
      ShowDetailHero(show: show);

  Widget _buildSynopsis(BuildContext context, TvShow show) {
    final text = show.overview;
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    final sentenceEnd = RegExp(r'[.!?](?:\s|$)').firstMatch(text);
    final preview =
        sentenceEnd == null ? text : text.substring(0, sentenceEnd.start + 1);
    final showToggle = preview.length < text.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildSectionHeader(context, 'About the show'),
      const SizedBox(height: 10),
      Text(_showFullOverview ? text : preview,
          style: TextStyle(
              color: context.colors.light, fontSize: 14, height: 1.7)),
      if (showToggle)
        TextButton(
          onPressed: () =>
              setState(() => _showFullOverview = !_showFullOverview),
          style: TextButton.styleFrom(
              foregroundColor: context.colors.primaryText,
              padding: EdgeInsets.zero,
              minimumSize: const Size(48, 44)),
          child: Text(_showFullOverview ? 'Read less' : 'Read more'),
        ),
    ]);
  }

  Widget _buildSectionHeader(BuildContext context, String title) =>
      FlixieSectionHeader(title: title);

  BoxDecoration _movieCardDecoration() {
    return BoxDecoration(
      color: context.colors.surface.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
    );
  }

  Widget _buildShowInfoSection(BuildContext context, TvShow show) =>
      ShowInfoSection(show: show, credits: _data.crew);

  Widget _buildCastSection(BuildContext context, TvShow show) =>
      ShowCastSection(show: show, credits: _data.cast);

  Widget _buildSimilarSection(BuildContext context, TvShow show) =>
      ShowSimilarSection(show: show);

  Widget _episodeLoadingState() {
    if (_data.detailsLoading) {
      return const ContentPlaceholder(
          label: 'Loading episodes and progress', rows: 2);
    }
    return Row(children: [
      const Expanded(child: Text('Episodes and progress couldn’t load.')),
      TextButton(
          onPressed: () => _data.retrySection('episodes'),
          child: const Text('Retry')),
    ]);
  }

  Widget _buildSeasonsAndEpisodesSection(TvShow show) => ShowEpisodesSection(
      show: show,
      selectedSeason: _data.selectedSeasonNumber,
      updatingSeasons: _data.updatingSeasonNumbers,
      updatingEpisodes: _data.updatingEpisodeIds,
      hideSpoilers: _hideEpisodeSpoilers,
      savingSpoilers: _savingSpoilerPreference,
      loading: _data.detailsLoading,
      loaded: _data.loadedDetails.contains('episodes'),
      failed: _data.detailErrors.contains('episodes'),
      onRetry: () => _data.retrySection('episodes'),
      onSeasonSelected: (season) =>
          setState(() => _data.selectedSeasonNumber = season),
      onSpoilersChanged: _setHideEpisodeSpoilers,
      onSeasonWatched: _flow.setSeasonWatched,
      onEpisodeWatched: _flow.setEpisodeWatched,
      onOpenEpisode: _showEpisodeSheet);

  Widget _buildEpisodeProgressBanner(TvShow show) {
    if (!_data.loadedDetails.contains('episodes') &&
        (_data.detailsLoading || _data.detailErrors.contains('episodes'))) {
      return _episodeLoadingState();
    }
    final progress = TvShowEpisodeProgress(show);
    final next = progress.nextReleased;
    final episode = next ?? progress.nextScheduled;
    final hidden = _hideEpisodeSpoilers && episode != null && !episode.watched;
    final busy =
        episode != null && _data.updatingEpisodeIds.contains(episode.id);
    final seasonEpisodes = progress.releasedEpisodes
        .where((item) => next == null || item.seasonNumber == next.seasonNumber)
        .toList();
    final watched = seasonEpisodes.where((item) => item.watched).length;
    final total = seasonEpisodes.length;
    final lavender = Theme.of(context).brightness == Brightness.light
        ? context.colors.primaryText
        : const Color(0xFFC7B5FF);
    final peach = context.colors.tertiary;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.light
              ? context.colors.surfaceElevated
              : const Color(0xFF211738),
          borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
              progress.hasNewEpisode
                  ? Icons.auto_awesome_rounded
                  : progress.isCaughtUp
                      ? Icons.task_alt_rounded
                      : Icons.local_activity_outlined,
              color: peach,
              size: 22),
          const SizedBox(width: 10),
          Expanded(
              child: Text(progress.nextLabel,
                  style: TextStyle(
                      color: context.colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700))),
        ]),
        if (episode != null) ...[
          const SizedBox(height: 10),
          InkWell(
              onTap: () => _showEpisodeSheet(episode),
              borderRadius: BorderRadius.circular(12),
              child: Row(children: [
                SizedBox(
                    width: 48,
                    height: 48,
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: hidden
                            ? ColoredBox(
                                color: context.colors.surface,
                                child: Icon(Icons.visibility_off_outlined,
                                    color: lavender, size: 22))
                            : EpisodeStill(path: episode.stillPath))),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          'Season ${episode.seasonNumber} · Episode ${episode.episodeNumber}',
                          style: TextStyle(
                              color: context.colors.white,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(hidden ? 'Spoilers tucked away' : episode.name,
                          style: TextStyle(color: context.colors.light)),
                      if (episode.runtime != null)
                        Text('${episode.runtime} min',
                            style: TextStyle(color: context.colors.light)),
                      if (next == null)
                        Text('Expected ${_dateLabel(episode.airDate)}',
                            style: TextStyle(color: context.colors.light)),
                    ])),
              ])),
        ],
        const SizedBox(height: 10),
        Text(
            next == null
                ? '$watched of $total episodes watched'
                : '$watched of $total watched this season',
            style: TextStyle(color: context.colors.light, fontSize: 13)),
        if (total > 0) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(
              value: watched / total,
              minHeight: 6,
              borderRadius: BorderRadius.circular(6),
              color: lavender,
              backgroundColor: context.colors.surface),
        ],
        if (next != null) ...[
          const SizedBox(height: 12),
          SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: lavender,
                      foregroundColor:
                          Theme.of(context).brightness == Brightness.light
                              ? Colors.white
                              : const Color(0xFF1A102B),
                      minimumSize: const Size(48, 46),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  onPressed:
                      busy ? null : () => _flow.setEpisodeWatched(next, true),
                  icon: const Icon(Icons.check_rounded, size: 20),
                  label: Text(busy ? 'Saving…' : 'Mark watched'))),
        ],
        Center(
            child: TextButton(
                style: TextButton.styleFrom(
                    foregroundColor: lavender,
                    minimumSize: const Size(48, 48),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                onPressed: () {
                  setState(() {
                    _selectedTab = _ShowDetailTab.episodes;
                    if (episode != null) {
                      _data.selectedSeasonNumber = episode.seasonNumber;
                    }
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final target = _tabContentKey.currentContext;
                    if (mounted && target != null) {
                      Scrollable.ensureVisible(target,
                          alignment: 0.15,
                          duration: const Duration(milliseconds: 250));
                    }
                  });
                },
                child: Text(
                    progress.hasStarted ? 'Edit progress' : 'View episodes'))),
      ]),
    );
  }

  void _openEpisodes([int? season]) {
    setState(() {
      _selectedTab = _ShowDetailTab.episodes;
      if (season != null) _data.selectedSeasonNumber = season;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _tabContentKey.currentContext;
      if (mounted && target != null) {
        Scrollable.ensureVisible(target,
            alignment: .15, duration: const Duration(milliseconds: 250));
      }
    });
  }

  Widget _buildSeasonOverview(TvShow show) {
    if (show.seasons.isEmpty) return const SizedBox.shrink();
    final seasons = _showAllSeasons ? show.seasons : show.seasons.take(2);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: _buildSectionHeader(context, 'Seasons')),
        Flexible(
            child: TextButton(
                onPressed: () => _openEpisodes(),
                child: const Text('All episodes', textAlign: TextAlign.end))),
      ]),
      for (final season in seasons) ...[
        InkWell(
          onTap: () => _openEpisodes(season.seasonNumber),
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(children: [
                SizedBox(
                  width: 48,
                  height: 72,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: ShowPoster(path: season.posterPath),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 5,
                        children: [
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                season.seasonNumber == 0
                                    ? 'Specials'
                                    : season.name,
                                style: TextStyle(
                                    color: context.colors.white,
                                    fontWeight: FontWeight.w600)),
                            Text('${season.resolvedEpisodeCount} episodes',
                                style: TextStyle(
                                    color: context.colors.light, fontSize: 12)),
                          ]),
                      Text(
                          season.watchedEpisodeCount == 0
                              ? 'Not started'
                              : season.resolvedEpisodeCount > 0 &&
                                      season.watchedEpisodeCount >=
                                          season.resolvedEpisodeCount
                                  ? 'Watched'
                                  : '${season.watchedEpisodeCount} of ${season.resolvedEpisodeCount} watched',
                          style: TextStyle(
                              color: context.colors.light, fontSize: 12)),
                    ])),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right,
                    size: 18, color: context.colors.light),
              ])),
        ),
        Divider(height: 1, color: context.colors.tabBarBorder),
      ],
      if (show.seasons.length > 2)
        TextButton(
            onPressed: () => setState(() => _showAllSeasons = !_showAllSeasons),
            child: Text(_showAllSeasons
                ? 'Show fewer seasons'
                : 'Show remaining seasons')),
    ]);
  }

  void _showEpisodeSheet(TvEpisode episode) {
    final flow = _flow;
    showShowEpisodeSheet(context, episode,
        onToggleWatched: () =>
            flow.setEpisodeWatched(episode, !episode.watched));
  }

  Widget _buildProviderSection(TvShow show) => ShowWatchProvidersSection(
      providers: _data.watchProviders,
      userProviderIds: _data.userProviderIds,
      userProviderMatchKeys: _data.userProviderMatchKeys,
      region: context.select<AuthProvider, String>(
          (auth) => auth.dbUser?.watchProviderRegion ?? 'GB'),
      loading: _data.pendingDetails.contains('streaming services'),
      loaded: _data.loadedDetails.contains('streaming services'),
      failed: _data.detailErrors.contains('streaming services'),
      onRetry: () => _data.retrySection('streaming services'),
      onRegionChanged: _load);

  Widget _buildActions() {
    return Column(
      children: [
        Divider(
          height: 1,
          thickness: 1,
          color: Colors.white.withValues(alpha: 0.12),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _statusActionItem(
              icon: _data.userRating != null
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              label: 'Rate',
              badge:
                  _data.userRating != null ? '${_data.userRating!}/10' : null,
              color: context.colors.tertiary,
              isActive: _data.userRating != null,
              isLoading: _data.isRatingLoading,
              onTap: _data.updatingAction != null || _data.isRatingLoading
                  ? null
                  : _flow.showRatingSheet,
            ),
          ),
          Expanded(
            child: _statusActionItem(
              icon: _data.inWatchlist ? Icons.bookmark : Icons.bookmark_outline,
              label: 'Watchlist',
              color: context.colors.warning,
              isActive: _data.inWatchlist,
              isLoading: _data.updatingAction == ShowDetailAction.watchlist,
              onTap:
                  _data.updatingAction != null ? null : _flow.toggleWatchlist,
            ),
          ),
          Expanded(
            child: _statusActionItem(
              icon: _data.isFavorite ? Icons.favorite : Icons.favorite_outline,
              label: 'Favourite',
              color: context.colors.danger,
              isActive: _data.isFavorite,
              isLoading: _data.updatingAction == ShowDetailAction.favorite,
              onTap: _data.updatingAction != null ? null : _flow.toggleFavorite,
            ),
          ),
          Expanded(
            child: _statusActionItem(
              icon: _data.myListsContainingShow.isNotEmpty
                  ? Icons.playlist_add_check_rounded
                  : Icons.playlist_add_rounded,
              label: 'List',
              color: context.colors.secondary,
              isActive: _data.myListsContainingShow.isNotEmpty,
              isLoading: _data.listsContainingShowLoading,
              onTap: _data.updatingAction != null
                  ? null
                  : _flow.showAddToListSheet,
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildListsSection(BuildContext context) {
    final lists = _data.myListsContainingShow
        .map((list) => MediaDetailListItem(
              id: list.id,
              name: list.name,
              visibility: list.visibility,
              posterUrls: list.previewPosterUrls,
              itemCount: list.itemCount ??
                  (list.movieCount ?? 0) + (list.showCount ?? 0),
              ownerId: list.userId,
            ))
        .toList(growable: false);

    return MediaListsSection(
      ownLists: lists,
      friendLists: const [],
      loading: _data.listsContainingShowLoading,
      itemLabel: 'titles',
      onEdit: _flow.showAddToListSheet,
      onSeeAll: () => context.push('/movie-lists'),
      onOpenList: (item) => context.push(
        '/movie-lists/${item.id}'
        '?name=${Uri.encodeComponent(item.name)}'
        '&owner=${Uri.encodeComponent(item.ownerId ?? '')}',
      ),
    );
  }

  Widget _statusActionItem({
    required IconData icon,
    required String label,
    String? badge,
    required Color color,
    required bool isActive,
    required bool isLoading,
    required VoidCallback? onTap,
  }) {
    return MediaDetailAction(
        icon: icon,
        label: label,
        badge: badge,
        isActive: isActive,
        isLoading: isLoading,
        onTap: onTap);
  }

  Widget _buildProgressSection(TvShow show) {
    if (!_data.loadedDetails.contains('episodes') &&
        (_data.detailsLoading || _data.detailErrors.contains('episodes'))) {
      return _episodeLoadingState();
    }
    final total = show.resolvedEpisodeCount;
    final watched = _watchedEpisodeCount(show).clamp(0, total == 0 ? 0 : total);
    final percent = total == 0 ? 0.0 : watched / total;
    final complete = total > 0 && watched >= total;
    final title = total == 0
        ? 'Episode progress unavailable'
        : complete
            ? 'All episodes watched'
            : 'Episode progress';
    final percentLabel = '${(percent * 100).round()}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Your Progress'),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: _movieCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: context.colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          total == 0
                              ? 'Episode progress is not available yet'
                              : '$watched of $total episodes watched',
                          style: TextStyle(
                            color: context.colors.medium,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FlixiePill.label(label: Text(percentLabel)),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : percent,
                  minHeight: 5,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation(context.colors.success),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFriendSummary(TvShow show) =>
      ShowFriendsSection(summary: _data.friendSummary ?? show.friendSummary);

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
}

String _dateLabel(String? date) {
  if (date == null || date.isEmpty) return '-';
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

class _ShowTabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _ShowTabsHeaderDelegate(
      {required this.selected, required this.onSelected});

  final _ShowDetailTab selected;
  final ValueChanged<_ShowDetailTab> onSelected;

  @override
  double get minExtent => 62;
  @override
  double get maxExtent => 62;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    const labels = {
      _ShowDetailTab.overview: 'Overview',
      _ShowDetailTab.episodes: 'Episodes',
      _ShowDetailTab.reviews: 'Reviews',
      _ShowDetailTab.activity: 'My Activity',
    };
    return ColoredBox(
      color: context.colors.background,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          border:
              Border(bottom: BorderSide(color: context.colors.tabBarBorder)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          children: labels.entries.map((entry) {
            final active = entry.key == selected;
            return InkWell(
              onTap: () => onSelected(entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(
                          color: active
                              ? context.colors.primaryText
                              : Colors.transparent,
                          width: 3)),
                ),
                child: Semantics(
                    selected: active,
                    button: true,
                    child: Text(entry.value,
                        style: TextStyle(
                          color: active
                              ? context.colors.textPrimary
                              : context.colors.light,
                          fontWeight:
                              active ? FontWeight.w800 : FontWeight.w500,
                        ))),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ShowTabsHeaderDelegate oldDelegate) =>
      oldDelegate.selected != selected;
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
            Icon(Icons.error_outline, color: context.colors.danger, size: 44),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.light),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
