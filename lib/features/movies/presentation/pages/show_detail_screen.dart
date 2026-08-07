import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/show.dart';
import 'package:flixie_app/models/show_list.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/data/show_service.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/movies/presentation/widgets/add_show_to_list_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/genre_chip.dart';
import 'package:flixie_app/features/movies/presentation/widgets/review_card.dart';
import 'package:flixie_app/features/movies/presentation/widgets/write_review_sheet.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/movies/presentation/widgets/media_lists_section.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/core/utils/skeleton.dart';

enum _ShowAction { watchlist, favorite }

enum _ShowDetailTab { overview, episodes, reviews, activity, details }

enum _ShowProviderTab { stream, rent, buy }

class ShowDetailScreen extends StatefulWidget {
  const ShowDetailScreen({super.key, required this.showId});

  final String showId;

  @override
  State<ShowDetailScreen> createState() => _ShowDetailScreenState();
}

class _ShowDetailScreenState extends State<ShowDetailScreen> {
  TvShow? _show;
  List<WatchProvider> _watchProviders = [];
  List<TvShowCredit> _cast = [];
  List<TvShowCredit> _crew = [];
  List<Review> _reviews = [];
  TvShowFriendSummary? _friendSummary;
  List<ShowList> _myListsContainingShow = [];
  Set<int> _userProviderIds = {};
  _ShowProviderTab _watchProviderTab = _ShowProviderTab.stream;
  bool _isLoading = true;
  String? _error;
  bool _inWatchlist = false;
  bool _isWatched = false;
  bool _isFavorite = false;
  int? _userRating;
  bool _isRatingLoading = false;
  bool _listsContainingShowLoading = false;
  bool _showFullOverview = false;
  _ShowAction? _updatingAction;
  int? _selectedSeasonNumber;
  final Set<int> _updatingEpisodeIds = {};
  final Set<int> _updatingSeasonNumbers = {};
  _ShowDetailTab _selectedTab = _ShowDetailTab.overview;

