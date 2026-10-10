import 'package:flixie_app/features/movies/presentation/widgets/media_synopsis.dart';
import 'package:flixie_app/features/guest/presentation/guest_access.dart';
import '../controllers/movie_detail_controller.dart';
import '../movie_detail_action_flow.dart';
export '../controllers/movie_detail_controller.dart' show ListUpdateType;
import '../widgets/movie_friends_section.dart';
export '../widgets/movie_friends_section.dart' show FriendActivityTab;
import '../widgets/movie_detail_hero.dart';
import '../widgets/movie_detail_hero_tokens.dart';
import '../widgets/movie_watch_history_section.dart';
import '../widgets/movie_photos_section.dart';
import '../widgets/movie_trailers_section.dart';
import '../widgets/movie_watch_providers_section.dart';
export '../widgets/movie_watch_providers_section.dart' show WatchProviderTab;
import 'package:flixie_app/features/movies/presentation/widgets/movie_cast_sheet.dart';
import 'package:flixie_app/core/widgets/flixie_back_button.dart';
import 'package:flixie_app/core/widgets/flixie_section_header.dart';
import 'package:flixie_app/features/collections/movie_collection_card.dart';
import 'package:flixie_app/features/movies/presentation/widgets/media_detail_action.dart';
import 'package:flixie_app/features/sharing/presentation/media_chat_share.dart';
import 'package:flixie_app/features/movies/presentation/widgets/movie_social_opinions.dart';
import 'package:flixie_app/features/settings/presentation/pages/settings_screen.dart'
    show showSettingsEditDetailsSheet;
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/models/movie.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/features/movies/presentation/widgets/cast_card.dart';
import 'package:flixie_app/features/movies/presentation/widgets/external_links_section.dart';
import 'package:flixie_app/features/movies/presentation/widgets/film_info_card.dart';
import 'package:flixie_app/features/movies/presentation/widgets/media_reviews_section.dart';
import 'package:flixie_app/features/movies/presentation/widgets/similar_card.dart';
import 'package:flixie_app/features/movies/presentation/widgets/media_lists_section.dart';
import 'package:flixie_app/features/movies/presentation/widgets/watch_request_sheet.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';
import 'package:flixie_app/core/analytics/recommendation_attribution.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({
    super.key,
    required this.movieId,
    this.fromMovieMatch = false,
    this.source = DetailSource.unknown,
    this.initialTitle,
    this.initialPoster,
    this.recommendation,
  });

  final String movieId;
  final bool fromMovieMatch;
  final DetailSource source;
  final String? initialTitle;
  final String? initialPoster;
  final RecommendationAttribution? recommendation;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

