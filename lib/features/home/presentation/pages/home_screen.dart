import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/friend_media_interaction.dart';
import 'package:flixie_app/models/watch_request.dart';
import 'package:flixie_app/models/watchlist_movie.dart';
import 'package:flixie_app/models/continue_watching_show.dart';
import 'package:flixie_app/models/user.dart' as models;
import 'package:flixie_app/features/watchlist/presentation/controllers/watchlist_actions_controller.dart';
import 'package:flixie_app/features/social/data/friend_service.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/auth/push_notification_service.dart';
import 'package:flixie_app/features/movies/data/show_service.dart';
import 'package:flixie_app/features/home/data/recommendation_service.dart';
import 'package:flixie_app/features/social/data/request_service.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/group_watch_request.dart';
import 'package:flixie_app/features/social/data/watch_plan_visibility_store.dart';
import 'package:flixie_app/features/home/data/trending_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/core/navigation/tab_refresh_controller.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/core/widgets/flixie_page.dart';
import 'package:flixie_app/core/widgets/flixie_wordmark.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';
import 'package:flixie_app/core/analytics/recommendation_attribution.dart';
import 'package:flixie_app/features/home/presentation/widgets/greeting_header.dart';
import 'package:flixie_app/features/home/presentation/widgets/section_header.dart';
import 'package:flixie_app/features/home/presentation/widgets/continue_watching_carousel.dart';
import 'package:flixie_app/features/home/presentation/widgets/trending_friends_section.dart';
import 'package:flixie_app/features/home/presentation/widgets/personalized_recommendation_card.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/write_review_sheet.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_tile.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/sharing/models/share_card_data.dart';
import 'package:flixie_app/features/sharing/presentation/share_card_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static _HomeSessionSnapshot? _sessionSnapshot;
  // Keep hero carousel concise so primary CTA and dots remain visible above fold.
  static const int _maxHeroCarouselItems = 12;
  static const double _heroViewportFraction = 0.84;

  List<MovieShort> _featuredMovies = [];
  List<MovieShort> _forYouMovies = [];
  List<ContinueWatchingShow> _continueWatchingShows = [];
  List<ActivityListItem> _friendsActivity = [];
  final Map<int, List<FriendMediaInteraction>> _heroFriendInteractions = {};
  bool _showMoreFriendActivity = false;
  final Set<int> _watchlistUpdatesInFlight = <int>{};
  Set<int> _watchlistMovieIds = {};
  int _watchRequestsNeedingResponse = 0;
  List<WatchRequest> _watchPlansToShow = const [];
  bool _isLoading = true;
  bool _isLoadingRecommendations = false;
  String? _error;
  String? _loadedForUserId;
  AuthProvider? _authProvider;
  final WatchlistActionsController _watchlistActions =
      WatchlistActionsController.instance;
  final PageController _heroPageController = PageController(
    viewportFraction: _heroViewportFraction,
  );
  final PageController _forYouPageController = PageController(
    viewportFraction: 0.88,
  );
  final ScrollController _homeScrollController = ScrollController();
  final GlobalKey _forYouSectionKey = GlobalKey();
  bool _recommendationVisibilityCheckScheduled = false;
  int _heroPage = 0;
  int _forYouPage = 0;
  bool _didAttemptSessionRestore = false;
  int _lastActivityVersion = -1;

  // Preserve the ranking returned by the trending endpoint. Recommendations
  // load independently and must not reshuffle an already-visible carousel.
  List<MovieShort> get _heroMovies => _featuredMovies;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authProvider ??= context.read<AuthProvider>();
    if (!_didAttemptSessionRestore) {
      _didAttemptSessionRestore = true;
      _restoreSessionSnapshot();
    }
  }

  @override
  void initState() {
    super.initState();
    // Listen for dbUser becoming available after auth resolves
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authProvider?.addListener(_onAuthChanged);
      TabRefreshController.home.addListener(_onHomeTabRefresh);
      _homeScrollController.addListener(_scheduleRecommendationVisibilityCheck);
      if (_loadedForUserId == null) _loadAll();
    });
  }

  @override
  void dispose() {
    _storeSessionSnapshot();
    _authProvider?.removeListener(_onAuthChanged);
    TabRefreshController.home.removeListener(_onHomeTabRefresh);
    _heroPageController.dispose();
    _forYouPageController.dispose();
    _homeScrollController.dispose();
    super.dispose();
  }

  void _onAuthChanged() {
    final userId = _authProvider?.dbUser?.id;
    if (userId == null) return;
    final activityVersion = _authProvider?.activityVersion ?? -1;
    if (userId != _loadedForUserId || activityVersion != _lastActivityVersion) {
      _lastActivityVersion = activityVersion;
      _loadAll();
    }
  }

  void _onHomeTabRefresh() {
    if (!mounted || !_homeScrollController.hasClients) return;
    unawaited(
      _homeScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _restoreSessionSnapshot() {
    final snapshot = _sessionSnapshot;
    final userId = _authProvider?.dbUser?.id;
    if (snapshot == null || userId == null || snapshot.userId != userId) return;

    _featuredMovies = List.of(snapshot.featuredMovies);
    _forYouMovies = List.of(snapshot.forYouMovies);
    _continueWatchingShows = List.of(snapshot.continueWatchingShows);
    _friendsActivity = List.of(snapshot.friendsActivity);
    _heroFriendInteractions
      ..clear()
      ..addAll(
        snapshot.heroFriendInteractions.map(
          (movieId, interactions) => MapEntry(movieId, List.of(interactions)),
        ),
      );
    _showMoreFriendActivity = snapshot.showMoreFriendActivity;
    _watchlistMovieIds = Set.of(snapshot.watchlistMovieIds);
    _watchRequestsNeedingResponse = snapshot.watchRequestsNeedingResponse;
    _watchPlansToShow = List.of(snapshot.watchPlansToShow);
    _heroPage = snapshot.heroPage;
    _forYouPage = snapshot.forYouPage;
    _loadedForUserId = userId;
    _isLoading = false;
    _isLoadingRecommendations = false;
    _error = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_heroPageController.hasClients && _featuredMovies.isNotEmpty) {
        _heroPageController.jumpToPage(
          _heroPage.clamp(0, _featuredMovies.length - 1),
        );
      }
      if (_forYouPageController.hasClients && _forYouMovies.isNotEmpty) {
        _forYouPageController.jumpToPage(
          _forYouPage.clamp(0, _forYouMovies.length - 1),
        );
      }
      if (_homeScrollController.hasClients) {
        _homeScrollController.jumpTo(
          snapshot.scrollOffset.clamp(
            0,
            _homeScrollController.position.maxScrollExtent,
          ),
        );
      }
      _scheduleRecommendationVisibilityCheck();
    });
  }

  void _storeSessionSnapshot() {
    final userId = _loadedForUserId;
    if (userId == null || _isLoading || _error != null) return;
    _sessionSnapshot = _HomeSessionSnapshot(
      userId: userId,
      featuredMovies: List.of(_featuredMovies),
      forYouMovies: List.of(_forYouMovies),
      continueWatchingShows: List.of(_continueWatchingShows),
      friendsActivity: List.of(_friendsActivity),
      heroFriendInteractions: _heroFriendInteractions.map(
        (movieId, interactions) => MapEntry(movieId, List.of(interactions)),
      ),
      showMoreFriendActivity: _showMoreFriendActivity,
      watchlistMovieIds: Set.of(_watchlistMovieIds),
      watchRequestsNeedingResponse: _watchRequestsNeedingResponse,
      watchPlansToShow: List.of(_watchPlansToShow),
      heroPage: _heroPage,
      forYouPage: _forYouPage,
      scrollOffset:
          _homeScrollController.hasClients ? _homeScrollController.offset : 0,
    );
  }

  Future<void> _refreshAll() =>
      _loadAll(refreshRecommendations: true, showFullLoading: false);

  Future<void> _loadAll({
    bool refreshRecommendations = false,
    bool showFullLoading = true,
  }) async {
    if (showFullLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    final auth = context.read<AuthProvider>();
    if (refreshRecommendations) {
      await auth.refreshUserData();
      if (!mounted) return;
    }
    final user = auth.dbUser;
    logger.d('[HomeScreen] loading, user=${user?.id}');

    _loadedForUserId = user?.id;

    final secondaryLoad = _loadSecondaryContent(
      user,
      refreshRecommendations: refreshRecommendations,
    );

    try {
      final cachedTrending = auth.cachedTrending;
      final trendingFuture = !refreshRecommendations &&
              cachedTrending != null &&
              cachedTrending.isNotEmpty
          ? Future.value(cachedTrending)
          : TrendingService.getTrendingMovies(refresh: refreshRecommendations);
      final trendingMovies = await trendingFuture;

      // The branded boot screen is the loading state. Do not reveal Home and
      // immediately replace sections with more loaders.
      if (showFullLoading || refreshRecommendations) {
        await secondaryLoad;
      } else {
        unawaited(secondaryLoad);
      }
      if (!mounted) return;

      if (showFullLoading) {
        await _precacheInitialHomeImages(trendingMovies);
        if (user != null) {
          await _loadHeroFriendInteractions(trendingMovies, user.id);
        }
      }
      if (context.mounted) {
        setState(() {
          _featuredMovies = trendingMovies;
          _isLoading = false;
        });
        if (user != null && !showFullLoading) {
          unawaited(_loadHeroFriendInteractions(trendingMovies, user.id));
        }
      }
    } catch (e) {
      logger.e('[HomeScreen] load error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Couldn\'t load content. Check your connection.';
        });
      }
    }
  }

  Future<void> _precacheInitialHomeImages(
    List<MovieShort> trendingMovies,
  ) async {
    final paths = <String?>[
      ...trendingMovies.take(2).map((movie) => movie.poster),
      ..._forYouMovies.take(2).map((movie) => movie.poster),
      ..._continueWatchingShows.take(1).map((show) => show.posterPath),
    ];
    final urls = paths
        .whereType<String>()
        .where((path) => path.trim().isNotEmpty)
        .map(
          (path) => path.startsWith('http')
              ? path
              : 'https://image.tmdb.org/t/p/w500$path',
        )
        .toSet();
    if (urls.isEmpty) return;

    await Future.wait(
      urls.map(
        (url) => precacheImage(
          CachedNetworkImageProvider(url),
          context,
        ).catchError((_) {}),
      ),
    ).timeout(const Duration(seconds: 4), onTimeout: () => []);
  }

  Future<void> _loadHeroFriendInteractions(
    List<MovieShort> movies,
    String userId,
  ) async {
    final visibleMovies = movies.take(_maxHeroCarouselItems).toList();
    final results = await Future.wait(
      visibleMovies.map((movie) async {
        try {
          final interactions = await FriendService.getFriendsMovieInteractions(
            userId,
            movie.id,
          );
          return MapEntry(movie.id, interactions);
        } catch (error) {
          logger.w(
            '[HomeScreen] friend interactions unavailable for ${movie.id}: $error',
          );
          return MapEntry(movie.id, <FriendMediaInteraction>[]);
        }
      }),
    ).timeout(
      const Duration(seconds: 4),
      onTimeout: () => visibleMovies
          .map((movie) => MapEntry(movie.id, <FriendMediaInteraction>[]))
          .toList(),
    );
    if (!mounted || _loadedForUserId != userId) return;
    setState(() {
      _heroFriendInteractions
        ..clear()
        ..addEntries(results);
    });
  }

  Future<void> _loadSecondaryContent(
    models.User? user, {
    bool refreshRecommendations = false,
  }) async {
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _friendsActivity = [];
        _forYouMovies = [];
        _continueWatchingShows = [];
        _watchlistMovieIds = {};
        _watchRequestsNeedingResponse = 0;
        _watchPlansToShow = const [];
        _isLoadingRecommendations = false;
      });
      return;
    }

    if (mounted) setState(() => _isLoadingRecommendations = true);

    final results = await Future.wait([
      FriendService.getFriendsActivityLists(
        user.id,
        days: 30,
        limit: 200,
      ).catchError((_) => <ActivityListItem>[]),
      RecommendationService.getUserRecommendations(
        user.id,
        refresh: refreshRecommendations,
      ).catchError((_) => <MovieShort>[]),
      _watchlistActions
          .getUserWatchlist(user.id)
          .catchError((_) => <WatchlistMovie>[]),
      RequestService.getWatchRequests(
        user.id,
      ).catchError((_) => <WatchRequest>[]),
      ShowService.getContinueWatching(
        user.id,
      ).catchError((_) => <ContinueWatchingShow>[]),
      WatchPlanVisibilityStore.closedPlanIds(user.id)
          .catchError((_) => <String>{}),
      _loadGroupWatchPlansForHome(),
    ]);
    if (!mounted || _loadedForUserId != user.id) return;

    final personalisedForYou = results[1] as List<MovieShort>;
    final watchRequests = results[3] as List<WatchRequest>;
    final groupWatchPlans = results[6] as List<WatchRequest>;
    unawaited(_syncLocalWatchPlanReminders(
      [...watchRequests, ...groupWatchPlans],
      userId: user.id,
    ));
    context.read<AuthProvider>().updateCachedWatchRequests(watchRequests);
    setState(() {
      _friendsActivity = results[0] as List<ActivityListItem>;
      _forYouMovies = personalisedForYou.take(20).toList();
      _watchlistMovieIds = (results[2] as List<WatchlistMovie>)
          .map((item) => item.movieId)
          .toSet();
      _watchRequestsNeedingResponse = _countWatchRequestsNeedingResponse(
        watchRequests,
        user.id,
      );
      _watchPlansToShow = _watchPlansForHome(
        [...watchRequests, ...groupWatchPlans],
        user: user,
        closedPlanIds: results[5] as Set<String>,
      );
      _continueWatchingShows = results[4] as List<ContinueWatchingShow>;
      _isLoadingRecommendations = false;
    });
    _scheduleRecommendationVisibilityCheck();
  }

  Future<void> _syncLocalWatchPlanReminders(
    List<WatchRequest> plans, {
    required String userId,
  }) async {
    for (final plan in plans) {
      final scheduledFor = plan.scheduledFor;
      if (!plan.isWatchRequest || plan.isTerminal || scheduledFor == null ||
          !scheduledFor.isAfter(DateTime.now())) {
        continue;
      }
      final groupName = plan.groupName?.trim();
      final isGroupPlan = groupName?.isNotEmpty == true;
      final otherUser = plan.otherUser(userId);
      await PushNotificationService.scheduleWatchPlanReminders(
        planId: plan.id,
        scheduledFor: scheduledFor,
        title: plan.movie?.title ?? 'Watch together',
        withName: isGroupPlan ? groupName! : otherUser?.username ?? 'your friend',
        deepLink: isGroupPlan && plan.groupId?.isNotEmpty == true
            ? '/groups/${plan.groupId}?tab=plans'
            : '/watch-requests/${plan.id}',
      );
    }
  }

  /// Adapt scheduled group plans to the same homepage card contract used by
  /// direct plans. This keeps their ordering, due-state and card layout truly
  /// identical while preserving a marker for the correct deep link.
  Future<List<WatchRequest>> _loadGroupWatchPlansForHome() async {
    try {
      final groups = await GroupService.getUserGroups(_loadedForUserId ?? '');
      final results =
          await Future.wait(groups.where((group) => group.id != null).map(
        (group) async {
          try {
            final requests =
                await GroupService.getGroupWatchRequests(group.id!);
            return requests
                .map((request) => _asHomeGroupWatchPlan(group, request))
                .toList(growable: false);
          } catch (_) {
            return const <WatchRequest>[];
          }
        },
      ));
      return results.expand((plans) => plans).toList(growable: false);
    } catch (_) {
      return const <WatchRequest>[];
    }
  }

  WatchRequest _asHomeGroupWatchPlan(Group group, GroupWatchRequest request) {
    final currentUserId = _loadedForUserId;
    final currentUserLogged = request.hasCurrentUserCompleted == true ||
        request.memberStatuses.any(
          (member) =>
              member.memberId == currentUserId && member.watchedAt != null,
        );
    final requester = WatchRequestUser(
      id: request.userId,
      username: request.requesterUsername ?? 'Group member',
      avatar: request.requesterAvatar,
    );
    final participants = request.memberStatuses
        .map((member) => WatchRequestParticipant(
              user: WatchRequestUser(
                id: member.memberId,
                username: member.username ?? 'Group member',
                avatar: member.avatar,
              ),
              response: member.status,
            ))
        .toList(growable: false);
    return WatchRequest(
      id: request.id,
      requesterId: request.userId,
      recipientId: '',
      status: request.status.apiValue,
      type: request.mediaType?.toLowerCase() == 'show'
          ? 'SHOW_WATCH_REQUEST'
          : 'MOVIE_WATCH_REQUEST',
      movieId:
          request.mediaType?.toLowerCase() == 'show' ? null : request.mediaId,
      showId:
          request.mediaType?.toLowerCase() == 'show' ? request.mediaId : null,
      createdAt: request.createdAt,
      updatedAt: request.updatedAt,
      scheduledFor: DateTime.tryParse(request.scheduledFor ?? ''),
      location: request.location,
      scheduleStatus: request.scheduledFor == null ? 'NONE' : 'AGREED',
      groupId: group.id,
      groupName: group.name,
      // A private marker lets the shared card open the group plan, not the
      // direct-plan detail route.
      conversationId: '__group_home__',
      selectedCandidateId: request.selectedCandidateId,
      requester: requester,
      createdBy: requester,
      participants: participants,
      watchConfirmations: currentUserLogged && currentUserId != null
          ? [
              WatchConfirmation(
                id: 'group-${request.id}-$currentUserId',
                userId: currentUserId,
                watched: true,
              ),
            ]
          : const [],
      movie: WatchRequestMovieDetails(
        id: request.mediaId ?? 0,
        title: request.movieTitle ?? 'Watch plan',
        posterPath: request.moviePosterPath,
      ),
    );
  }

  void _scheduleRecommendationVisibilityCheck() {
    if (_recommendationVisibilityCheckScheduled || !mounted) return;
    _recommendationVisibilityCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recommendationVisibilityCheckScheduled = false;
      if (!mounted || _forYouMovies.isEmpty) return;

      final sectionContext = _forYouSectionKey.currentContext;
      final renderObject = sectionContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) return;

      final top = renderObject.localToGlobal(Offset.zero).dy;
      final bottom = top + renderObject.size.height;
      final viewportHeight = MediaQuery.sizeOf(context).height;
      final visibleHeight =
          (bottom.clamp(0.0, viewportHeight) - top.clamp(0.0, viewportHeight))
              .clamp(0.0, renderObject.size.height);
      final requiredHeight = renderObject.size.height.clamp(0.0, 160.0) * 0.25;
      if (visibleHeight >= requiredHeight) {
        unawaited(_trackRecommendationImpression(_forYouPage));
      }
    });
  }

  Future<void> _trackRecommendationImpression(int position) async {
    if (position < 0 || position >= _forYouMovies.length) return;
    await context.read<AnalyticsController>().recommendationImpression(
          attribution: RecommendationAttribution.forPersonalisedMovie(
            _forYouMovies[position],
            position: position,
          ),
        );
  }

  Future<void> _openRecommendation(MovieShort movie, int position) async {
    final attribution = RecommendationAttribution.forPersonalisedMovie(
      movie,
      position: position,
    );
    await context.read<AnalyticsController>().recommendationOpened(
          attribution: attribution,
        );
    if (mounted) {
      context.push(
        movieDetailPath(
          movie.id,
          source: DetailSource.justForYou,
          recommendation: attribution,
        ),
      );
    }
  }

  Future<void> _markMovieNotInterested(MovieShort movie) async {
    final messenger = ScaffoldMessenger.of(context);
    final user = context.read<AuthProvider>().dbUser;
    if (user == null) return;

    final originalIndex = _forYouMovies.indexWhere(
      (item) => item.id == movie.id,
    );
    if (originalIndex < 0) return;
    setState(() => _forYouMovies.removeAt(originalIndex));

    try {
      await RecommendationService.markMovieNotInterested(user.id, movie.id);
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('We won\'t recommend ${movie.name} again.'),
            duration: const Duration(seconds: 4),
            persist: false,
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                try {
                  await RecommendationService.removeMovieNotInterested(
                    user.id,
                    movie.id,
                  );
                  if (mounted &&
                      !_forYouMovies.any((item) => item.id == movie.id)) {
                    setState(
                      () => _forYouMovies.insert(
                        originalIndex.clamp(0, _forYouMovies.length),
                        movie,
                      ),
                    );
                  }
                } catch (error) {
                  logger.e('[HomeScreen] undo not-interested error: $error');
                }
              },
            ),
          ),
        );
    } catch (error) {
      logger.e('[HomeScreen] not-interested error: $error');
      if (mounted && !_forYouMovies.any((item) => item.id == movie.id)) {
        setState(
          () => _forYouMovies.insert(
            originalIndex.clamp(0, _forYouMovies.length),
            movie,
          ),
        );
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Couldn\'t update recommendations.')),
      );
    }
  }

  Future<void> _refreshRecommendations() async {
    if (_isLoadingRecommendations) return;
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null || userId.isEmpty) return;

    setState(() => _isLoadingRecommendations = true);
    try {
      final recommendations =
          await RecommendationService.getUserRecommendations(
        userId,
        refresh: true,
      );
      if (!mounted) return;
      setState(() {
        _forYouMovies = recommendations.take(20).toList();
        _forYouPage = 0;
      });
      if (_forYouPageController.hasClients) {
        await _forYouPageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    } catch (error) {
      logger.w('[HomeScreen] recommendation refresh failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Couldn’t refresh your picks. Try again shortly.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingRecommendations = false);
    }
  }

  int _countWatchRequestsNeedingResponse(
    List<WatchRequest> requests,
    String userId,
  ) {
    return requests.where((request) {
      if (!request.isWatchRequest) return false;
      if (request.isPending && request.requesterId != userId) return true;
      final proposal = request.latestPendingProposal;
      if (request.normalizedScheduleStatus == 'PROPOSED' &&
          proposal != null &&
          proposal.proposerId != userId) {
        return true;
      }
      return request.canConfirmWatchedFor(userId);
    }).length;
  }

  List<WatchRequest> _watchPlansForHome(
    List<WatchRequest> requests, {
    required models.User user,
    required Set<String> closedPlanIds,
  }) {
    final now = DateTime.now();
    final plans = requests.where((request) {
      final scheduledFor = request.scheduledFor;
      final isAgreed =
          request.normalizedScheduleStatus == 'AGREED' || request.isScheduled;
      return request.isWatchRequest &&
          isAgreed &&
          !request.isTerminal &&
          scheduledFor != null &&
          !closedPlanIds.contains(request.id) &&
          !_hasLoggedWatchForPlan(user, request) &&
          !_isPlanFullyRated(request) &&
          !scheduledFor.isBefore(now.subtract(const Duration(days: 5)));
    }).toList()
      ..sort(
        (left, right) {
          final leftIsDue = !left.scheduledFor!.isAfter(now);
          final rightIsDue = !right.scheduledFor!.isAfter(now);
          if (leftIsDue != rightIsDue) return leftIsDue ? -1 : 1;
          return left.scheduledFor!.compareTo(right.scheduledFor!);
        },
      );
    return plans.take(10).toList(growable: false);
  }

  bool _isPlanFullyRated(WatchRequest plan) {
    final participantIds = <String>{
      if (plan.requesterId.isNotEmpty) plan.requesterId,
      // Some older/direct API shapes omit the recipient from `participants`.
      // A plan must remain on Home until both sides have rated it.
      if (plan.recipientId.isNotEmpty) plan.recipientId,
      ...plan.participants
          .where(
              (participant) => participant.response.toUpperCase() == 'ACCEPTED')
          .map((participant) => participant.user?.id)
          .whereType<String>(),
    };
    if (participantIds.isEmpty) return false;
    return participantIds.every((userId) => plan.watchConfirmations.any(
          (confirmation) =>
              confirmation.userId == userId && confirmation.rating != null,
        ));
  }

  bool _hasLoggedWatchForPlan(models.User user, WatchRequest plan) {
    // A movie can be watched several times. Only the confirmation attached to
    // this specific plan proves that this particular viewing was logged.
    return plan.watchConfirmations.any(
      (confirmation) => confirmation.userId == user.id && confirmation.watched,
    );
  }

  Future<void> _toggleHeroWatchlist(
    BuildContext context,
    MovieShort movie,
  ) async {
    final authProvider = context.read<AuthProvider>();
    final analytics = context.read<AnalyticsController>();
    final user = authProvider.dbUser;
    if (user == null) {
      context.push(movieDetailPath(movie.id, source: DetailSource.trending));
      return;
    }
    final movieId = movie.id;
    if (_watchlistUpdatesInFlight.contains(movieId)) return;
    final inWatchlist = _watchlistMovieIds.contains(movieId);
    setState(() {
      _watchlistUpdatesInFlight.add(movieId);
      if (inWatchlist) {
        _watchlistMovieIds.remove(movieId);
      } else {
        _watchlistMovieIds.add(movieId);
      }
    });
    try {
      final currentWatchlist = List<WatchlistMovie>.from(
        user.movieWatchlist ?? [],
      );
      if (inWatchlist) {
        await _watchlistActions.removeFromWatchlist(user.id, movieId);
        await analytics.watchlistRemoved(
          contentType: 'movie',
          contentId: movieId,
          source: 'home',
        );
        currentWatchlist.removeWhere((item) => item.movieId == movieId);
      } else {
        final added = await _watchlistActions.addToWatchlist(user.id, movieId);
        await analytics.watchlistAdded(
          contentType: 'movie',
          contentId: movieId,
          source: 'home',
        );
        currentWatchlist.removeWhere((item) => item.movieId == movieId);
        currentWatchlist.add(added);
        authProvider.markActivityChanged();
      }
      authProvider.updateUserList(movieWatchlist: currentWatchlist);
      if (context.mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                inWatchlist
                    ? '${movie.name} removed from your watchlist'
                    : '${movie.name} added to your watchlist',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              duration: const Duration(seconds: 2),
              backgroundColor:
                  inWatchlist ? FlixieColors.surface : FlixieColors.success,
            ),
          );
      }
    } catch (e) {
      logger.e('[HomeScreen] watchlist toggle error: $e');
      if (mounted) {
        setState(() {
          if (inWatchlist) {
            _watchlistMovieIds.add(movieId);
          } else {
            _watchlistMovieIds.remove(movieId);
          }
        });
      }
    } finally {
      if (mounted) setState(() => _watchlistUpdatesInFlight.remove(movieId));
    }
  }

  Future<void> _openHeroTrailer(BuildContext context, MovieShort movie) async {
    final rawUrl = movie.trailer?.key;
    if (rawUrl == null || rawUrl.trim().isEmpty) return;
    final watchUrl = rawUrl.replaceFirst(
      'youtube.com/embed/',
      'youtube.com/watch?v=',
    );
    final uri = Uri.tryParse(watchUrl);
    var opened = false;
    try {
      opened = uri != null &&
          await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error) {
      logger.w('[HomeScreen] trailer launch failed for ${movie.id}: $error');
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t open this trailer.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.watch<AuthProvider>().unreadNotificationCount;
    final user = context.watch<AuthProvider>().dbUser;
    final greetingName = (user?.firstName?.trim().isNotEmpty ?? false)
        ? user!.firstName!.trim()
        : user?.username;
    final heroMovies = _heroMovies;

    return FlixiePageScaffold(
      backgroundColor: FlixieColors.background,
      appBar: AppBar(
        backgroundColor: FlixieColors.background,
        foregroundColor: FlixieColors.light,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: FlixieColors.light),
        actionsIconTheme: const IconThemeData(color: FlixieColors.light),
        title: const FlixieWordmark(),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label:
                  unreadCount < 100 ? Text('$unreadCount') : const Text('99+'),
              backgroundColor: FlixieColors.tertiary,
              textColor: Colors.black,
              child: const Icon(
                Icons.notifications_outlined,
                color: FlixieColors.light,
              ),
            ),
            onPressed: () async {
              final auth = context.read<AuthProvider>();
              await context.push('/notifications');
              // Refresh the badge count once the user returns from the screen
              if (mounted) {
                auth.refreshNotificationCount();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const HomeBootLoadingScreen()
          : _error != null
              ? ErrorRetryWidget(message: _error!, onRetry: _loadAll)
              : RefreshIndicator(
                  color: FlixieColors.primary,
                  backgroundColor: FlixieColors.background,
                  onRefresh: _refreshAll,
                  child: SingleChildScrollView(
                    controller: _homeScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: GreetingHeader(
                            name: greetingName,
                            avatar: user?.avatar,
                            profileBadges: user?.profileBadges ?? const [],
                            requestCount: _watchRequestsNeedingResponse,
                            onSearch: () => context.push('/search'),
                            onWatchlist: () => context.go('/watchlist'),
                            onInvite: () => context.go('/social'),
                            onRequests: () => context.push('/watch-requests'),
                          ),
                        ),
                        _buildUpcomingWatchPlanSection(context, user),
                        if (heroMovies.isNotEmpty) ...[
                          const HomeSectionHeader(title: 'Trending now'),
                          const SizedBox(height: 4),
                          _buildHeroCarousel(context, heroMovies),
                          const SizedBox(height: 10),
                          _buildCarouselDots(heroMovies),
                          const SizedBox(height: 20),
                        ],
                        _buildBecauseYouRatedSection(context),
                        _buildContinueWatchingSection(context),
                        if (_isLoadingRecommendations &&
                            _friendsActivity.isEmpty)
                          _buildPosterRailLoadingState('Friends watching')
                        else
                          FriendsWatchingSection(activity: _friendsActivity),
                        _buildFriendActivitySection(context),
                        _buildWatchlistSection(context),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildContinueWatchingSection(BuildContext context) {
    if (_isLoadingRecommendations && _continueWatchingShows.isEmpty) {
      return _buildPosterRailLoadingState('Continue Watching');
    }
    if (_continueWatchingShows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionHeader(title: 'Continue Watching'),
        const SizedBox(height: 12),
        ContinueWatchingCarousel(
          shows: _continueWatchingShows,
          onTap: (show) => context.push(showDetailPath(show.showId)),
          onRemove: _removeContinueWatchingShow,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _removeContinueWatchingShow(ContinueWatchingShow show) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) return;
    final index = _continueWatchingShows.indexWhere(
      (item) => item.showId == show.showId,
    );
    if (index < 0) return;

    setState(() => _continueWatchingShows.removeAt(index));
    try {
      await ShowService.dismissContinueWatching(userId, show.showId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${show.name} removed from Continue Watching')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final restoredIndex = index.clamp(0, _continueWatchingShows.length);
        _continueWatchingShows.insert(restoredIndex, show);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove that show right now')),
      );
    }
  }

  // ── Hero carousel ──────────────────────────────────────────────────────────

  Widget _buildHeroCarousel(BuildContext context, List<MovieShort> movies) {
    final count = movies.length.clamp(0, _maxHeroCarouselItems);
    return SizedBox(
      height: 560,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: PageView.builder(
              controller: _heroPageController,
              padEnds: false,
              clipBehavior: Clip.none,
              onPageChanged: (i) => setState(() => _heroPage = i),
              itemCount: count,
              itemBuilder: (context, index) {
                final posterCard = _buildInactiveHeroCard(
                  context,
                  movies[index],
                );
                final detailCard = _buildHeroCard(context, movies[index]);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: AnimatedBuilder(
                    animation: _heroPageController,
                    builder: (context, _) {
                      // A preserved Home tab can briefly coexist with the
                      // incoming post-signup tree. `page` may only be read
                      // when exactly one PageView is attached.
                      final page = _heroPageController.positions.length == 1
                          ? (_heroPageController.page ?? _heroPage.toDouble())
                          : _heroPage.toDouble();
                      // With padEnds disabled a partial-width PageView cannot
                      // physically scroll all the way to the final page index.
                      // Without this, the last card's detail layer settles
                      // slightly transparent over its poster-only layer.
                      const trailingPageOffset =
                          (1 - _heroViewportFraction) / _heroViewportFraction;
                      final isAtTrailingEdge = index == count - 1 &&
                          page >= index - trailingPageOffset - 0.001;
                      final detailOpacity = isAtTrailingEdge
                          ? 1.0
                          : (1 - (page - index).abs()).clamp(0.0, 1.0);
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          posterCard,
                          IgnorePointer(
                            ignoring: detailOpacity < 0.98,
                            child: Opacity(
                              opacity: detailOpacity,
                              child: detailCard,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselDots(List<MovieShort> movies) {
    final count = movies.length.clamp(0, _maxHeroCarouselItems);
    if (count <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: i == _heroPage ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: i == _heroPage
                ? FlixieColors.primary
                : Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, MovieShort movie) {
    final inWatchlist = _watchlistMovieIds.contains(movie.id);
    final isUpdating = _watchlistUpdatesInFlight.contains(movie.id);
    final friendActivityLoading = context.read<AuthProvider>().dbUser != null &&
        !_heroFriendInteractions.containsKey(movie.id);
    final interactions = _heroFriendInteractions[movie.id] ?? const [];
    final watchlistedBy =
        interactions.where((interaction) => interaction.onWatchlist).toList();
    final favouritedBy =
        interactions.where((interaction) => interaction.favourited).toList();
    final posterHeight = movie.name.length <= 20 ? 375.0 : 350.0;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: FlixieColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        onTap: () => context.push(
          movieDetailPath(movie.id, source: DetailSource.trending),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: posterHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (movie.poster != null)
                    Stack(
                      fit: StackFit.expand,
                      children: [
                        ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                          child: CachedNetworkImage(
                            imageUrl:
                                'https://image.tmdb.org/t/p/w780${movie.poster}',
                            fit: BoxFit.cover,
                            color: Colors.black.withValues(alpha: 0.38),
                            colorBlendMode: BlendMode.darken,
                            errorWidget: (_, __, ___) => _heroFallback(),
                          ),
                        ),
                        Center(
                          child: FractionallySizedBox(
                            widthFactor: 0.62,
                            heightFactor: 1,
                            child: ClipRect(
                              child: CachedNetworkImage(
                                imageUrl:
                                    'https://image.tmdb.org/t/p/w780${movie.poster}',
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                                errorWidget: (_, __, ___) => _heroFallback(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    _heroFallback(),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                movie.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  height: 1.08,
                                ),
                              ),
                              if ((movie.releaseDate ?? '').isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _formatHeroDate(movie.releaseDate!),
                                  style: const TextStyle(
                                    color: FlixieColors.medium,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        _HeroCompactIconButton(
                          tooltip: inWatchlist
                              ? 'Remove from watchlist'
                              : 'Watchlist',
                          icon: inWatchlist
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_outline_rounded,
                          foregroundColor: FlixieColors.warning,
                          isBusy: isUpdating,
                          onPressed: () => _toggleHeroWatchlist(context, movie),
                        ),
                      ],
                    ),
                    if ((movie.overview ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        movie.overview!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FlixieColors.light,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        if ((movie.voteAverage ?? 0) > 0) ...[
                          const Icon(
                            Icons.star_rounded,
                            color: FlixieColors.warning,
                            size: 19,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            movie.voteAverage!.toStringAsFixed(1),
                            style: const TextStyle(
                              color: FlixieColors.warning,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ] else ...[
                          const Icon(
                            Icons.star_outline_rounded,
                            color: FlixieColors.medium,
                            size: 19,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Not rated yet',
                            style: TextStyle(
                              color: FlixieColors.medium,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        if ((movie.trailer?.key ?? '').trim().isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Container(
                            width: 1,
                            height: 22,
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                          const SizedBox(width: 10),
                          TextButton.icon(
                            onPressed: () => _openHeroTrailer(context, movie),
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: 18,
                            ),
                            label: const Text('Trailer'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              side: BorderSide(
                                color: Colors.redAccent.withValues(alpha: 0.35),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 6),
                        _HeroCompactIconButton(
                          tooltip: 'Details',
                          icon: Icons.info_outline_rounded,
                          foregroundColor: FlixieColors.light,
                          onPressed: () => context.push(
                            movieDetailPath(
                              movie.id,
                              source: DetailSource.trending,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    if (watchlistedBy.isNotEmpty || favouritedBy.isNotEmpty)
                      Row(
                        children: [
                          if (watchlistedBy.isNotEmpty)
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.bookmark_rounded,
                                    color: FlixieColors.warning,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  _FriendInteractionAvatarStack(
                                    interactions: watchlistedBy,
                                  ),
                                ],
                              ),
                            )
                          else
                            const Spacer(flex: 2),
                          if (watchlistedBy.isNotEmpty &&
                              favouritedBy.isNotEmpty) ...[
                            Container(
                              width: 1,
                              height: 30,
                              color: Colors.white.withValues(alpha: 0.16),
                            ),
                            const SizedBox(width: 14),
                          ],
                          if (favouritedBy.isNotEmpty) ...[
                            Expanded(
                              flex: 1,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const Icon(
                                    Icons.favorite_rounded,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: _FriendInteractionAvatarStack(
                                        interactions: favouritedBy,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      )
                    else if (friendActivityLoading)
                      const SizedBox(
                        height: 30,
                        child: Row(
                          children: [
                            SkeletonBox(
                              width: 26,
                              height: 26,
                              borderRadius: 13,
                            ),
                            SizedBox(width: 8),
                            SkeletonBox(width: 132, height: 10),
                          ],
                        ),
                      )
                    else
                      const SizedBox(
                        height: 30,
                        child: Row(
                          children: [
                            Icon(
                              Icons.people_outline_rounded,
                              color: FlixieColors.medium,
                              size: 19,
                            ),
                            SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                'No friends have saved or favourited this yet',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: FlixieColors.medium,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInactiveHeroCard(BuildContext context, MovieShort movie) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: FlixieColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        onTap: () => context.push(
          movieDetailPath(movie.id, source: DetailSource.trending),
        ),
        child: movie.poster != null
            ? CachedNetworkImage(
                imageUrl: 'https://image.tmdb.org/t/p/w780${movie.poster}',
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorWidget: (_, __, ___) => _heroFallback(),
              )
            : _heroFallback(),
      ),
    );
  }

  Widget _heroFallback() {
    return Container(
      color: FlixieColors.tabBarBackgroundFocused,
      child: const Icon(
        Icons.movie_outlined,
        color: FlixieColors.medium,
        size: 48,
      ),
    );
  }

  Widget _buildWatchlistSection(BuildContext context) {
    final user = context.read<AuthProvider>().dbUser;
    final watchlist = user?.movieWatchlist
            ?.where((w) => w.removed != true)
            .take(10)
            .toList() ??
        [];
    if (watchlist.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: 'On Your Watchlist',
          onSeeAll: () => context.go('/watchlist'),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: watchlist.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = watchlist[index];
              final isUpdating = _watchlistUpdatesInFlight.contains(
                item.movieId,
              );
              final posterUrl = item.movie?.posterPath != null
                  ? 'https://image.tmdb.org/t/p/w342${item.movie!.posterPath}'
                  : null;
              return GestureDetector(
                onTap: () => context.push(
                  movieDetailPath(item.movieId, source: DetailSource.watchlist),
                ),
                onLongPress: () => _showQuickMovieActions(
                  context,
                  movieId: item.movieId,
                  movieTitle: item.movie?.title ?? 'Movie',
                  isInWatchlist: true,
                ),
                child: SizedBox(
                  width: 110,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 110,
                              height: 148,
                              child: posterUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: posterUrl,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Container(
                                        color: FlixieColors
                                            .tabBarBackgroundFocused,
                                        child: const Icon(
                                          Icons.movie_outlined,
                                          color: FlixieColors.medium,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color:
                                          FlixieColors.tabBarBackgroundFocused,
                                      child: const Icon(
                                        Icons.movie_outlined,
                                        color: FlixieColors.medium,
                                      ),
                                    ),
                            ),
                          ),
                          Positioned(
                            top: 6,
                            left: 6,
                            child: GestureDetector(
                              onTap: isUpdating
                                  ? null
                                  : () => _toggleWatchlistState(
                                        context,
                                        movieId: item.movieId,
                                        movieTitle:
                                            item.movie?.title ?? 'Movie',
                                        posterPath: item.movie?.posterPath,
                                        currentlyInWatchlist: true,
                                      ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Icon(
                                  Icons.bookmark,
                                  color: isUpdating
                                      ? FlixieColors.medium
                                      : FlixieColors.primary,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: PopupMenuButton<String>(
                              tooltip: 'Quick actions',
                              icon: const Icon(
                                Icons.more_vert_rounded,
                                color: FlixieColors.light,
                                size: 20,
                              ),
                              color: FlixieColors.tabBarBackgroundFocused,
                              onSelected: (value) {
                                _handleQuickActionSelection(
                                  context,
                                  action: value,
                                  movieId: item.movieId,
                                  movieTitle: item.movie?.title ?? 'Movie',
                                  posterPath: item.movie?.posterPath,
                                  isInWatchlist: true,
                                );
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'mark_watched',
                                  child: Text('Mark as watched'),
                                ),
                                PopupMenuItem(
                                  value: 'remove_watchlist',
                                  child: Text('Remove from watchlist'),
                                ),
                                // TODO(release): Restore favourite, list,
                                // invite and share quick actions when their
                                // home-screen flows are implemented.
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.movie?.title ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FlixieColors.light,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildBecauseYouRatedSection(BuildContext context) {
    if (_isLoadingRecommendations && _forYouMovies.isEmpty) {
      return _buildRecommendationsLoadingState();
    }
    if (_forYouMovies.isEmpty) return const SizedBox.shrink();

    final movies = _forYouMovies.take(10).toList(growable: false);
    final activeIndex = _forYouPage.clamp(0, movies.length - 1);

    return Column(
      key: _forYouSectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 4),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: FlixieColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Just for you',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Reload recommendations',
                onPressed:
                    _isLoadingRecommendations ? null : _refreshRecommendations,
                style: IconButton.styleFrom(
                  foregroundColor: FlixieColors.primary,
                  backgroundColor: FlixieColors.primary.withValues(alpha: 0.14),
                  disabledForegroundColor: FlixieColors.medium,
                  disabledBackgroundColor:
                      FlixieColors.surfaceElevated.withValues(alpha: 0.7),
                ),
                icon: _isLoadingRecommendations
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              _isLoadingRecommendations
                  ? 'Building your fresh picks…'
                  : 'Picked from your taste',
              key: ValueKey(_isLoadingRecommendations),
              style: const TextStyle(
                color: FlixieColors.medium,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        SizedBox(
          height: PersonalizedRecommendationCard.height,
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (currentChild, previousChildren) => Stack(
                fit: StackFit.expand,
                children: [
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              ),
              child: _isLoadingRecommendations
                  ? const Padding(
                      key: ValueKey('recommendations-generating'),
                      padding: EdgeInsets.only(right: 10),
                      child: _RecommendationGeneratingCard(),
                    )
                  : PageView.builder(
                      key: const ValueKey('recommendation-cards'),
                      controller: _forYouPageController,
                      padEnds: false,
                      itemCount: movies.length,
                      onPageChanged: (index) {
                        setState(() => _forYouPage = index);
                        _trackRecommendationImpression(index);
                      },
                      itemBuilder: (context, index) {
                        final movie = movies[index];
                        final isBookmarked = _watchlistMovieIds.contains(
                          movie.id,
                        );
                        final isPreviouslyWatched = movie.previouslyWatched ||
                            (context
                                    .read<AuthProvider>()
                                    .dbUser
                                    ?.isMovieWatched(movie.id) ??
                                false);
                        final reasons = isPreviouslyWatched &&
                                !movie.recommendationReasons.any(
                                  (reason) =>
                                      reason.toLowerCase().contains('rewatch'),
                                )
                            ? [
                                'You\'ve watched this before - it may be worth a rewatch',
                                ...movie.recommendationReasons,
                              ]
                            : movie.recommendationReasons;
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: PersonalizedRecommendationCard(
                            movie: movie,
                            reasons: reasons,
                            isBookmarked: isBookmarked,
                            isBookmarkUpdating:
                                _watchlistUpdatesInFlight.contains(movie.id),
                            isPreviouslyWatched: isPreviouslyWatched,
                            onTap: () => _openRecommendation(movie, index),
                            onBookmarkTap: () async {
                              final analytics =
                                  context.read<AnalyticsController>();
                              await _toggleWatchlistState(
                                context,
                                movieId: movie.id,
                                movieTitle: movie.name,
                                posterPath: movie.poster,
                                currentlyInWatchlist: isBookmarked,
                              );
                              if (!isBookmarked &&
                                  _watchlistMovieIds.contains(movie.id) &&
                                  mounted) {
                                await analytics.recommendationSaved(
                                  attribution: RecommendationAttribution
                                      .forPersonalisedMovie(
                                    movie,
                                    position: index,
                                  ),
                                );
                              }
                            },
                            onMarkWatched: () => _openQuickMarkWatchedSheet(
                              context,
                              movieId: movie.id,
                              movieTitle: movie.name,
                              posterPath: movie.poster,
                              isInWatchlist: isBookmarked,
                              isRewatch: isPreviouslyWatched,
                              recommendation: RecommendationAttribution
                                  .forPersonalisedMovie(
                                movie,
                                position: index,
                              ),
                            ),
                            onNotInterested: () =>
                                _markMovieNotInterested(movie),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
        if (!_isLoadingRecommendations && movies.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              movies.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: index == activeIndex ? 22 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: index == activeIndex
                      ? FlixieColors.primary
                      : FlixieColors.mediumShade.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildRecommendationsLoadingState() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(title: 'Just for you'),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: FlixieColors.primary,
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Building your recommendations…',
                style: TextStyle(
                  color: FlixieColors.medium,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: PersonalizedRecommendationCard.height,
          child: Padding(
            padding: EdgeInsets.only(left: 16, right: 10),
            child: SizedBox(
              width: double.infinity,
              child: _RecommendationGeneratingCard(),
            ),
          ),
        ),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _buildUpcomingWatchPlanSection(
    BuildContext context,
    models.User? user,
  ) {
    final plans = _watchPlansToShow;
    if (_isLoadingRecommendations && plans.isEmpty && user != null) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: SkeletonBox(
          width: double.infinity,
          height: 100,
          borderRadius: 14,
        ),
      );
    }
    if (plans.isEmpty || user == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: 'Watch plans',
          onSeeAll: () => context.push('/watch-requests'),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            // Keep plans as a compact horizontal row. Each card owns its
            // natural width. On phones, leave only a small next-card preview
            // to make the horizontal swipe affordance clear.
            final cardWidth = constraints.maxWidth >= 600
                ? 420.0
                : constraints.maxWidth * .90;
            final preferredHeight =
                cardWidth / (constraints.maxWidth >= 600 ? 3.0 : 2.55);
            final viewportCap = MediaQuery.sizeOf(context).height * .34;
            final carouselHeight =
                preferredHeight < viewportCap ? preferredHeight : viewportCap;
            return SizedBox(
              height: carouselHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: plans.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) => SizedBox(
                  width: cardWidth,
                  height: double.infinity,
                  child: _buildWatchPlanCard(context, user, plans[index]),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildWatchPlanCard(
    BuildContext context,
    models.User user,
    WatchRequest plan,
  ) {
    final scheduledFor = plan.scheduledFor!;
    final isPast = !scheduledFor.isAfter(DateTime.now());
    final watchAlreadyLogged = isPast && _hasLoggedWatchForPlan(user, plan);
    final isDue = isPast && !watchAlreadyLogged;
    final other = plan.otherUser(user.id);
    final participants = <WatchRequestUser>[
      ...plan.participants
          .map((participant) => participant.user)
          .whereType<WatchRequestUser>()
          .where((participant) => participant.id != user.id),
      if (other != null) other,
    ]
        .fold(<String, WatchRequestUser>{}, (byId, participant) {
          byId[participant.id] = participant;
          return byId;
        })
        .values
        .toList(growable: false);
    final withLabel = plan.groupName?.trim().isNotEmpty == true
        ? plan.groupName!.trim()
        : other?.username.isNotEmpty == true
            ? other!.username
            : 'Your friends';
    final posterPath = plan.movie?.posterPath;
    final location = plan.location?.trim();
    final isGroupPlan = plan.conversationId == '__group_home__';
    final railColor = isGroupPlan ? FlixieColors.primary : FlixieColors.success;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => plan.conversationId == '__group_home__'
            ? context.push(
                '/groups/${plan.groupId}?tab=requests&requestId=${plan.id}')
            : context.push('/watch-requests/${plan.id}'),
        child: Ink(
          decoration: BoxDecoration(
            color: FlixieColors.surfaceElevated.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: FlixieColors.primary.withValues(alpha: .34)),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: railColor,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(14),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 12, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: AspectRatio(
                        // Movie posters are 2:3 portrait (width : height).
                        // As a direct stretched Row child it fills the card's
                        // available height instead of sizing from its width.
                        aspectRatio: 2 / 3,
                        child: posterPath != null && posterPath.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl:
                                    'https://image.tmdb.org/t/p/w342$posterPath',
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => _heroFallback(),
                              )
                            : _heroFallback(),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: railColor.withValues(alpha: .7)),
                                ),
                                child: Icon(
                                  isGroupPlan
                                      ? Icons.groups_rounded
                                      : Icons.person_outline_rounded,
                                  size: 14,
                                  color: railColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isGroupPlan
                                      ? '$withLabel · ${participants.length + 1} people'
                                      : 'With $withLabel',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: FlixieColors.light,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isDue
                                ? 'Time to log your watch'
                                : watchAlreadyLogged
                                    ? 'Watch logged'
                                    : _watchPlanScheduleHeadline(scheduledFor),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            plan.movie?.title ?? 'Watch plan',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: FlixieColors.medium,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 14),
                          if (location != null && location.isNotEmpty) ...[
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 15,
                                  color: FlixieColors.secondary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    location,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: FlixieColors.light,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isDue || watchAlreadyLogged)
                                  const Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: FlixieColors.success,
                                  )
                                else
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: const BoxDecoration(
                                      color: FlixieColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                const SizedBox(width: 5),
                                Text(
                                  isDue
                                      ? 'Log watch'
                                      : watchAlreadyLogged
                                          ? 'Watch logged'
                                          : _watchPlanScheduleCaption(scheduledFor),
                                  style: TextStyle(
                                    color: isDue || watchAlreadyLogged
                                        ? FlixieColors.success
                                        : FlixieColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (participants.isNotEmpty)
                          _WatchPlanAvatarStack(participants: participants),
                        const Spacer(),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: FlixieColors.light,
                          size: 26,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatWatchPlanDate(DateTime raw) {
    final date = raw.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final dayOffset = target.difference(today).inDays;
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final dayLabel = dayOffset == 0
        ? 'Today'
        : dayOffset == 1
            ? 'Tomorrow'
            : weekdays[date.weekday - 1];
    final displayHour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour < 12 ? 'AM' : 'PM';
    return '$dayLabel · $displayHour:$minute $period';
  }

  String _watchPlanScheduleHeadline(DateTime raw) {
    final date = raw.toLocal();
    final now = DateTime.now();
    final remaining = date.difference(now);
    if (remaining.inMinutes < 60) {
      final minutes = remaining.inMinutes.clamp(1, 59);
      return 'Starts in $minutes min';
    }
    if (remaining.inHours < 6) {
      final hours = remaining.inHours + (remaining.inMinutes % 60 == 0 ? 0 : 1);
      return 'Scheduled in $hours ${hours == 1 ? 'hour' : 'hours'}';
    }
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final dayOffset = target.difference(today).inDays;
    if (dayOffset == 0) return 'Scheduled today';
    if (dayOffset == 1) return 'Scheduled tomorrow';
    return 'Scheduled ${_formatWatchPlanDate(raw)}';
  }

  String _watchPlanScheduleCaption(DateTime raw) {
    final date = raw.toLocal();
    final now = DateTime.now();
    final remaining = date.difference(now);
    if (remaining.inHours < 6) return 'Upcoming';
    final displayHour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour < 12 ? 'AM' : 'PM';
    return '$displayHour:$minute $period';
  }

  Widget _buildFriendActivitySection(BuildContext context) {
    if (_isLoadingRecommendations && _friendsActivity.isEmpty) {
      return _buildActivityLoadingState();
    }
    if (_friendsActivity.isEmpty) return const SizedBox.shrink();
    final previewCount = _showMoreFriendActivity ? 8 : 3;
    final items = _friendsActivity.take(previewCount).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: 'Popular with friends',
          onSeeAll: () => context.push('/friends-activity'),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              for (final item in items) ...[
                ActivityTile(
                  item: item,
                  compact: true,
                  detailSource: DetailSource.friendActivity,
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        if (_friendsActivity.length > 3) ...[
          if (!_showMoreFriendActivity)
            Center(
              child: TextButton.icon(
                onPressed: () => setState(() => _showMoreFriendActivity = true),
                style: TextButton.styleFrom(
                  foregroundColor: FlixieColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                label: Text(
                  'Show ${(_friendsActivity.length - 3).clamp(0, 5)} more',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildPosterRailLoadingState(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(title: title),
        const SizedBox(height: 12),
        const SizedBox(
          height: 180,
          child: Row(
            children: [
              SizedBox(width: 16),
              SkeletonBox(width: 110, height: 148, borderRadius: 11),
              SizedBox(width: 8),
              SkeletonBox(width: 110, height: 148, borderRadius: 11),
              SizedBox(width: 8),
              SkeletonBox(width: 110, height: 148, borderRadius: 11),
              SizedBox(width: 8),
              Expanded(child: SkeletonBox(height: 148, borderRadius: 11)),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildActivityLoadingState() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(title: 'Popular with friends'),
        SizedBox(height: 12),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              SkeletonBox(height: 72, borderRadius: 14),
              SizedBox(height: 10),
              SkeletonBox(height: 72, borderRadius: 14),
              SizedBox(height: 10),
              SkeletonBox(height: 72, borderRadius: 14),
            ],
          ),
        ),
        SizedBox(height: 20),
      ],
    );
  }

  Future<void> _toggleWatchlistState(
    BuildContext context, {
    required int movieId,
    required String movieTitle,
    required String? posterPath,
    required bool currentlyInWatchlist,
  }) async {
    final auth = context.read<AuthProvider>();
    final analytics = context.read<AnalyticsController>();
    final userId = auth.dbUser?.id;
    if (userId == null) return;

    if (_watchlistUpdatesInFlight.contains(movieId)) return;
    final existing = auth.dbUser?.movieWatchlist ?? [];
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _watchlistUpdatesInFlight.add(movieId);
      if (currentlyInWatchlist) {
        _watchlistMovieIds.remove(movieId);
      } else {
        _watchlistMovieIds.add(movieId);
      }
    });
    try {
      if (currentlyInWatchlist) {
        await _watchlistActions.removeFromWatchlist(userId, movieId);
        await analytics.watchlistRemoved(
          contentType: 'movie',
          contentId: movieId,
          source: 'home',
        );
        auth.updateUserList(
          movieWatchlist: existing.where((w) => w.movieId != movieId).toList(),
        );
      } else {
        await _watchlistActions.addToWatchlist(userId, movieId);
        await analytics.watchlistAdded(
          contentType: 'movie',
          contentId: movieId,
          source: 'home',
        );
        final now = DateTime.now().toIso8601String();
        auth.updateUserList(
          movieWatchlist: [
            WatchlistMovie(
              id: 'local-$movieId-$now',
              userId: userId,
              movieId: movieId,
              createdAt: now,
              movie: WatchlistMovieDetails(
                id: movieId,
                title: movieTitle,
                posterPath: posterPath,
              ),
            ),
            ...existing.where((w) => w.movieId != movieId),
          ],
        );
      }
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              currentlyInWatchlist
                  ? '$movieTitle removed from watchlist'
                  : '$movieTitle added to watchlist',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      logger.w('[HomeScreen] watchlist toggle failed: $e');
      if (mounted) {
        setState(() {
          if (currentlyInWatchlist) {
            _watchlistMovieIds.add(movieId);
          } else {
            _watchlistMovieIds.remove(movieId);
          }
        });
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not update watchlist right now')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _watchlistUpdatesInFlight.remove(movieId));
      }
    }
  }

  void _showQuickMovieActions(
    BuildContext context, {
    required int movieId,
    required String movieTitle,
    String? posterPath,
    required bool isInWatchlist,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: FlixieColors.tabBarBackgroundFocused,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.check_circle_outline,
                color: FlixieColors.success,
              ),
              title: const Text('Mark as watched'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openQuickMarkWatchedSheet(
                  context,
                  movieId: movieId,
                  movieTitle: movieTitle,
                  posterPath: posterPath,
                  isInWatchlist: isInWatchlist,
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.bookmark_remove_outlined,
                color: FlixieColors.warning,
              ),
              title: const Text('Remove from watchlist'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _toggleWatchlistState(
                  context,
                  movieId: movieId,
                  movieTitle: movieTitle,
                  posterPath: null,
                  currentlyInWatchlist: true,
                );
              },
            ),
            // TODO(release): Restore favourite, list, invite and share quick
            // actions when their home-screen flows are implemented.
          ],
        ),
      ),
    );
  }

  void _handleQuickActionSelection(
    BuildContext context, {
    required String action,
    required int movieId,
    required String movieTitle,
    String? posterPath,
    required bool isInWatchlist,
  }) {
    switch (action) {
      case 'mark_watched':
        _openQuickMarkWatchedSheet(
          context,
          movieId: movieId,
          movieTitle: movieTitle,
          posterPath: posterPath,
          isInWatchlist: isInWatchlist,
        );
        break;
      case 'remove_watchlist':
        _toggleWatchlistState(
          context,
          movieId: movieId,
          movieTitle: movieTitle,
          posterPath: null,
          currentlyInWatchlist: true,
        );
        break;
    }
  }

  Future<void> _openQuickMarkWatchedSheet(
    BuildContext context, {
    required int movieId,
    required String movieTitle,
    String? posterPath,
    required bool isInWatchlist,
    bool isRewatch = false,
    RecommendationAttribution? recommendation,
  }) async {
    final auth = context.read<AuthProvider>();
    final analytics = context.read<AnalyticsController>();
    final userId = auth.dbUser?.id;
    if (userId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    var writeReview = false;
    var watchSaved = false;
    double? reviewRating;
    bool? reviewRecommended;
    String? shareNote;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RewatchLogSheet(
        isRewatch: isRewatch,
        showReviewOption: true,
        onReviewSelected: (selected) => writeReview = selected,
        onSubmit: ({
          required watchedAt,
          required rating,
          required recommended,
          required notes,
        }) async {
          reviewRating = rating;
          reviewRecommended = recommended;
          shareNote = notes;
          await _watchlistActions.logMovieWatch(
            userId,
            LogMovieWatchRequest(
              movieId: movieId,
              watchedAt: watchedAt,
              rating: rating,
              recommended: recommended,
              notes: notes,
            ),
          );
          await analytics.watchLogged(
            contentType: 'movie',
            contentId: movieId,
            source: recommendation?.source ?? 'home',
          );
          if (recommendation != null) {
            await analytics.recommendationWatched(
              attribution: recommendation,
            );
          }
          if (rating != null) {
            await analytics.ratingAdded(
              contentType: 'movie',
              contentId: movieId,
              source: recommendation?.source ?? 'home',
              recommendation: recommendation,
            );
          }
          if (isInWatchlist) {
            await _watchlistActions.removeFromWatchlist(userId, movieId);
            await analytics.watchlistRemoved(
              contentType: 'movie',
              contentId: movieId,
              source: 'home',
            );
            await analytics.movieRemovedFromWatchlist();
            final currentWatchlist = auth.dbUser?.movieWatchlist ?? [];
            auth.updateUserList(
              movieWatchlist: currentWatchlist
                  .where((entry) => entry.movieId != movieId)
                  .toList(),
            );
          }
          watchSaved = true;
          RecommendationService.invalidateCache(userId: userId);
          auth.markActivityChanged();
          if (mounted) {
            setState(() {
              _forYouMovies.removeWhere((movie) => movie.id == movieId);
              _watchlistMovieIds.remove(movieId);
              if (_forYouMovies.isEmpty) {
                _forYouPage = 0;
              } else {
                _forYouPage = _forYouPage.clamp(
                  0,
                  _forYouMovies.length - 1,
                );
              }
            });
            messenger.showSnackBar(
              SnackBar(content: Text('$movieTitle marked as watched')),
            );
          }
        },
      ),
    );

    if (!mounted || !context.mounted || !watchSaved) return;
    if (writeReview) {
      await showModalBottomSheet<Review>(
        context: this.context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => WriteReviewSheet(
          movieId: movieId,
          userId: userId,
          initialRating: reviewRating,
          initialRecommended: reviewRecommended,
          onSubmitted: (_) {
            auth.invalidateCachedReviews();
            auth.markActivityChanged();
          },
        ),
      );
    }
    if (!mounted) return;
    if (reviewRating != null) {
      final user = auth.dbUser;
      if (user == null) return;
      promptShareCard(
        this.context,
        ShareCardData.rating(
          mediaType: ShareCardMediaType.movie,
          mediaId: movieId,
          title: movieTitle,
          posterPath: posterPath,
          user: user,
          rating: reviewRating!.round(),
          recommended: reviewRecommended,
          note: shareNote,
        ),
      );
    }
  }
}

class _HomeSessionSnapshot {
  const _HomeSessionSnapshot({
    required this.userId,
    required this.featuredMovies,
    required this.forYouMovies,
    required this.continueWatchingShows,
    required this.friendsActivity,
    required this.heroFriendInteractions,
    required this.showMoreFriendActivity,
    required this.watchlistMovieIds,
    required this.watchRequestsNeedingResponse,
    required this.watchPlansToShow,
    required this.heroPage,
    required this.forYouPage,
    required this.scrollOffset,
  });

  final String userId;
  final List<MovieShort> featuredMovies;
  final List<MovieShort> forYouMovies;
  final List<ContinueWatchingShow> continueWatchingShows;
  final List<ActivityListItem> friendsActivity;
  final Map<int, List<FriendMediaInteraction>> heroFriendInteractions;
  final bool showMoreFriendActivity;
  final Set<int> watchlistMovieIds;
  final int watchRequestsNeedingResponse;
  final List<WatchRequest> watchPlansToShow;
  final int heroPage;
  final int forYouPage;
  final double scrollOffset;
}

class _RecommendationGeneratingCard extends StatefulWidget {
  const _RecommendationGeneratingCard();

  @override
  State<_RecommendationGeneratingCard> createState() =>
      _RecommendationGeneratingCardState();
}

class _RecommendationGeneratingCardState
    extends State<_RecommendationGeneratingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FlixieColors.primary.withValues(alpha: 0.18),
            FlixieColors.surfaceElevated,
            FlixieColors.tertiary.withValues(alpha: 0.10),
          ],
        ),
        border: Border.all(color: FlixieColors.primary.withValues(alpha: 0.28)),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final movement = Curves.easeInOut.transform(_controller.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 34,
                top: 68 - (movement * 8),
                child: Transform.rotate(
                  angle: -0.14 + (movement * 0.05),
                  child: const _GeneratingPoster(
                    color: FlixieColors.tertiary,
                    icon: Icons.favorite_rounded,
                  ),
                ),
              ),
              Positioned(
                right: 34,
                top: 68 + (movement * 8),
                child: Transform.rotate(
                  angle: 0.14 - (movement * 0.05),
                  child: const _GeneratingPoster(
                    color: FlixieColors.success,
                    icon: Icons.thumb_up_alt_rounded,
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(0, -10 + (movement * 5)),
                child: Container(
                  width: 88,
                  height: 112,
                  decoration: BoxDecoration(
                    color: FlixieColors.tabBarBackgroundFocused,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: FlixieColors.primary.withValues(alpha: 0.7),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: FlixieColors.primary.withValues(
                          alpha: 0.18 + movement * 0.12,
                        ),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: FlixieColors.primary,
                    size: 38,
                  ),
                ),
              ),
              Positioned(
                top: 46 + (movement * 5),
                left: 112,
                child: const Icon(
                  Icons.star_rounded,
                  color: FlixieColors.tertiary,
                  size: 18,
                ),
              ),
              Positioned(
                top: 52 - (movement * 5),
                right: 108,
                child: const Icon(
                  Icons.auto_awesome,
                  color: FlixieColors.primary,
                  size: 16,
                ),
              ),
              const Positioned(
                left: 20,
                right: 20,
                bottom: 52,
                child: Text(
                  'Mixing your movie magic…',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: FlixieColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Positioned(
                left: 20,
                right: 20,
                bottom: 30,
                child: Text(
                  'Taste, favourites and a little sparkle',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: FlixieColors.medium,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GeneratingPoster extends StatelessWidget {
  const _GeneratingPoster({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      height: 88,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Icon(icon, color: color, size: 25),
    );
  }
}

// Kept temporarily for hot-reload compatibility with older element trees.
// ignore: unused_element
class _ContinueWatchingCard extends StatelessWidget {
  const _ContinueWatchingCard({required this.show, required this.onTap});

  final ContinueWatchingShow show;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cardWidth = (MediaQuery.sizeOf(context).width * 0.46).clamp(
      170.0,
      340.0,
    );
    final episode = show.lastWatchedEpisode;
    final episodeLabel = episode == null
        ? '${show.watchedEpisodes} episodes watched'
        : 'S${episode.seasonNumber} E${episode.episodeNumber}';
    final progress = (show.completionPercent / 100).clamp(0.0, 1.0);
    final imagePath = show.backdropPath ?? show.posterPath;
    final posterUrl =
        imagePath == null ? null : 'https://image.tmdb.org/t/p/w780$imagePath';

    return SizedBox(
      width: cardWidth,
      height: 102,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                posterUrl == null
                    ? _posterFallback()
                    : CachedNetworkImage(
                        imageUrl: posterUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _posterFallback(),
                        errorWidget: (_, __, ___) => _posterFallback(),
                      ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.35, 1],
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.68),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.24),
                      ),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        show.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        episodeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FlixieColors.light,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: Colors.black54,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        FlixieColors.primary,
                      ),
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

  Widget _posterFallback() {
    return Container(
      color: FlixieColors.tabBarBackgroundFocused,
      alignment: Alignment.center,
      child: const Icon(Icons.tv_rounded, color: FlixieColors.medium, size: 38),
    );
  }
}

String _formatHeroDate(String raw) {
  final date = DateTime.tryParse(raw);
  if (date == null) return raw;
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
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class _FriendInteractionAvatarStack extends StatelessWidget {
  const _FriendInteractionAvatarStack({required this.interactions});

  final List<FriendMediaInteraction> interactions;

  @override
  Widget build(BuildContext context) {
    const avatarSize = 30.0;
    const avatarSpacing = 22.0;
    final visible = interactions.take(3).toList(growable: false);
    final overflow = interactions.length - visible.length;
    final itemCount = visible.length + (overflow > 0 ? 1 : 0);
    return SizedBox(
      width: avatarSize + ((itemCount - 1).clamp(0, 3) * avatarSpacing),
      height: avatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < visible.length; index++)
            Positioned(
              left: index * avatarSpacing,
              child: Container(
                width: avatarSize,
                height: avatarSize,
                padding: const EdgeInsets.all(1.5),
                decoration: const BoxDecoration(
                  color: FlixieColors.primary,
                  shape: BoxShape.circle,
                ),
                child: ProfileAvatarView(
                  avatar: visible[index].avatar,
                  fallbackText: visible[index].username.isEmpty
                      ? '?'
                      : visible[index].username[0].toUpperCase(),
                  fallbackColor: FlixieColors.surfaceElevated,
                  size: 27,
                  profileBadges: visible[index].profileBadges,
                ),
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: visible.length * avatarSpacing,
              child: Container(
                width: avatarSize,
                height: avatarSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: FlixieColors.surfaceElevated,
                  shape: BoxShape.circle,
                  border: Border.all(color: FlixieColors.primary, width: 1.5),
                ),
                child: Text(
                  '+$overflow',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WatchPlanAvatarStack extends StatelessWidget {
  const _WatchPlanAvatarStack({required this.participants});

  final List<WatchRequestUser> participants;

  @override
  Widget build(BuildContext context) {
    const size = 28.0;
    const spacing = 19.0;
    final visible = participants.take(2).toList(growable: false);
    final overflow = participants.length - visible.length;
    final count = visible.length + (overflow > 0 ? 1 : 0);
    return SizedBox(
      width: size + ((count - 1).clamp(0, 2) * spacing),
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < visible.length; index++)
            Positioned(
              left: index * spacing,
              child: Container(
                width: size,
                height: size,
                padding: const EdgeInsets.all(1.5),
                decoration: const BoxDecoration(
                  color: FlixieColors.primary,
                  shape: BoxShape.circle,
                ),
                child: ProfileAvatarView(
                  avatar: visible[index].avatar,
                  fallbackText: visible[index].username.isEmpty
                      ? '?'
                      : visible[index].username[0].toUpperCase(),
                  fallbackColor: FlixieColors.surface,
                  size: 25,
                ),
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: visible.length * spacing,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: FlixieColors.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: FlixieColors.primary.withValues(alpha: 0.38),
                  ),
                ),
                child: Text(
                  '+$overflow',
                  style: const TextStyle(
                    color: FlixieColors.primary,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroCompactIconButton extends StatelessWidget {
  const _HeroCompactIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.isBusy = false,
    this.foregroundColor = Colors.white,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isBusy;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.44),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: isBusy ? null : onPressed,
          child: SizedBox(
            width: 36,
            height: 36,
            child: isBusy
                ? _SpinningActionIcon(icon: icon, color: foregroundColor)
                : Icon(icon, color: foregroundColor, size: 22),
          ),
        ),
      ),
    );
  }
}

class _SpinningActionIcon extends StatefulWidget {
  const _SpinningActionIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  State<_SpinningActionIcon> createState() => _SpinningActionIconState();
}

class _SpinningActionIconState extends State<_SpinningActionIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Icon(widget.icon, color: widget.color, size: 22),
    );
  }
}