  static const _background = FlixieColors.background;
  static const _primary = FlixieColors.primary;
  static const _accent = FlixieColors.primaryTint;
  static const _card = FlixieColors.surface;
  static const _textSecondary = FlixieColors.light;
  static const _success = FlixieColors.success;

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
        ShowService.getShowCredits(id).catchError(
          (_) => const TvShowCredits(),
        ),
        if (user != null)
          UserService.getUserWatchProviders(user.id)
              .catchError((_) => <WatchProvider>[])
        else
          Future.value(<WatchProvider>[]),
        if (user != null)
          ShowService.getUserShowRating(id, user.id).catchError((_) => null),
        ShowService.getShowReviews(id).catchError((_) => <Review>[]),
        if (user != null)
          ShowService.getFriendSummary(id).catchError((_) => null)
        else
          Future.value(null),
      ]);

      if (!mounted) return;
      final show = results[0] as TvShow;
      final providersFromEndpoint = results[1] as List<WatchProvider>;
      final credits = results[2] as TvShowCredits;
      final userProviders = results[3] as List<WatchProvider>;
      final userRating = results.length > 4 ? results[4] as int? : null;
      final reviews = results[5] as List<Review>;
      final friendSummary = results[6] as TvShowFriendSummary?;
      final totalEpisodes = show.resolvedEpisodeCount;
      final watchedEpisodes = _watchedEpisodeCount(show);
      setState(() {
        _show = show;
        _watchProviders = providersFromEndpoint.isNotEmpty
            ? providersFromEndpoint
            : show.watchProviders;
        _cast = credits.cast.isNotEmpty ? credits.cast : show.cast;
        _crew = credits.crew.isNotEmpty ? credits.crew : show.crew;
        _userProviderIds = userProviders.map((provider) => provider.id).toSet();
        _userRating = userRating;
        _reviews = reviews;
        _friendSummary = friendSummary ?? show.friendSummary;
        _selectedSeasonNumber = _resolveSelectedSeasonNumber(show);
        _inWatchlist = _containsShowId(user?.showWatchlist, id);
        _isWatched = totalEpisodes > 0 && watchedEpisodes >= totalEpisodes;
        _isFavorite = _containsShowId(user?.favoriteShows, id);
        _isLoading = false;
      });
      if (user != null) {
        _loadListsContainingShow(user.id, id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadListsContainingShow(String userId, int showId) async {
    setState(() => _listsContainingShowLoading = true);
    try {
      final lists = await UserService.getShowLists(userId);
      final containing = <ShowList>[];
      for (final list in lists) {
        final shows = await UserService.getShowListShows(userId, list.id);
        if (shows.any((show) => show.id == showId)) {
          containing.add(list);
        }
      }
      if (!mounted) return;
      setState(() {
        _myListsContainingShow = containing;
        _listsContainingShowLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _listsContainingShowLoading = false);
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

  List<dynamic> _updatedShowIdList(
    List<dynamic>? items,
    int showId,
    bool shouldContain,
  ) {
    final updated = (items ?? const <dynamic>[])
        .where((item) => !_dynamicShowIdMatches(item, showId))
        .toList();
    if (shouldContain) {
      updated.add({'showId': showId});
    }
    return updated;
  }

  bool _dynamicShowIdMatches(dynamic item, int showId) {
    if (item is int) return item == showId;
    if (item is String) return int.tryParse(item) == showId;
    if (item is Map<String, dynamic>) {
      return item['showId'] == showId || item['id'] == showId;
    }
    return false;
  }

  int _resolveSelectedSeasonNumber(TvShow show) {
    if (show.seasons.isEmpty) return 1;
    final current = _selectedSeasonNumber;
    if (current != null &&
        show.seasons.any((season) => season.seasonNumber == current)) {
      return current;
    }

    final inProgress = show.seasons.where((season) {
      final total = season.resolvedEpisodeCount;
      return total > 0 &&
          season.watchedEpisodeCount > 0 &&
          season.watchedEpisodeCount < total;
    }).firstOrNull;
    if (inProgress != null) return inProgress.seasonNumber;

    final nextUnwatched = show.seasons.where((season) {
      final total = season.resolvedEpisodeCount;
      return total == 0 || season.watchedEpisodeCount < total;
    }).firstOrNull;
    if (nextUnwatched != null) return nextUnwatched.seasonNumber;

    return show.seasons.last.seasonNumber;
  }

  Future<void> _toggleWatchlist() async {
    final user = context.read<AuthProvider>().dbUser;
    final analytics = context.read<AnalyticsController>();
    final showId = _show?.id;
    if (user == null || showId == null) return;

    setState(() => _updatingAction = _ShowAction.watchlist);
    try {
      final nextInWatchlist = !_inWatchlist;
      if (_inWatchlist) {
        await ShowService.removeFromWatchlist(user.id, showId);
        await analytics.watchlistItemRemoved(source: 'show_detail');
        await analytics.showRemovedFromWatchlist();
      } else {
        await ShowService.addToWatchlist(user.id, showId);
        await analytics.watchlistItemAdded(source: 'show_detail');
        await analytics.showAddedToWatchlist();
      }
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _inWatchlist = nextInWatchlist;
        _updatingAction = null;
      });
      context.read<AuthProvider>()
        ..updateUserList(
          showWatchlist: _updatedShowIdList(
            user.showWatchlist,
            showId,
            nextInWatchlist,
          ),
        )
        ..markActivityChanged();
    } catch (e) {
      if (!mounted) return;
      setState(() => _updatingAction = null);
      _showSnack('Unable to update watchlist');
    }
  }

  Future<void> _toggleFavorite() async {
    final user = context.read<AuthProvider>().dbUser;
    final analytics = context.read<AnalyticsController>();
    final showId = _show?.id;
    if (user == null || showId == null) return;

    setState(() => _updatingAction = _ShowAction.favorite);
    try {
      final nextIsFavorite = !_isFavorite;
      if (_isFavorite) {
        await ShowService.removeFromFavourites(user.id, showId);
        await analytics.showUnfavourited();
      } else {
        await ShowService.addToFavourites(user.id, showId);
        await analytics.showFavourited();
      }
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _isFavorite = nextIsFavorite;
        _updatingAction = null;
      });
      context.read<AuthProvider>()
        ..updateUserList(
          favoriteShows: _updatedShowIdList(
            user.favoriteShows,
            showId,
            nextIsFavorite,
          ),
        )
        ..markActivityChanged();
    } catch (_) {
      if (!mounted) return;
      setState(() => _updatingAction = null);
      _showSnack('Unable to update favourites');
    }
  }

  Future<void> _showAddToListSheet() async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    final show = _show;
    if (userId == null || show == null) return;

    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddShowToListSheet(
        showId: show.id,
        showTitle: show.name,
        showPosterPath: show.posterPath,
        firstAirDate: show.firstAirDate,
        ratingLabel: show.voteAverage != null
            ? '★ ${show.voteAverage!.toStringAsFixed(1)}'
            : null,
      ),
    );
    if (changed == true && mounted) {
      await _loadListsContainingShow(userId, show.id);
    }
  }

  Future<void> _setSeasonWatched(TvSeason season, bool watched) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    final showId = _show?.id;
    if (userId == null || showId == null) return;

    setState(() => _updatingSeasonNumbers.add(season.seasonNumber));
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
    } finally {
      if (mounted) {
        setState(() => _updatingSeasonNumbers.remove(season.seasonNumber));
      }
    }
  }

  Future<void> _setEpisodeWatched(TvEpisode episode, bool watched) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    final showId = _show?.id;
    if (userId == null || showId == null) return;

    setState(() => _updatingEpisodeIds.add(episode.id));
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
    } finally {
      if (mounted) setState(() => _updatingEpisodeIds.remove(episode.id));
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _setUserRating(int rating) async {
    final user = context.read<AuthProvider>().dbUser;
    final analytics = context.read<AnalyticsController>();
    final showId = _show?.id;
    if (user == null || showId == null) return;

    setState(() => _isRatingLoading = true);
    try {
      final response = await ShowService.addShowRating(showId, user.id, rating);
      await analytics.ratingSaved(source: 'show_detail');
      final updatedVoteAverage = _parseDouble(response['voteAverage']);
      final updatedVoteCount = _parseInt(response['voteCount']);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _userRating = rating;
        if (updatedVoteAverage != null || updatedVoteCount != null) {
          final current = _show!;
          _show = TvShow(
            id: current.id,
            name: current.name,
            firstAirDate: current.firstAirDate,
            lastAirDate: current.lastAirDate,
            overview: current.overview,
            posterPath: current.posterPath,
            backdropPath: current.backdropPath,
            popularity: current.popularity,
            voteAverage: updatedVoteAverage ?? current.voteAverage,
            tmdbRating: current.tmdbRating,
            imdbRating: current.imdbRating,
            imdbRatingLabel: current.imdbRatingLabel,
            rottenTomatoRatingLabel: current.rottenTomatoRatingLabel,
            metascoreRatingLabel: current.metascoreRatingLabel,
            flixieScore: current.flixieScore,
            friendRating: current.friendRating,
            friendRecommendPercent: current.friendRecommendPercent,
            voteCount: updatedVoteCount ?? current.voteCount,
            numberOfSeasons: current.numberOfSeasons,
            numberOfEpisodes: current.numberOfEpisodes,
            tagline: current.tagline,
            status: current.status,
            originalLanguage: current.originalLanguage,
            originCountry: current.originCountry,
            genres: current.genres,
            networks: current.networks,
            createdBy: current.createdBy,
            seasons: current.seasons,
            episodes: current.episodes,
            cast: current.cast,
            crew: current.crew,
            similarShows: current.similarShows,
            friendActivity: current.friendActivity,
            friendSummary: current.friendSummary,
            watchProviders: current.watchProviders,
            watchedEpisodeCount: current.watchedEpisodeCount,
          );
        }
        _isRatingLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isRatingLoading = false);
      _showSnack('Unable to save show rating');
    }
  }

  void _showRatingSheet() {
    var selectedRating = _userRating;
    showModalBottomSheet<void>(
      context: context,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          color: FlixieColors.tabBarBackgroundFocused,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rate this show',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                const Text(
                  'Choose a score for the overall series.',
                  style: TextStyle(color: FlixieColors.medium, fontSize: 13),
                ),
                const SizedBox(height: 20),
                GridView.count(
                  crossAxisCount: 5,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: List.generate(10, (index) {
                    final rating = index + 1;
                    final selected = selectedRating == rating;
                    return InkWell(
                      onTap: () => setSheetState(() => selectedRating = rating),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? FlixieColors.primary
                              : FlixieColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$rating',
                          style: TextStyle(
                            color:
                                selected ? Colors.white : FlixieColors.medium,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedRating == null
                        ? null
                        : () {
                            final rating = selectedRating!;
                            Navigator.pop(sheetContext);
                            _setUserRating(rating);
                          },
                    child: const Text('Save rating'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFlixScoreInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'FLIXSCORE',
          style: TextStyle(
            color: FlixieColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Community ratings from Flixie. The score updates as viewers rate this show.',
          style: TextStyle(
            color: FlixieColors.light,
            fontSize: 14,
            height: 1.5,
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: _isLoading
          ? const SafeArea(child: MediaDetailScreenSkeleton())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final show = _show!;
    return RefreshIndicator(
      color: _primary,
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _buildSliverAppBar(context, show),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEpisodeProgressBanner(show),
                  const SizedBox(height: 14),
                  _buildActions(),
                  const SizedBox(height: 20),
                  _buildProviderSection(show),
                  if (_watchProviders.isNotEmpty) const SizedBox(height: 20),
                  _buildFriendSummary(show),
                  if ((_friendSummary?.friendCount ?? 0) > 0 ||
                      show.friendActivity.isNotEmpty)
                    const SizedBox(height: 20),
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
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
              child: _buildSelectedTab(context, show),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedTab(BuildContext context, TvShow show) {
    switch (_selectedTab) {
      case _ShowDetailTab.overview:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildNextEpisode(show),
          _sectionGap(),
          _buildSeasonOverview(show),
          _sectionGap(),
          _buildSynopsis(context, show),
          _sectionGap(),
          _buildCastSection(context, show),
          _sectionGap(),
          _buildSimilarSection(context, show),
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
          const SizedBox(height: 24),
          _FriendActivityList(show: show),
        ]);
      case _ShowDetailTab.details:
        return _buildShowInfoSection(context, show);
    }
  }

  Widget _sectionGap() => const SizedBox(height: 24);

  Widget _buildReviewsTab() {
    final userId = context.read<AuthProvider>().dbUser?.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _buildSectionHeader(context, 'Reviews')),
            if (_reviews.isNotEmpty)
              TextButton(
                onPressed: _showAllReviews,
                child: Text('See all ${_reviews.length}'),
              ),
            const SizedBox(width: 4),
            OutlinedButton.icon(
              onPressed: _showWriteReviewSheet,
              style: OutlinedButton.styleFrom(
                foregroundColor: FlixieColors.primary,
                side: const BorderSide(color: FlixieColors.primary),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: const Text(
                'Write review',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_reviews.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No reviews yet. Be the first to write one!',
              style: TextStyle(color: FlixieColors.medium, fontSize: 13),
            ),
          )
        else
          ..._reviews.take(4).map((review) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ReviewCard(review: review, currentUserId: userId),
              )),
      ],
    );
  }

  Future<void> _showWriteReviewSheet() async {
    final user = context.read<AuthProvider>().dbUser;
    final show = _show;
    if (user == null || show == null) return;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WriteReviewSheet(
        showId: show.id,
        userId: user.id,
        initialRating: _userRating?.toDouble(),
        onSubmitted: (review) {
          setState(() => _reviews = [review, ..._reviews]);
          final auth = context.read<AuthProvider>();
          auth.invalidateCachedReviews();
          auth.markActivityChanged();
        },
      ),
    );
  }

  void _showAllReviews() {
    final userId = context.read<AuthProvider>().dbUser?.id;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: .9,
        minChildSize: .5,
        maxChildSize: .95,
        builder: (sheetContext, controller) => Container(
          decoration: const BoxDecoration(
            color: FlixieColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: FlixieColors.medium,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'All Reviews (${_reviews.length})',
                        style: const TextStyle(
                          color: FlixieColors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close, color: FlixieColors.light),
                    ),
                  ],
                ),
              ),
              const Divider(color: FlixieColors.tabBarBorder, height: 1),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  padding: const EdgeInsets.all(16),
                  itemCount: _reviews.length,
                  itemBuilder: (_, index) => ReviewCard(
                    review: _reviews[index],
                    currentUserId: userId,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, TvShow show) {
    return SliverAppBar(
      expandedHeight: MediaQuery.sizeOf(context).width < 380 ? 260 : 270,
      pinned: false,
      backgroundColor: FlixieColors.background,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                child: LayoutBuilder(builder: (context, constraints) {
                  final compact = constraints.maxWidth < 360;
                  final posterWidth =
                      (constraints.maxWidth * .42).clamp(120.0, 168.0);
                  return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: posterWidth,
                          child: AspectRatio(
                            aspectRatio: 2 / 3,
                            child: Hero(
                              tag: 'show-poster-${show.id}',
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: show.posterPath == null
                                      ? null
                                      : () => _showPosterViewer(show),
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(12),
                                      bottomRight: Radius.circular(12),
                                    ),
                                    child: _ShowPoster(path: show.posterPath),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: compact ? 14 : 20),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child:
                                _buildHeroInformation(show, compact: compact),
                          ),
                        ),
                      ]);
                }),
              ),
              Positioned(
                top: 8,
                left: 16,
                child: _heroIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => context.pop(),
                ),
              ),
              Positioned(
                top: 8,
                right: 16,
                child: _heroIconButton(
                  icon: Icons.ios_share_rounded,
                  onTap: () => _showSnack('Show sharing is coming soon'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroInformation(TvShow show, {required bool compact}) {
    final year = DateTime.tryParse(show.firstAirDate ?? '')?.year;
    final seasons = show.numberOfSeasons ?? show.seasons.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(show.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 24 : 28,
                height: 1.02,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 9),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: _ShowScoreBadge(
            show: show,
            onTap: () => _showFlixScoreInfo(context),
          ),
        ),
        const SizedBox(height: 7),
        Text(
            [
              if (year != null) '$year',
              if (seasons > 0)
                '$seasons ${seasons == 1 ? 'season' : 'seasons'}',
            ].join('  ·  '),
            style: const TextStyle(color: FlixieColors.light, fontSize: 14)),
        if ((show.status ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          _StatusChip(label: show.status!),
        ],
        if ((show.tagline ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(show.tagline!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: FlixieColors.light, fontSize: 13, height: 1.25)),
        ],
        if (show.genres.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(show.genres.take(2).join('  ·  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: FlixieColors.medium, fontSize: 12)),
        ],
        if (show.createdBy.isNotEmpty) ...[
          const SizedBox(height: 7),
          Text('Created by ${show.createdBy.take(2).join(', ')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: FlixieColors.medium, fontSize: 12)),
        ],
      ],
    );
  }

  void _showPosterViewer(TvShow show) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) =>
            _FullScreenShowPoster(show: show),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Widget _heroIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 46,
      height: 46,
      child: IconButton(
        onPressed: onTap,
        style: IconButton.styleFrom(
          backgroundColor: Colors.black.withValues(alpha: 0.45),
          shape: const CircleBorder(),
        ),
        icon: Icon(icon, color: FlixieColors.light, size: 21),
      ),
    );
  }

  // Retained while the redesigned hero settles; useful for a compact fallback.
  // ignore: unused_element
  Widget _buildShowIntro(BuildContext context, TvShow show) {
    final years = _yearRange(show);
    final meta = <String>[
      if (years.isNotEmpty) years,
      if ((show.numberOfSeasons ?? show.seasons.length) > 0)
        '${show.numberOfSeasons ?? show.seasons.length} Seasons',
      if (show.resolvedEpisodeCount > 0)
        '${show.resolvedEpisodeCount} Episodes',
      if ((show.status ?? '').isNotEmpty) show.status!,
    ];
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = width < 380 ? 34.0 : 38.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          show.name,
          style: TextStyle(
            color: FlixieColors.white,
            fontSize: titleSize,
            fontWeight: FontWeight.w900,
            height: 1.02,
            letterSpacing: 0.1,
          ),
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            meta.join('  •  '),
            style: const TextStyle(
              color: FlixieColors.light,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if ((show.tagline ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildTaglineChip(show.tagline!),
        ],
        if (show.genres.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: show.genres.asMap().entries.map((entry) {
              return GenreChip(
                label: entry.value.toUpperCase(),
                color: _kGenreChipColors[entry.key % _kGenreChipColors.length],
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildTaglineChip(String tagline) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: FlixieColors.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: FlixieColors.secondary.withValues(alpha: 0.45),
          width: 1,
        ),
      ),
      child: Text(
        tagline,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: FlixieColors.secondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSynopsis(BuildContext context, TvShow show) {
    final text = show.overview;
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    final showToggle = text.length > 250;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Overview'),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: _movieCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                maxLines: _showFullOverview ? null : 5,
                overflow: _showFullOverview
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: const TextStyle(
                  color: FlixieColors.light,
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
              if (showToggle)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(
                      () => _showFullOverview = !_showFullOverview,
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: FlixieColors.primary,
                      padding: const EdgeInsets.only(top: 4),
                      minimumSize: Size.zero,
                    ),
                    child: Text(_showFullOverview ? 'Show less' : 'Show more'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: FlixieColors.white,
            fontWeight: FontWeight.bold,
          ),
    );
  }

  BoxDecoration _movieCardDecoration() {
    return BoxDecoration(
      color: FlixieColors.surface.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
    );
  }

  static const List<Color> _kGenreChipColors = [
    FlixieColors.primary,
    FlixieColors.secondary,
    FlixieColors.tertiary,
    FlixieColors.warning,
  ];

  Widget _buildShowInfoSection(BuildContext context, TvShow show) {
    final crew = _crew.isNotEmpty ? _crew : show.crew;
    final directors = crew
        .where(
            (credit) => (credit.role ?? '').toLowerCase().contains('director'))
        .map((credit) => credit.name)
        .toSet()
        .toList();
    final writers = crew
        .where((credit) => (credit.role ?? '').toLowerCase().contains('writer'))
        .map((credit) => credit.name)
        .toSet()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Show Info'),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: _movieCardDecoration(),
          child: Wrap(
            runSpacing: 12,
            children: [
              _InfoCell(label: 'Status', value: show.status),
              _InfoCell(
                  label: 'First Air Date',
                  value: _dateLabel(show.firstAirDate)),
              _InfoCell(
                  label: 'Last Air Date', value: _dateLabel(show.lastAirDate)),
              _InfoCell(
                  label: 'Language',
                  value: show.originalLanguage?.toUpperCase()),
              _InfoCell(label: 'Country', value: show.originCountry.join(', ')),
              _InfoCell(label: 'Network', value: show.networks.join(', ')),
              _InfoCell(label: 'Created By', value: show.createdBy.join(', ')),
              _InfoCell(label: 'Directors', value: directors.join(', ')),
              _InfoCell(label: 'Writers', value: writers.join(', ')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCastSection(BuildContext context, TvShow show) {
    final cast = _cast.isNotEmpty ? _cast : show.cast;
    if (cast.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Top Cast'),
        const SizedBox(height: 12),
        SizedBox(
          height: 188,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cast.take(12).length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) => _CastTile(
              credit: cast[index],
              onTap: cast[index].id <= 0
                  ? null
                  : () => context.push('/people/${cast[index].id}'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSimilarSection(BuildContext context, TvShow show) {
    if (show.similarShows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'More Like This'),
        const SizedBox(height: 12),
        SizedBox(
          height: 210,
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
      ],
    );
  }

  Widget _buildSeasonsAndEpisodesSection(TvShow show) {
    if (show.seasons.isEmpty) {
      return const SizedBox.shrink();
    }

    final seasonNumber = _selectedSeasonNumber ??
        (show.seasons.isNotEmpty ? show.seasons.first.seasonNumber : 1);
    final selectedSeason = show.seasons
        .where((season) => season.seasonNumber == seasonNumber)
        .firstOrNull;
    final episodes = show.episodesForSeason(seasonNumber);
    final seasonComplete = selectedSeason != null &&
        selectedSeason.resolvedEpisodeCount > 0 &&
        selectedSeason.watchedEpisodeCount >=
            selectedSeason.resolvedEpisodeCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSectionHeader(context, 'Seasons & Episodes'),
            ),
            const SizedBox(width: 12),
            Text(
              '${show.seasons.length} ${show.seasons.length == 1 ? 'season' : 'seasons'}',
              style: const TextStyle(
                color: FlixieColors.primaryTint,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (show.seasons.length > 1) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.swipe_left_alt_rounded,
                color: FlixieColors.medium,
                size: 20,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 214,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: show.seasons.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final season = show.seasons[index];
              final selected = season.seasonNumber == seasonNumber;
              return _SeasonCard(
                season: season,
                selected: selected,
                isUpdating:
                    _updatingSeasonNumbers.contains(season.seasonNumber),
                onMarkWatched: () => _setSeasonWatched(season, true),
                onMarkUnwatched: () => _setSeasonWatched(season, false),
                onTap: () => setState(
                  () => _selectedSeasonNumber = season.seasonNumber,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: _movieCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SeasonSelectorButton(
                      label: 'Season $seasonNumber',
                      onTap: () => _showSeasonPicker(show, seasonNumber),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (selectedSeason != null)
                    _CompactPillButton(
                      icon: seasonComplete
                          ? Icons.check_circle
                          : Icons.check_circle_outline,
                      label: seasonComplete ? 'Unwatch' : 'Watch all',
                      onTap: () =>
                          _setSeasonWatched(selectedSeason, !seasonComplete),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (episodes.isEmpty)
                const Text(
                  'No episodes available yet.',
                  style: TextStyle(color: FlixieColors.medium),
                )
              else
                ...episodes.take(12).map((episode) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _EpisodeCard(
                        episode: episode,
                        isUpdating: _updatingEpisodeIds.contains(episode.id),
                        onOpen: () => _showEpisodeSheet(episode),
                        onToggleWatched: () =>
                            _setEpisodeWatched(episode, !episode.watched),
                      ),
                    )),
            ],
          ),
        ),
      ],
    );
  }

  bool _isReleased(TvEpisode episode) {
    return TvShowEpisodeProgress(_show!).isReleased(episode);
  }

  Widget _buildEpisodeProgressBanner(TvShow show) {
    final progress = TvShowEpisodeProgress(show);
    final watchedCount = progress.watchedCount;
    final total = progress.releasedCount;
    final next = progress.nextReleased;
    final scheduled = progress.nextScheduled;
    final ended = (show.status ?? '').toLowerCase().contains('ended') ||
        (show.status ?? '').toLowerCase().contains('cancel');
    final complete = total > 0 && watchedCount >= total;
    final currentSeason = next?.seasonNumber;
    final seasonRemaining = currentSeason == null
        ? 0
        : progress.releasedEpisodes
            .where((episode) =>
                episode.seasonNumber == currentSeason && !episode.watched)
            .length;
    final title = watchedCount == 0
        ? 'Not started yet'
        : complete
            ? (ended ? 'Series completed' : 'You’re all caught up')
            : '$watchedCount of $total episodes watched';
    final subtitle = watchedCount == 0
        ? '$total released ${total == 1 ? 'episode' : 'episodes'} available'
        : complete
            ? scheduled == null
                ? '$watchedCount episodes watched'
                : 'Next episode ${_dateLabel(scheduled.airDate)}'
            : currentSeason == null
                ? '${total - watchedCount} released episodes remaining'
                : 'Season $currentSeason  ·  $seasonRemaining ${seasonRemaining == 1 ? 'episode' : 'episodes'} remaining';
    final actionLabel = next == null
        ? 'View episodes'
        : '${watchedCount == 0 ? 'Start' : 'Continue'} S${next.seasonNumber} E${next.episodeNumber}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final status = Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: complete
                    ? FlixieColors.success
                    : FlixieColors.primary.withValues(alpha: .18),
                shape: BoxShape.circle,
              ),
              child: Icon(
                complete ? Icons.check_rounded : Icons.play_arrow_rounded,
                color:
                    complete ? FlixieColors.background : FlixieColors.primary,
                size: 25,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(title,
                        maxLines: 1,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(subtitle,
                        maxLines: 1,
                        style: const TextStyle(
                            color: FlixieColors.light,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          ],
        );
        final action = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: compact ? double.infinity : 150,
              child: FilledButton(
                onPressed: () {
                  if (next != null) {
                    _showEpisodeSheet(next);
                  } else {
                    setState(() => _selectedTab = _ShowDetailTab.episodes);
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: FlixieColors.primary,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                  shape: const StadiumBorder(),
                ),
                child: Text(actionLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w900)),
              ),
            ),
            if (next != null) ...[
              const SizedBox(height: 5),
              SizedBox(
                width: compact ? double.infinity : 150,
                child: Text(
                  [next.name, if (next.runtime != null) '${next.runtime}m']
                      .join('  ·  '),
                  maxLines: 2,
                  softWrap: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: FlixieColors.medium, fontSize: 10.5, height: 1.2),
                ),
              ),
            ],
          ],
        );
        return Column(
          children: [
            if (compact) ...[
              status,
              const SizedBox(height: 12),
              action,
            ] else
              Row(children: [
                Expanded(child: status),
                const SizedBox(width: 14),
                action,
              ]),
            if (total > 0) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: compact ? 1 : .58,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: watchedCount / total,
                      minHeight: 5,
                      backgroundColor: Colors.white.withValues(alpha: .08),
                      valueColor:
                          const AlwaysStoppedAnimation(FlixieColors.primary),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      }),
    );
  }

  Widget _buildNextEpisode(TvShow show) {
    final progress = TvShowEpisodeProgress(show);
    final episode = progress.nextReleased ?? progress.nextScheduled;
    if (episode == null) return const SizedBox.shrink();
    final released = _isReleased(episode);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildSectionHeader(
          context, released ? 'Next episode' : 'Upcoming episode'),
      const SizedBox(height: 10),
      Container(
          decoration: _movieCardDecoration(),
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            SizedBox(
                width: 138,
                child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: _EpisodeStill(path: episode.stillPath)))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      'S${episode.seasonNumber} E${episode.episodeNumber} · ${episode.name}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text(
                      [
                        if (!released) _dateLabel(episode.airDate),
                        if (episode.runtime != null) '${episode.runtime}m'
                      ]
                          .whereType<String>()
                          .where((value) => value.isNotEmpty)
                          .join(' · '),
                      style: const TextStyle(
                          color: FlixieColors.medium, fontSize: 12)),
                  TextButton(
                      onPressed: () => _showEpisodeSheet(episode),
                      child: const Text('Episode details')),
                ])),
          ])),
    ]);
  }

  Widget _buildSeasonOverview(TvShow show) {
    if (show.seasons.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: _buildSectionHeader(context, 'Seasons')),
        TextButton(
            onPressed: () =>
                setState(() => _selectedTab = _ShowDetailTab.episodes),
            child: const Text('View all')),
      ]),
      const SizedBox(height: 8),
      SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: show.seasons.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final season = show.seasons[index];
              final total = season.resolvedEpisodeCount;
              final complete = total > 0 && season.watchedEpisodeCount >= total;
              return InkWell(
                onTap: () => setState(() {
                  _selectedSeasonNumber = season.seasonNumber;
                  _selectedTab = _ShowDetailTab.episodes;
                }),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                    width: 190,
                    padding: const EdgeInsets.all(8),
                    decoration: _movieCardDecoration(),
                    child: Row(children: [
                      SizedBox(
                          width: 62,
                          child: AspectRatio(
                              aspectRatio: 2 / 3,
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(7),
                                  child:
                                      _ShowPoster(path: season.posterPath)))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(
                                season.seasonNumber == 0
                                    ? 'Specials'
                                    : season.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 5),
                            Text('$total episodes',
                                style: const TextStyle(
                                    color: FlixieColors.medium, fontSize: 12)),
                            const SizedBox(height: 7),
                            Text(
                                complete
                                    ? 'Watched'
                                    : '${season.watchedEpisodeCount} of $total watched',
                                style: TextStyle(
                                    color: complete
                                        ? FlixieColors.success
                                        : FlixieColors.primary,
                                    fontSize: 11)),
                          ])),
                    ])),
              );
            },
          )),
    ]);
  }

  void _showEpisodeSheet(TvEpisode episode) {
    final still = _tmdbImage(episode.stillPath, 'w780');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlixieColors.background,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.68,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (_, scrollController) {
            return ListView(
              controller: scrollController,
              padding: EdgeInsets.zero,
              children: [
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: still == null
                          ? const ColoredBox(color: FlixieColors.surface)
                          : CachedNetworkImage(
                              imageUrl: still,
                              fit: BoxFit.cover,
                            ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.08),
                              FlixieColors.background.withValues(alpha: 0.92),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.32),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 14,
                      right: 12,
                      child: IconButton.filled(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.42),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Season ${episode.seasonNumber} · Episode ${episode.episodeNumber}',
                        style: const TextStyle(
                          color: FlixieColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        episode.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          height: 1.08,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _EpisodeInfoChip(
                            icon: Icons.calendar_month_rounded,
                            label: _dateLabel(episode.airDate),
                          ),
                          if (episode.runtime != null)
                            _EpisodeInfoChip(
                              icon: Icons.schedule_rounded,
                              label: '${episode.runtime}m',
                            ),
                          if (episode.voteAverage != null)
                            _EpisodeInfoChip(
                              icon: Icons.star_rounded,
                              label:
                                  '${episode.voteAverage!.toStringAsFixed(1)}/10',
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _CompactPillButton(
                        icon: episode.watched
                            ? Icons.check_circle
                            : Icons.check_circle_outline,
                        label:
                            episode.watched ? 'Mark unwatched' : 'Mark watched',
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _setEpisodeWatched(episode, !episode.watched);
                        },
                      ),
                      if ((episode.overview ?? '').isNotEmpty) ...[
                        const SizedBox(height: 22),
                        const Text(
                          'Overview',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          episode.overview!,
                          style: const TextStyle(
                            color: FlixieColors.light,
                            fontSize: 15,
                            height: 1.42,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSeasonPicker(TvShow show, int selectedSeasonNumber) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: FlixieColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Select season',
                  style: TextStyle(
                    color: FlixieColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: show.seasons.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: FlixieColors.tabBarBorder),
                    itemBuilder: (context, index) {
                      final season = show.seasons[index];
                      final selected =
                          season.seasonNumber == selectedSeasonNumber;
                      final total = season.resolvedEpisodeCount;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Season ${season.seasonNumber}',
                          style: const TextStyle(
                            color: FlixieColors.light,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          total == 0
                              ? 'Episode data unavailable'
                              : '${season.watchedEpisodeCount}/$total watched',
                          style: const TextStyle(color: FlixieColors.medium),
                        ),
                        trailing: selected
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: FlixieColors.primary,
                              )
                            : null,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          setState(
                            () => _selectedSeasonNumber = season.seasonNumber,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProviderSection(TvShow show) {
    if (_watchProviders.isEmpty) return const SizedBox.shrink();
    final providers = _providersForTab(_watchProviderTab);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Where to watch'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: FlixieColors.surface.withValues(alpha: .58),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: .12)),
          ),
          child: Row(
            children: _ShowProviderTab.values
                .map((tab) => Expanded(child: _providerTabButton(tab)))
                .toList(growable: false),
          ),
        ),
        const SizedBox(height: 8),
        if (providers.isNotEmpty)
          SizedBox(
            height: 58,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: providers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) =>
                  _buildCompactProviderCard(providers[index]),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            alignment: Alignment.center,
            child: Text(
              'No ${_providerTabLabel(_watchProviderTab).toLowerCase()} options in your region yet.',
              style: const TextStyle(
                color: FlixieColors.medium,
                fontSize: 12,
              ),
            ),
          ),
        if (providers.length > 3)
          SizedBox(
            height: 30,
            child: TextButton(
              onPressed: () => _showAllProviderOptions(providers),
              style: TextButton.styleFrom(
                foregroundColor: FlixieColors.primary,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('All ${providers.length} options'),
            ),
          ),
      ],
    );
  }

  Widget _providerTabButton(_ShowProviderTab tab) {
    final selected = tab == _watchProviderTab;
    return InkWell(
      onTap: () => setState(() => _watchProviderTab = tab),
      borderRadius: BorderRadius.circular(11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? FlixieColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        alignment: Alignment.center,
        child: Text(
          _providerTabLabel(tab),
          style: TextStyle(
            color: selected ? FlixieColors.white : FlixieColors.light,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _providerTabLabel(_ShowProviderTab tab) => switch (tab) {
        _ShowProviderTab.stream => 'Stream',
        _ShowProviderTab.rent => 'Rent',
        _ShowProviderTab.buy => 'Buy',
      };

  List<WatchProvider> _providersForTab(_ShowProviderTab tab) {
    final matching = switch (tab) {
      _ShowProviderTab.stream =>
        _watchProviders.where((provider) => provider.isStreaming),
      _ShowProviderTab.rent =>
        _watchProviders.where((provider) => provider.isRental),
      _ShowProviderTab.buy =>
        _watchProviders.where((provider) => provider.isPurchase),
    };
    return _sortedProviders(_dedupeProviders(matching));
  }

  Iterable<WatchProvider> _dedupeProviders(Iterable<WatchProvider> providers) {
    final byId = <int, WatchProvider>{};
    for (final provider in providers) {
      byId.putIfAbsent(provider.id, () => provider);
    }
    return byId.values;
  }

  List<WatchProvider> _sortedProviders(Iterable<WatchProvider> providers) {
    return providers.toList()
      ..sort((a, b) {
        final aMatches = _userProviderIds.contains(a.id);
        final bMatches = _userProviderIds.contains(b.id);
        if (aMatches != bMatches) return aMatches ? -1 : 1;
        return a.displayPriority.compareTo(b.displayPriority);
      });
  }

  Widget _buildCompactProviderCard(WatchProvider provider) {
    final isUserProvider = _userProviderIds.contains(provider.id);
    final availabilityLabel = switch (_watchProviderTab) {
      _ShowProviderTab.stream => isUserProvider ? 'Included' : 'Subscription',
      _ShowProviderTab.rent => 'Available to rent',
      _ShowProviderTab.buy => 'Available to buy',
    };
    return Container(
      width: 150,
      height: 58,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isUserProvider && _watchProviderTab == _ShowProviderTab.stream
            ? FlixieColors.success.withValues(alpha: .08)
            : FlixieColors.surface.withValues(alpha: .58),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUserProvider && _watchProviderTab == _ShowProviderTab.stream
              ? FlixieColors.success.withValues(alpha: .72)
              : Colors.white.withValues(alpha: .1),
        ),
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
            width: 34,
            height: 34,
            child: provider.logoPath.isEmpty
                ? const ColoredBox(
                    color: FlixieColors.surfaceElevated,
                    child: Icon(Icons.play_circle_outline_rounded,
                        color: FlixieColors.medium),
                  )
                : CachedNetworkImage(
                    imageUrl: provider.logoUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const ColoredBox(
                      color: FlixieColors.surfaceElevated,
                      child: Icon(Icons.play_circle_outline_rounded,
                          color: FlixieColors.medium),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(provider.providerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: FlixieColors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(availabilityLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: FlixieColors.success,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ]),
    );
  }

  void _showAllProviderOptions(List<WatchProvider> providers) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: FlixieColors.background,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_providerTabLabel(_watchProviderTab)} options',
                  style: const TextStyle(
                      color: FlixieColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: providers.map(_buildCompactProviderCard).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
              icon: _userRating != null
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              label: 'Rate',
              badge: _userRating != null ? '${_userRating!}/10' : null,
              color: FlixieColors.tertiary,
              isActive: _userRating != null,
              isLoading: _isRatingLoading,
              onTap: _updatingAction != null || _isRatingLoading
                  ? null
                  : _showRatingSheet,
            ),
          ),
          Expanded(
            child: _statusActionItem(
              icon: _inWatchlist ? Icons.bookmark : Icons.bookmark_outline,
              label: 'Watchlist',
              color: FlixieColors.warning,
              isActive: _inWatchlist,
              isLoading: _updatingAction == _ShowAction.watchlist,
              onTap: _updatingAction != null ? null : _toggleWatchlist,
            ),
          ),
          Expanded(
            child: _statusActionItem(
              icon: _isFavorite ? Icons.favorite : Icons.favorite_outline,
              label: 'Favourite',
              color: FlixieColors.danger,
              isActive: _isFavorite,
              isLoading: _updatingAction == _ShowAction.favorite,
              onTap: _updatingAction != null ? null : _toggleFavorite,
            ),
          ),
          Expanded(
            child: _statusActionItem(
              icon: _myListsContainingShow.isNotEmpty
                  ? Icons.playlist_add_check_rounded
                  : Icons.playlist_add_rounded,
              label: 'List',
              color: FlixieColors.secondary,
              isActive: _myListsContainingShow.isNotEmpty,
              isLoading: _listsContainingShowLoading,
              onTap: _updatingAction != null ? null : _showAddToListSheet,
            ),
          ),
          Expanded(
            child: _statusActionItem(
              icon: Icons.group_add_outlined,
              label: 'Invite',
              color: FlixieColors.primary,
              isActive: false,
              isLoading: false,
              onTap: _updatingAction != null
                  ? null
                  : () => _showSnack('Show invitations are coming soon'),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildListsSection(BuildContext context) {
    final lists = _myListsContainingShow
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
      loading: _listsContainingShowLoading,
      itemLabel: 'titles',
      onEdit: _showAddToListSheet,
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
    final iconColor = isActive ? color : FlixieColors.medium;

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 38,
                  height: 34,
                  child: Center(
                    child: isLoading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(iconColor),
                            ),
                          )
                        : Icon(icon, size: 27, color: iconColor),
                  ),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: 14,
                  child: Text(
                    badge ?? label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isActive ? color : FlixieColors.light,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      height: 1.05,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection(TvShow show) {
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
                          style: const TextStyle(
                            color: Colors.white,
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
                          style: const TextStyle(
                            color: FlixieColors.medium,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: FlixieColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: FlixieColors.success.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Text(
                      percentLabel,
                      style: const TextStyle(
                        color: FlixieColors.success,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : percent,
                  minHeight: 5,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor:
                      const AlwaysStoppedAnimation(FlixieColors.success),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Retained for compatibility with the previous dashboard composition.
  // ignore: unused_element
  Widget _buildShowDashboard(BuildContext context, TvShow show) {
    final score = show.flixieScore ?? show.voteAverage;
    final voteCount = show.voteCount ?? 0;
    final hasCommunityRatings = voteCount > 0 && score != null && score > 0;
    final totalEpisodes = show.resolvedEpisodeCount;
    final watched = _watchedEpisodeCount(show);
    final statusLabel = _isWatched
        ? 'All caught up'
        : _inWatchlist
            ? 'On watchlist'
            : 'Not tracked';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: FlixieColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your show dashboard',
                      style: TextStyle(
                        color: FlixieColors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Ratings, status, and episode progress in one place.',
                      style: TextStyle(
                        color: FlixieColors.medium,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'About FlixScore',
                onPressed: () => _showFlixScoreInfo(context),
                icon: const Icon(
                  Icons.info_outline_rounded,
                  color: FlixieColors.medium,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 520;
              final tiles = [
                _DashboardTile(
                  title: 'FlixScore',
                  value: hasCommunityRatings
                      ? '${score.toStringAsFixed(1)}/10'
                      : '- /10',
                  icon: Icons.star_border_rounded,
                  color: Colors.deepOrangeAccent,
                  onTap: () => _showFlixScoreInfo(context),
                ),
                _DashboardTile(
                  title: 'Ratings',
                  value: _formatVoteCount(voteCount),
                  icon: Icons.people_outline_rounded,
                  color: FlixieColors.tertiary,
                  onTap: () => _showFlixScoreInfo(context),
                ),
                _DashboardTile(
                  title: 'Your rating',
                  value: _userRating != null ? '${_userRating!}/10' : '+ Rate',
                  icon: Icons.star_rounded,
                  color: FlixieColors.warning,
                  onTap: _isRatingLoading ? null : _showRatingSheet,
                ),
                _DashboardTile(
                  title: 'Your status',
                  value: statusLabel,
                  icon: _isWatched
                      ? Icons.check_circle_rounded
                      : _inWatchlist
                          ? Icons.bookmark_rounded
                          : Icons.radio_button_unchecked_rounded,
                  color: _isWatched
                      ? FlixieColors.success
                      : _inWatchlist
                          ? FlixieColors.warning
                          : FlixieColors.medium,
                ),
                _DashboardTile(
                  title: 'Episodes',
                  value: totalEpisodes == 0
                      ? 'No episodes'
                      : '$watched/$totalEpisodes',
                  icon: Icons.tv_rounded,
                  color: FlixieColors.light,
                ),
              ];

              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: tiles
                      .map(
                        (tile) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: tile,
                          ),
                        ),
                      )
                      .toList(),
                );
              }

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tiles
                    .map(
                      (tile) => SizedBox(
                        width: (constraints.maxWidth - 8) / 2,
                        child: tile,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFriendSummary(TvShow show) {
    final summary = _friendSummary ?? show.friendSummary;
    if (summary == null || summary.friendCount == 0) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: _buildSectionHeader(context, 'Friends')),
          TextButton.icon(
            onPressed: summary.friends.isEmpty
                ? null
                : () => _showAllShowFriends(summary),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.chevron_right_rounded, size: 18),
            label: const Text('View all'),
          ),
        ]),
        Text(
          '${summary.friendCount} ${summary.friendCount == 1 ? 'friend' : 'friends'} interacted',
          style: const TextStyle(color: FlixieColors.medium, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: _movieCardDecoration(),
          child: Row(
            children: [
              SizedBox(
                width: 58,
                height: 30,
                child: Stack(
                  children: summary.friends
                      .take(3)
                      .toList()
                      .asMap()
                      .entries
                      .map((entry) => Positioned(
                          left: entry.key * 17,
                          child: _showFriendAvatar(entry.value, 30)))
                      .toList(),
                ),
              ),
              _showFriendMetric(summary.watchedCount, 'watched'),
              _showFriendMetric(summary.ratedCount, 'rated'),
              _showFriendMetric(summary.recommendedCount, 'recommend'),
              _showFriendMetric(summary.watchlistCount, 'watchlist'),
              _showFriendMetric(summary.favouriteCount, 'favourited'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...summary.friends.take(3).map(_buildShowFriendRow),
      ],
    );
  }

  Widget _showFriendMetric(int value, String label) => Expanded(
        child: Column(children: [
          Text('$value',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              style: const TextStyle(color: FlixieColors.medium, fontSize: 9)),
        ]),
      );

  Widget _showFriendAvatar(TvShowFriend friend, double size) =>
      ProfileAvatarView(
        avatar: friend.avatar,
        fallbackText:
            friend.username.isEmpty ? '?' : friend.username[0].toUpperCase(),
        fallbackColor: FlixieColors.primary,
        size: size,
      );

  Widget _buildShowFriendRow(TvShowFriend friend) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: InkWell(
          onTap: friend.userId.isEmpty
              ? null
              : () => context.push('/friends/${friend.userId}'),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: _movieCardDecoration(),
            child: Row(children: [
              _showFriendAvatar(friend, 42),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(friend.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800)),
                    if (friend.watched ||
                        friend.favorited ||
                        friend.onWatchlist ||
                        friend.reviewed) ...[
                      const SizedBox(height: 4),
                      Text(
                          [
                            if (friend.watched) 'Watched',
                            if (friend.favorited) 'Favourite',
                            if (friend.onWatchlist) 'In watchlist',
                            if (friend.reviewed) 'Reviewed',
                          ].join('  ·  '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: FlixieColors.success,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ],
                  ])),
              if (friend.recommends)
                const Icon(Icons.thumb_up_rounded,
                    color: FlixieColors.success, size: 20),
              if (friend.rating != null) ...[
                const SizedBox(width: 12),
                const Icon(Icons.star_rounded,
                    color: FlixieColors.warning, size: 19),
                const SizedBox(width: 3),
                Text('${friend.rating!.toStringAsFixed(0)}/10',
                    style: const TextStyle(
                        color: FlixieColors.light,
                        fontWeight: FontWeight.w700)),
              ],
              const SizedBox(width: 5),
              const Icon(Icons.chevron_right_rounded,
                  color: FlixieColors.primary, size: 20),
            ]),
          ),
        ),
      );

  void _showAllShowFriends(TvShowFriendSummary summary) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: .7,
        minChildSize: .45,
        maxChildSize: .92,
        builder: (context, controller) => Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          decoration: const BoxDecoration(
              color: FlixieColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: FlixieColors.medium,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child: Text('${summary.friendCount} friends interacted',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800))),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded,
                      color: FlixieColors.light)),
            ]),
            Expanded(
                child: ListView(
                    controller: controller,
                    children:
                        summary.friends.map(_buildShowFriendRow).toList())),
          ]),
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

  String _yearRange(TvShow show) {
    final first = _year(show.firstAirDate);
    final last = _year(show.lastAirDate);
    if (first == null) return '';
    if (last == null || last == first) return '$first';
    return '$first - $last';
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  String _formatVoteCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
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

class _ShowScoreBadge extends StatelessWidget {
  const _ShowScoreBadge({required this.show, required this.onTap});

  final TvShow show;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final score = show.flixieScore ?? show.voteAverage;
    final voteCount = show.voteCount ?? 0;
    final hasScore = score != null && score > 0 && voteCount > 0;
    final color = !hasScore
        ? FlixieColors.medium
        : score >= 8
            ? FlixieColors.success
            : score >= 7
                ? FlixieColors.tertiary
                : score >= 6
                    ? FlixieColors.warning
                    : FlixieColors.danger;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.65)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded, color: color, size: 17),
              const SizedBox(width: 6),
              Text(
                hasScore
                    ? '${score.toStringAsFixed(1)}/10'
                    : 'No FlixScore yet',
                style: const TextStyle(
                  color: FlixieColors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'FlixScore',
                style: TextStyle(
                  color: FlixieColors.light,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
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
            (value == null || value!.isEmpty) ? '-' : value!,
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

class _DashboardTile extends StatelessWidget {
  const _DashboardTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: FlixieColors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: FlixieColors.medium,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return tile;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: tile,
      ),
    );
  }
}

class _CompactPillButton extends StatelessWidget {
  const _CompactPillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: FlixieColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: FlixieColors.primary.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: FlixieColors.primary,
                size: 17,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: FlixieColors.primary,
                  fontSize: 13,
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

class _SeasonSelectorButton extends StatelessWidget {
  const _SeasonSelectorButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: FlixieColors.tabBarBackgroundFocused.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FlixieColors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: FlixieColors.primary,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeasonCard extends StatelessWidget {
  const _SeasonCard({
    required this.season,
    required this.selected,
    required this.onTap,
    required this.onMarkWatched,
    required this.onMarkUnwatched,
    required this.isUpdating,
  });

  final TvSeason season;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onMarkWatched;
  final VoidCallback onMarkUnwatched;
  final bool isUpdating;

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
                      onTap: isUpdating
                          ? null
                          : watched
                              ? onMarkUnwatched
                              : onMarkWatched,
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: isUpdating
                            ? const Padding(
                                padding: EdgeInsets.all(8),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: FlixieColors.primary,
                                ),
                              )
                            : Icon(
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
    required this.onOpen,
    required this.onToggleWatched,
    required this.isUpdating,
  });

  final TvEpisode episode;
  final VoidCallback onOpen;
  final VoidCallback onToggleWatched;
  final bool isUpdating;

  @override
  Widget build(BuildContext context) {
    final still = _tmdbImage(episode.stillPath, 'w342');
    final airDate = DateTime.tryParse(episode.airDate ?? '');
    final unreleased = airDate != null && airDate.isAfter(DateTime.now());
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: FlixieColors.tabBarBackgroundFocused.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: SizedBox(
                  width: 94,
                  height: 58,
                  child: still == null
                      ? const ColoredBox(
                          color: _ShowDetailScreenState._background)
                      : CachedNetworkImage(imageUrl: still, fit: BoxFit.cover),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      [
                        _dateLabel(episode.airDate),
                        if (episode.runtime != null) '${episode.runtime}m',
                      ].where((item) => item != '-').join('  •  '),
                      style: const TextStyle(
                        color: _ShowDetailScreenState._textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if ((episode.overview ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        episode.overview!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ShowDetailScreenState._textSecondary,
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                    ],
                    if (unreleased || episode.watchCount > 1) ...[
                      const SizedBox(height: 4),
                      Text(
                        unreleased
                            ? 'Upcoming'
                            : 'Watched ${episode.watchCount} times',
                        style: TextStyle(
                          color: unreleased
                              ? FlixieColors.medium
                              : FlixieColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: unreleased
                    ? 'Available after release'
                    : episode.watched
                        ? 'Mark unwatched'
                        : 'Mark watched',
                child: GestureDetector(
                  onTap: unreleased || isUpdating ? null : onToggleWatched,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: unreleased
                          ? Colors.white.withValues(alpha: 0.02)
                          : episode.watched
                              ? FlixieColors.success.withValues(alpha: 0.14)
                              : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: unreleased
                            ? Colors.white.withValues(alpha: 0.06)
                            : episode.watched
                                ? FlixieColors.success.withValues(alpha: 0.42)
                                : Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: isUpdating
                          ? const SizedBox(
                              key: ValueKey('loading'),
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: FlixieColors.primary,
                              ),
                            )
                          : Icon(
                              unreleased
                                  ? Icons.lock_clock_rounded
                                  : episode.watched
                                      ? Icons.check_rounded
                                      : Icons.radio_button_unchecked_rounded,
                              key: const ValueKey('status'),
                              color: unreleased
                                  ? FlixieColors.medium.withValues(alpha: 0.55)
                                  : episode.watched
                                      ? FlixieColors.success
                                      : FlixieColors.medium,
                              size: 17,
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.chevron_right_rounded,
                color: FlixieColors.medium,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EpisodeInfoChip extends StatelessWidget {
  const _EpisodeInfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: FlixieColors.medium, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: FlixieColors.light,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CastTile extends StatelessWidget {
  const _CastTile({required this.credit, this.onTap});

  final TvShowCredit credit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final image = _tmdbImage(credit.profilePath, 'w185');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
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
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12),
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
      ),
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
              '${show.voteAverage?.toStringAsFixed(1) ?? '-'} • ${show.numberOfSeasons ?? show.seasons.length} Seasons',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Friends Activity',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: FlixieColors.white,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: FlixieColors.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
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
        ),
      ],
    );
  }
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
      _ShowDetailTab.details: 'Details',
    };
    return ColoredBox(
      color: FlixieColors.background,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: FlixieColors.surface.withValues(alpha: .58),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: .12)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(3),
          children: labels.entries.map((entry) {
            final active = entry.key == selected;
            return InkWell(
              onTap: () => onSelected(entry.key),
              borderRadius: BorderRadius.circular(11),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: active ? FlixieColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(entry.value,
                    style: TextStyle(
                      color: active ? Colors.white : FlixieColors.light,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                    )),
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

class _ShowPoster extends StatelessWidget {
  const _ShowPoster({this.path});
  final String? path;

  @override
  Widget build(BuildContext context) {
    final url = _tmdbImage(path, 'w500');
    if (url == null) return const _ImageFallback(icon: Icons.tv_rounded);
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => const _ImageFallback(icon: Icons.tv_rounded),
      errorWidget: (_, __, ___) => const _ImageFallback(icon: Icons.tv_rounded),
    );
  }
}

class _FullScreenShowPoster extends StatelessWidget {
  const _FullScreenShowPoster({required this.show});

  final TvShow show;

  @override
  Widget build(BuildContext context) {
    final url = _tmdbImage(show.posterPath, 'original');
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Hero(
                tag: 'show-poster-${show.id}',
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: url == null
                      ? const _ImageFallback(icon: Icons.tv_rounded)
                      : CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(
                              color: FlixieColors.primary,
                            ),
                          ),
                          errorWidget: (_, __, ___) =>
                              const _ImageFallback(icon: Icons.tv_rounded),
                        ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 12,
              child: IconButton.filledTonal(
                tooltip: 'Close poster',
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: .65),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: Text(
                show.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EpisodeStill extends StatelessWidget {
  const _EpisodeStill({this.path});
  final String? path;

  @override
  Widget build(BuildContext context) {
    final url = _tmdbImage(path, 'w500');
    if (url == null) {
      return const _ImageFallback(icon: Icons.play_circle_outline_rounded);
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) =>
          const _ImageFallback(icon: Icons.play_circle_outline_rounded),
      errorWidget: (_, __, ___) =>
          const _ImageFallback(icon: Icons.play_circle_outline_rounded),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: FlixieColors.surface,
        child: Center(child: Icon(icon, color: FlixieColors.medium, size: 30)),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: FlixieColors.success.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: FlixieColors.success.withValues(alpha: .55)),
        ),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: FlixieColors.success,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      );
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