enum MovieDetailTab { overview, reviews, activity, details }

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  late final MovieDetailController _data;
  MovieDetailTab _movieDetailTab = MovieDetailTab.overview;
  bool _showFullSynopsis = false;
  final _movieTabContentKey = GlobalKey();
  MovieDetailActionFlow get _actionFlow => MovieDetailActionFlow(
      context: context, data: _data, recommendation: widget.recommendation);

  // ---- Data loading ---------------------------------------------------------

  @override
  void initState() {
    super.initState();
    final id = int.tryParse(widget.movieId);
    if (id != null && id > 0) {
      context.read<AnalyticsController?>()?.contentOpened(
            contentType: 'movie',
            contentId: id,
            source: widget.source.value,
          );
    }
    _data = MovieDetailController(
        auth: context.read<AuthProvider>(),
        service: context.read<MovieService>())
      ..addListener(_sectionsChanged);
    _load();
  }

  void _sectionsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }

  Future<void> _refresh() => _data.refresh(widget.movieId);
  Future<void> _load() async {
    await _data.load(widget.movieId);
    if (!mounted ||
        _data.movie == null ||
        context.read<AuthProvider>().dbUser == null) return;
    final intent = GuestAccess.takeAction('/movies/${widget.movieId}');
    switch (intent) {
      case 'watchlist':
        if (!_data.inWatchlist) await _actionFlow.toggleWatchlist();
      case 'favorite':
        if (!_data.isFavorite) await _actionFlow.toggleFavorite();
      case 'list':
        await _actionFlow.showAddToListSheet();
      case 'log':
        await _actionFlow.showLogWatchSheet();
      case 'review':
        await _actionFlow.showWriteReviewSheet(context);
      case 'providers':
        await showSettingsEditDetailsSheet(context);
      case 'plan':
        _showWatchRequestSheet();
    }
  }

  @override
  void didUpdateWidget(covariant MovieDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movieId != widget.movieId) {
      _data.movie = null;
      _data.isLoading = true;
      _load();
    }
  }

  Widget _optionalSection(String key, String label, Widget child) {
    final state = _data.sectionStates[key];
    if (state == null ||
        (state == 'loading' && _data.loadedSections.contains(key))) {
      return child;
    }
    if (state == 'loading') {
      if (child is SizedBox && child.child == null) {
        return const SizedBox.shrink();
      }
      return ContentPlaceholder(
          label: 'Loading $label',
          style: switch (key) {
            'providers' => ContentPlaceholderStyle.providers,
            'credits' ||
            'images' ||
            'similar' =>
              ContentPlaceholderStyle.posters,
            'reviews' => ContentPlaceholderStyle.review,
            _ => ContentPlaceholderStyle.rows,
          });
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(
            child: Text('Couldn’t load $label',
                style: TextStyle(color: context.colors.medium))),
        if (state == 'error')
          TextButton(
              onPressed: _data.sectionRetries[key],
              child:
                  Semantics(label: 'Retry $label', child: const Text('Retry'))),
      ]),
    );
  }

  // ---- List Management ------------------------------------------------------

  // ---- Helpers --------------------------------------------------------------

  // ---- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_data.isLoading) {
      return Scaffold(
        backgroundColor: context.colors.background,
        body: widget.initialTitle != null
            ? MediaDetailPreview(
                title: widget.initialTitle!, poster: widget.initialPoster)
            : const SafeArea(child: MediaDetailScreenSkeleton()),
      );
    }

    if (_data.error != null) {
      return Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
          backgroundColor: context.colors.background,
          leading: const FlixieBackButton(),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  color: context.colors.danger,
                  size: 56,
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load movie',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _data.error!,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _data.isLoading = true;
                      _data.error = null;
                    });
                    _load();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final movie = _data.movie;
    if (movie == null) {
      return Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
          backgroundColor: context.colors.background,
          leading: const FlixieBackButton(),
        ),
        body: Center(
          child: Text(
            'Movie data is unavailable.',
            style: TextStyle(color: context.colors.medium),
          ),
        ),
      );
    }
    // Preserve the device text scale. Dense poster-led sections must reflow
    // or scroll rather than override a user's accessibility preference.
    return MediaQuery(
      data: MediaQuery.of(context),
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: RefreshIndicator(
          color: FlixieColors.primary,
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: MovieDetailHero(
                    movie: movie,
                    onShowScoreInfo: () => _showFlixScoreInfo(context)),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: MovieDetailHeroTokens.pageHorizontalPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(
                          height: MovieDetailHeroTokens.heroToWatchSectionGap),
                      _buildActionButtons(),
                      const SizedBox(height: 18),
                      _optionalSection(
                          'providers',
                          'watch providers',
                          MovieWatchProvidersSection(
                            key: ValueKey('providers:${movie.id}'),
                            providers: _data.watchProviders,
                            userProviderIds: _data.userProviderIds,
                            userProviderMatchKeys: _data.userProviderMatchKeys,
                            region: context
                                    .watch<AuthProvider>()
                                    .dbUser
                                    ?.watchProviderRegion ??
                                'GB',
                            onChangeRegion: () async {
                              await showSettingsEditDetailsSheet(context);
                              if (mounted) await _load();
                            },
                          )),
                      const SizedBox(height: 18),
                      _buildSynopsis(context, movie),
                      if (_data.friendsActivity.isNotEmpty ||
                          _data.friendSummaryLoading ||
                          _data.friendSummaryError != null) ...[
                        const SizedBox(height: 18),
                        _optionalSection(
                            'friend summary',
                            'friend summary',
                            MovieFriendsSection(
                              movieId: movie.id,
                              activities: _data.friendsActivity,
                              signedIn:
                                  context.read<AuthProvider>().dbUser != null,
                              loading: _data.friendSummaryLoading,
                              summaryLoaded: _data.loadedSections
                                  .contains('friend summary'),
                              hasSummary:
                                  _data.friendSummary?.friendCount != null,
                              hasError: _data.friendSummaryError != null,
                              onReload: () {
                                _data.loadFriendSummary(movie.id);
                              },
                            )),
                      ],
                      if (context.read<AuthProvider>().dbUser?.id
                          case final String viewerId) ...[
                        const SizedBox(height: 18),
                        MovieFollowingOpinions(
                            key: ValueKey('following:$viewerId:${movie.id}'),
                            movieId: movie.id,
                            viewerId: viewerId),
                      ],
                      _optionalSection('activity', 'friend activity',
                          const SizedBox.shrink()),
                      _optionalSection('friend recommendations',
                          'friend recommendations', const SizedBox.shrink()),
                      _optionalSection('your providers',
                          'your streaming services', const SizedBox.shrink()),
                      _optionalSection(
                          'rating', 'your rating', const SizedBox.shrink()),
                      const SizedBox(height: 14),
                      _buildMovieDetailTabs(),
                      const SizedBox(height: 18),
                      Container(
                          key: _movieTabContentKey,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            child: KeyedSubtree(
                              key: ValueKey(_movieDetailTab),
                              child: _buildSelectedMovieTab(context, movie),
                            ),
                          )),
                      const SizedBox(height: 110),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Hero top actions ----------------------------------------------------

  void _showFlixScoreInfo(BuildContext context) {
    showFlixiePromptSheet<void>(
      context: context,
      builder: (context) => FlixiePromptSheetContent(
        title: Text(
          'FLIXSCORE',
          style: TextStyle(
            color: context.colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Community ratings from Flixie.',
              style: TextStyle(
                color: context.colors.light,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Rating Guide:',
              style: TextStyle(
                color: context.colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '🔥 8.1+ · Loved\n'
              '😀 7.0-8.1 · Liked\n'
              '🙂 6.0-7.0 · Okay\n'
              '😐 5.0-6.0 · Meh\n'
              '😕 Below 5.0 · Disliked\n'
              'N/A · No ratings yet.',
              style: TextStyle(
                color: context.colors.light,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Got it',
              style: TextStyle(
                color: FlixieColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Synopsis ------------------------------------------------------------

  Widget _buildSynopsis(BuildContext context, Movie movie) {
    final text = movie.overview;
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Story'),
        const SizedBox(height: 8),
        MediaSynopsis(
          text: text,
          style: TextStyle(
              color: context.colors.light, fontSize: 14, height: 1.48),
          expanded: _showFullSynopsis,
          onToggle: () =>
              setState(() => _showFullSynopsis = !_showFullSynopsis),
          actionColor: FlixieColors.primary,
        ),
        if (_data.director != null) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => context.push(personDetailPath(
              _data.director!.id,
              source: DetailSource.personCredits,
              parentContentId: movie.id,
              parentContentType: 'movie',
            )),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12.5),
                children: [
                  TextSpan(
                    text: 'Directed by ',
                    style: TextStyle(
                      color: context.colors.medium,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextSpan(
                    text: _data.director!.name,
                    style: const TextStyle(
                      color: FlixieColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ---- Watch request -------------------------------------------------------

  void _showWatchRequestSheet() async {
    if (!await GuestAccess.require(context,
        title: 'Plan a watch with friends',
        path: '/movies/${widget.movieId}',
        intent: 'plan')) return;
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final friends = auth.cachedFriends?.friendships ?? [];
    final userId = auth.dbUser?.id;

    if (userId == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => MovieWatchRequestSheet(
        movieId: int.tryParse(widget.movieId),
        movieTitle: _data.movie?.title,
        moviePoster: _data.movie?.posterPath,
        requesterId: userId,
        friends: friends,
        fromMovieMatch: widget.fromMovieMatch,
        onSuccess: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showFlixieToast(
              FlixieToast(
                  type: FlixieToastType.success,
                  content: const Text('Watch plan sent!')),
            );
          }
        },
        onError: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showFlixieToast(
              FlixieToast(
                  type: FlixieToastType.error,
                  content: const Text('Failed to send watch plan')),
            );
          }
        },
      ),
    );
  }

  // ---- CTA buttons ---------------------------------------------------------

  Widget _buildActionButtons() {
    final signedIn = context.watch<AuthProvider>().dbUser != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (signedIn)
          _buildWatchEntryStatusRow()
        else
          FilledButton.icon(
            onPressed: () => _actionFlow.showLogWatchSheet(),
            icon: const Icon(Icons.edit_note_outlined),
            label: const Text('Log an entry'),
          ),
        const SizedBox(height: 8),
        Divider(
          height: 1,
          thickness: 1,
          color: Colors.white.withValues(alpha: 0.12),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: EdgeInsets.zero,
          child: Row(
            children: [
              Expanded(
                child: _statusActionItem(
                  icon: _data.inWatchlist
                      ? Icons.bookmark
                      : Icons.bookmark_outline,
                  label: 'Watchlist',
                  color: context.colors.warning,
                  isActive: _data.inWatchlist,
                  isLoading:
                      _data.currentlyUpdating == ListUpdateType.watchlist,
                  onTap: _data.currentlyUpdating != null
                      ? null
                      : _actionFlow.toggleWatchlist,
                ),
              ),
              if (signedIn)
                Expanded(
                  child: _statusActionItem(
                    icon: _data.isFavorite
                        ? Icons.favorite
                        : Icons.favorite_outline,
                    label: 'Favourite',
                    color: context.colors.danger,
                    isActive: _data.isFavorite,
                    isLoading:
                        _data.currentlyUpdating == ListUpdateType.favorite,
                    onTap: _data.currentlyUpdating != null
                        ? null
                        : _actionFlow.toggleFavorite,
                  ),
                ),
              if (signedIn)
                Expanded(
                  child: _statusActionItem(
                    icon: _data.myListsContainingMovie.isNotEmpty
                        ? Icons.playlist_add_check_rounded
                        : Icons.playlist_add_rounded,
                    label: 'List',
                    color: context.colors.secondary,
                    isActive: _data.myListsContainingMovie.isNotEmpty,
                    isLoading: _data.listsContainingMovieLoading,
                    onTap: _data.currentlyUpdating != null
                        ? null
                        : _actionFlow.showAddToListSheet,
                  ),
                ),
              if (signedIn)
                Expanded(
                  child: _statusActionItem(
                    icon: Icons.group_add_outlined,
                    label: 'Plan',
                    color: FlixieColors.primary,
                    isActive: false,
                    isLoading: false,
                    onTap: _data.currentlyUpdating != null
                        ? null
                        : _showWatchRequestSheet,
                  ),
                ),
              Expanded(
                child: _statusActionItem(
                  icon: Icons.ios_share_rounded,
                  label: 'Share',
                  color: Theme.of(context).brightness == Brightness.light
                      ? const Color(0xFF16658C)
                      : const Color(0xFF5CC8FF),
                  isActive: true,
                  isLoading: false,
                  onTap: _data.movie == null
                      ? null
                      : () => MediaChatShare(context).show(ChatShareMedia(
                          id: _data.movie!.id,
                          title: _data.movie!.title,
                          posterPath: _data.movie!.posterPath)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The movie header always shows one watch-entry component. Its evidence and
  /// CTA change with the latest entry, rather than mixing a movie-level rating
  /// with a separate watch-history action.
  Widget _buildWatchEntryStatusRow() {
    if (_data.watchHistoryLoading && !_data.watchHistoryLoaded) {
      return const ContentPlaceholder(
          label: 'Loading watch history',
          style: ContentPlaceholderStyle.compact);
    }
    if (_data.sectionStates['history'] == 'error') {
      return TextButton.icon(
          onPressed: () {
            final user = context.read<AuthProvider>().dbUser;
            if (user != null && _data.movie != null) {
              _data.loadWatchHistory(user.id, _data.movie!.id);
            }
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Retry watch history'));
    }

    final entries = [..._data.movieWatchHistory]..sort((a, b) {
        final left = DateTime.tryParse(a.watchedAt ?? '') ?? DateTime(0);
        final right = DateTime.tryParse(b.watchedAt ?? '') ?? DateTime(0);
        return right.compareTo(left);
      });
    final latest = entries.isEmpty ? null : entries.first;
    final previousRated =
        entries.skip(1).where((entry) => entry.rating != null).firstOrNull;
    final latestRated = latest?.rating != null;
    final watchedCount = entries.length;
    final isRewatch = watchedCount > 1;
    final hasAnyRating = entries.any((entry) => entry.rating != null);
    final canInteract = _data.currentlyUpdating == null;

    final title = watchedCount == 0
        ? 'Not watched yet'
        : watchedCount == 1
            ? 'Watched once'
            : 'Watched $watchedCount times';
    final icon = watchedCount == 0
        ? Icons.history_rounded
        : isRewatch
            ? Icons.replay_rounded
            : Icons.check_rounded;
    final iconColor = context.colors.success;
    final iconBackground = watchedCount == 0
        ? FlixieColors.primary.withValues(alpha: .18)
        : context.colors.success.withValues(alpha: .12);

    final dateText = latest?.watchedAt == null
        ? (watchedCount == 0
            ? 'Start your watch history'
            : 'Watch date not saved')
        : _formatWatchDate(latest!.watchedAt);
    final watchDetailText = latestRated
        ? '${isRewatch ? 'Latest · ' : ''}$dateText'
        : watchedCount == 0
            ? 'Start your watch history'
            : isRewatch
                ? 'Latest · $dateText  Not rated'
                : '$dateText  Not rated';
    final ratingText =
        latestRated ? '★ ${latest!.rating!.toStringAsFixed(0)}/10' : null;
    final recommendationLabel = latest?.recommended == true
        ? 'Recommended'
        : latest?.recommended == false
            ? 'Wouldn’t recommend'
            : null;
    final recommendationIcon = latest?.recommended == true
        ? '👍'
        : latest?.recommended == false
            ? '👎'
            : null;

    void openHistory() {
      setState(() => _movieDetailTab = MovieDetailTab.activity);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _movieTabContentKey.currentContext;
        if (mounted && target != null) {
          Scrollable.ensureVisible(target,
              alignment: .1, duration: const Duration(milliseconds: 250));
        }
      });
    }

    void logAgain() => _actionFlow.showLogWatchSheet();
    void rateLatest() => _actionFlow.showLogWatchSheet(entry: latest);

    final needsRating = watchedCount > 0 && !latestRated;
    final primaryLabel = watchedCount == 0
        ? 'Log watch'
        : needsRating
            ? (isRewatch ? 'Rate latest' : 'Add rating')
            : 'Log again';
    final primaryAction =
        watchedCount == 0 || latestRated ? logAgain : rateLatest;
    final primaryButton = FilledButton(
      onPressed: canInteract ? primaryAction : null,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      child: Text(primaryLabel),
    );

    final latestRating = latest?.rating;
    final previousRating = previousRated?.rating;
    final previousComparison = isRewatch &&
            latestRating != null &&
            previousRating != null
        ? '${previousRating.toStringAsFixed(0)}/10 → ${latestRating.toStringAsFixed(0)}/10'
        : null;
    final delta = previousComparison == null
        ? null
        : latestRating!.round() - previousRating!.round();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: watchedCount == 0 ? null : openHistory,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stackAction = constraints.maxWidth < 326 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.2;
              final details = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: context.colors.light,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  if (ratingText != null) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        Text(
                          ratingText,
                          style: TextStyle(
                            color: context.colors.warning,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (recommendationLabel != null) ...[
                          const SizedBox(width: 7),
                          Text(
                            '·',
                            style: TextStyle(
                              color: context.colors.medium,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            recommendationLabel,
                            style: TextStyle(
                              color: context.colors.medium,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            recommendationIcon!,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    watchDetailText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.colors.medium,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
              final leading = Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: iconBackground, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 24),
              );
              final action = needsRating && !isRewatch
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      OutlinedButton(
                        onPressed: canInteract ? rateLatest : null,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          textStyle: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        child: const Text('Add rating'),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'Log again',
                        onPressed: canInteract ? logAgain : null,
                        icon: const Icon(Icons.replay_rounded),
                      ),
                    ])
                  : primaryButton;

              return Column(mainAxisSize: MainAxisSize.min, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  leading,
                  const SizedBox(width: 10),
                  Expanded(child: details),
                  if (!stackAction) ...[const SizedBox(width: 8), action],
                ]),
                if (stackAction) ...[
                  const SizedBox(height: 14),
                  Align(alignment: Alignment.centerRight, child: action),
                ],
                if (isRewatch &&
                    (previousComparison != null || !hasAnyRating)) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(left: 12),
                    decoration: const BoxDecoration(
                      border: Border(
                          left: BorderSide(
                              color: FlixieColors.primary, width: 2)),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Text(
                          previousComparison == null
                              ? 'Previous watches · No ratings yet'
                              : 'Previous rating',
                          style: TextStyle(
                              color: context.colors.medium, fontSize: 13),
                        ),
                      ),
                      if (previousComparison != null)
                        Text(
                          '$previousComparison${delta == null || delta == 0 ? '' : delta > 0 ? '  ↑$delta' : '  ↓${delta.abs()}'}',
                          style: TextStyle(
                              color: context.colors.warning,
                              fontWeight: FontWeight.w600),
                        ),
                    ]),
                  ),
                ],
              ]);
            },
          ),
        ),
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

  String _formatWatchDate(String? iso) {
    final dt = DateTime.tryParse(iso ?? '');
    if (dt == null) return 'Unknown date';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _buildMovieDetailTabs() {
    return Row(
        children: MovieDetailTab.values.map((tab) {
      final selected = _movieDetailTab == tab;
      return Expanded(
          child: Semantics(
              selected: selected,
              button: true,
              child: InkWell(
                  onTap: () => setState(() => _movieDetailTab = tab),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                    decoration: BoxDecoration(
                        border: Border(
                            bottom: BorderSide(
                                color: selected
                                    ? context.colors.primaryText
                                    : context.colors.tabBarBorder,
                                width: selected ? 3 : 1))),
                    alignment: Alignment.center,
                    child: Text(
                        switch (tab) {
                          MovieDetailTab.overview => 'Overview',
                          MovieDetailTab.reviews => 'Reviews',
                          MovieDetailTab.activity => 'My Activity',
                          MovieDetailTab.details => 'Details',
                        },
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: selected
                                ? context.colors.textPrimary
                                : context.colors.light,
                            fontSize: 13,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500)),
                  ))));
    }).toList());
  }

  Widget _buildSelectedMovieTab(BuildContext context, Movie movie) {
    return switch (_movieDetailTab) {
      MovieDetailTab.overview => _tabContent([
          if (movie.collection != null)
            MovieCollectionCard(
                collection: movie.collection!,
                onReturn: () {
                  if (!mounted) return;
                  setState(() => _data.inWatchlist = context
                          .read<AuthProvider>()
                          .dbUser
                          ?.isMovieInWatchlist(movie.id) ??
                      false);
                }),
          MovieTrailersSection(movie: movie),
          _optionalSection(
              'credits', 'cast and crew', _buildTopCastSection(context)),
          _optionalSection(
              'images',
              'images',
              MoviePhotosSection(
                  movie: movie,
                  images: _data.movieImages,
                  loading: _data.movieImagesLoading)),
          _optionalSection(
              'similar', 'similar films', _buildMoreLikeThisSection(context)),
        ]),
      MovieDetailTab.reviews => _tabContent([
          _optionalSection(
              'reviews', 'reviews', _buildUserReviewsSection(context)),
        ]),
      MovieDetailTab.activity => _tabContent([
          _optionalSection(
              'history',
              'watch history',
              MovieWatchHistorySection(
                entries: _data.movieWatchHistory,
                loading: _data.watchHistoryLoading,
                formatDate: _formatWatchDate,
                onAdd: () => _actionFlow.showLogWatchSheet(),
                onEdit: (entry) => _actionFlow.showLogWatchSheet(entry: entry),
                onDelete: _actionFlow.deleteWatchEntry,
              )),
          _optionalSection('lists', 'lists', _buildListsSection(context)),
        ]),
      MovieDetailTab.details => _tabContent([
          FilmInfoCard(
            director: null,
            writers: _data.writers,
            producers: _data.producers,
            movie: movie,
          ),
          ExternalLinksSection(movie: movie),
        ]),
    };
  }

  Widget _tabContent(List<Widget> sections) {
    final visibleSections = sections
        .where((section) => !(section is SizedBox &&
            section.child == null &&
            section.width == 0 &&
            section.height == 0))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < visibleSections.length; index++) ...[
          if (index > 0)
            const SizedBox(height: MovieDetailHeroTokens.sectionSpacing),
          visibleSections[index],
        ],
      ],
    );
  }

  // ---- Friends activity --------------------------------------------------

  Widget _buildListsSection(BuildContext context) {
    final ownLists = _data.myListsContainingMovie
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
    final friendLists = _data.friendsListsContainingMovie
        .map((entry) => MediaDetailListItem(
              id: entry.listId,
              name: entry.listName,
              visibility: entry.visibility ?? 'PUBLIC',
              posterUrls: entry.previewPosterUrls,
              itemCount: entry.movieCount ?? 0,
              ownerId: entry.friendUserId,
              ownerUsername: entry.friendName,
              ownerAvatar: entry.friendAvatar,
            ))
        .toList(growable: false);

    return MediaListsSection(
      ownLists: ownLists,
      friendLists: friendLists,
      loading: _data.listsContainingMovieLoading,
      itemLabel: 'films',
      onEdit: _actionFlow.showAddToListSheet,
      onSeeAll: () => context.push('/movie-lists'),
      onOpenList: (item) => context.push(
        '/movie-lists/${item.id}'
        '?name=${Uri.encodeComponent(item.name)}'
        '&owner=${Uri.encodeComponent(item.ownerId ?? '')}',
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) =>
      FlixieSectionHeader(title: title);

  // ---- Photos -------------------------------------------------------------

  // ---- Trailers -----------------------------------------------------------

  // ---- Where to watch ------------------------------------------------------

  // ---- Top cast ------------------------------------------------------------

  void _showAllCast(BuildContext context) {
    showModalBottomSheet(
      useRootNavigator: true,
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MovieCastSheet(
        cast: _data.cast,
        parentContentId: int.parse(widget.movieId),
      ),
    );
  }

  Widget _buildTopCastSection(BuildContext context) {
    if (_data.cast.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader(context, 'Top Cast'),
            TextButton(
              onPressed: () => _showAllCast(context),
              child: const Row(
                children: [
                  Text(
                    'See all',
                    style: TextStyle(
                      color: FlixieColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: FlixieColors.primary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: CastCard.heightFor(context),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _data.cast.length > 6 ? 6 : _data.cast.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, i) => CastCard(
              member: _data.cast[i],
              parentContentId: int.parse(widget.movieId),
              parentContentType: 'movie',
            ),
          ),
        ),
      ],
    );
  }

  // ---- Write review -------------------------------------------------------

  // ---- User reviews --------------------------------------------------------

  Widget _buildUserReviewsSection(BuildContext context) => MediaReviewsSection(
        reviews: _data.reviews,
        currentUserId: context.read<AuthProvider>().dbUser?.id,
        onWriteReview: () => _actionFlow.showWriteReviewSheet(context),
      );

  // ---- More like this ------------------------------------------------------

  Widget _buildMoreLikeThisSection(BuildContext context) {
    if (_data.similar.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'More like this'),
        const SizedBox(height: 8),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _data.similar.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) =>
                SimilarMovieCard(movie: _data.similar[i]),
          ),
        ),
      ],
    );
  }
}
