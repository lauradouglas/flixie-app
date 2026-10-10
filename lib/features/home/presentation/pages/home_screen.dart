import '../models/home_image_urls.dart';
import '../widgets/home_hero_card.dart';
import '../controllers/home_controller.dart';
import '../controllers/home_watch_plans_controller.dart';
import '../widgets/home_session_updates.dart';
import 'package:flixie_app/core/widgets/flixie_refresh.dart';
import 'package:flixie_app/core/storage/library_image_warmup.dart';
import 'package:flixie_app/features/home/presentation/widgets/home_watchlist_action.dart';
import 'package:flixie_app/core/widgets/flixie_section_header.dart';
import 'package:flixie_app/features/home/presentation/widgets/find_tonights_film_section.dart';
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:flixie_app/core/auth/startup_trace.dart';
import 'package:flixie_app/features/social/data/watch_request_cache.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/models/watch_request.dart';
import 'package:flixie_app/models/watchlist_movie.dart';
import 'package:flixie_app/models/continue_watching_show.dart';
import 'package:flixie_app/models/user.dart' as models;
import 'package:flixie_app/features/watchlist/presentation/controllers/watchlist_actions_controller.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/data/show_service.dart';
import 'package:flixie_app/features/home/data/recommendation_service.dart';
import 'package:flixie_app/features/social/data/watch_plan_visibility_store.dart';
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
import 'package:flixie_app/features/home/presentation/widgets/home_community_section.dart';
import 'package:flixie_app/features/home/presentation/widgets/personalized_recommendation_card.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/write_review_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/watch_request_sheet.dart';
import 'package:flixie_app/features/home/presentation/models/home_watch_plan_state.dart';
import 'package:flixie_app/features/home/presentation/widgets/home_watch_plan_card.dart';
import 'package:flixie_app/features/home/presentation/widgets/watch_plans_introduction_card.dart';
import 'package:flixie_app/features/sharing/models/share_card_data.dart';
import 'package:flixie_app/features/sharing/presentation/share_card_sheet.dart';

class HomeScreen extends StatefulWidget {
  /// Starts an independent screen session in native benchmark fixtures.
  @visibleForTesting
  static void clearSessionSnapshotForTesting() {
    // Test-only bridge preserves the existing native fixture entry point.
    // ignore: invalid_use_of_visible_for_testing_member
    HomeController.clearSessionSnapshotForTesting();
  }

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // Keep hero carousel concise so primary CTA and dots remain visible above fold.
  static const int _maxHeroCarouselItems = HomeController.heroLimit;
  static const double _heroViewportFraction = 0.84;

  late final HomeController _home;
  bool _didCreateController = false;
  final _communityKey = GlobalKey<HomeCommunitySectionState>();
  List<MovieShort> get _featuredMovies => _home.trending.value.data;
  List<MovieShort> get _forYouMovies => _home.recommendations.value.data;
  List<ContinueWatchingShow> get _continueWatchingShows =>
      _home.continueWatching.value.data;
  Set<int> get _watchlistUpdatesInFlight => _home.watchlist.value.data.pending;
  Set<int> get _watchlistMovieIds => _home.watchlist.value.data.ids;
  List<WatchRequest> get _watchPlansToShow => _home.watchPlans.plans;
  bool get _isLoadingWatchPlans => _home.watchPlans.loading;
  bool get _watchPlansLoadFailed => _home.watchPlans.failed;
  bool get _watchPlansIntroDismissed => _home.watchPlans.introductionDismissed;
  bool get _hasUsedWatchPlans => _home.watchPlans.hasUsedPlans;
  bool get _isLoading => _home.trending.value.loading;
  bool get _isLoadingRecommendations => _home.recommendations.value.loading;
  String? get _error => _home.trending.value.error;
  final WatchlistActionsController _watchlistActions =
      WatchlistActionsController.instance;
  final PageController _heroPageController = PageController(
    viewportFraction: _heroViewportFraction,
  );
  final PageController _forYouPageController = PageController(
    viewportFraction: 0.88,
  );
  final ScrollController _watchPlansScrollController = ScrollController();
  final ScrollController _homeScrollController = ScrollController();
  final GlobalKey _forYouSectionKey = GlobalKey();
  bool _recommendationVisibilityCheckScheduled = false;
  final ValueNotifier<int> _heroPage = ValueNotifier(0);
  final ValueNotifier<int> _forYouPage = ValueNotifier(0);
  final ValueNotifier<int> _watchPlansPage = ValueNotifier(0);
  final ValueNotifier<double?> _watchPlansCardHeight = ValueNotifier(null);
  String? _watchPlansHeightSignature;
  bool _tracedPlanFrame = false;

  // Preserve the ranking returned by the trending endpoint. Recommendations
  // load independently and must not reshuffle an already-visible carousel.
  List<MovieShort> get _heroMovies => _featuredMovies;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didCreateController) return;
    _didCreateController = true;
    StartupTrace.mark('home.mounted');
    _home = HomeController(
      auth: context.read<AuthProvider>(),
      watchPlans: HomeWatchPlansController(context.read<WatchRequestCache>()),
      onTrendingReady: (movies, user) {
        if (!mounted) return;
        unawaited(_precacheInitialHomeImages(movies));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          StartupTrace.mark('usable-home-frame');
          if (user != null) unawaited(_warmLibraryImages(user));
        });
      },
    );
    _home.recommendations.addListener(_scheduleRecommendationVisibilityCheck);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    TabRefreshController.watchPlans.addListener(_refreshWatchPlanReminders);
    // Listen for dbUser becoming available after auth resolves
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      TabRefreshController.home.addListener(_onHomeTabRefresh);
      _homeScrollController.addListener(_scheduleRecommendationVisibilityCheck);
      _home.start();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    TabRefreshController.watchPlans.removeListener(_refreshWatchPlanReminders);
    _home.recommendations
        .removeListener(_scheduleRecommendationVisibilityCheck);
    _home.dispose();
    TabRefreshController.home.removeListener(_onHomeTabRefresh);
    _heroPageController.dispose();
    _forYouPageController.dispose();
    _watchPlansScrollController.dispose();
    _homeScrollController.dispose();
    _heroPage.dispose();
    _forYouPage.dispose();
    _watchPlansPage.dispose();
    _watchPlansCardHeight.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(_preloadInitialWatchPlans(context.read<AuthProvider>().dbUser,
          force: false));
    }
  }

  void _refreshWatchPlanReminders() {
    if (mounted) {
      unawaited(_preloadInitialWatchPlans(context.read<AuthProvider>().dbUser));
    }
  }

  void _onHomeTabRefresh() {
    if (!mounted || !_homeScrollController.hasClients) return;
    unawaited(_preloadInitialWatchPlans(context.read<AuthProvider>().dbUser));
    unawaited(
      _homeScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadAll(refreshRecommendations: true, showFullLoading: false),
      if (_communityKey.currentState != null)
        _communityKey.currentState!.refresh(),
    ]);
  }

  Future<void> _loadAll({
    bool refreshRecommendations = false,
    bool showFullLoading = true,
    bool refreshProfile = true,
  }) =>
      _home.load(
          refreshRecommendations: refreshRecommendations,
          showFullLoading: showFullLoading,
          refreshProfile: refreshProfile);

  Future<void> _preloadInitialWatchPlans(models.User? user,
          {bool force = true}) =>
      _home.watchPlans.load(user, force: force);

  String? _libraryImagesWarmedFor;
  Future<void> _warmLibraryImages(models.User user) async {
    if (_libraryImagesWarmedFor == user.id) return;
    _libraryImagesWarmedFor = user.id;
    // Sequential, bounded decoding avoids competing with the Home hero.
    for (final url in libraryPosterWarmupUrls(user)) {
      if (!mounted || context.read<AuthProvider>().dbUser?.id != user.id) {
        return;
      }
      await precacheImage(
          libraryPosterWarmupProvider(
              url, MediaQuery.devicePixelRatioOf(context)),
          context,
          onError: (_, __) {});
    }
  }

  Future<void> _precacheInitialHomeImages(
    List<MovieShort> trendingMovies,
  ) async {
    final urls = homeImageWarmupUrls(
      trending: trendingMovies,
      recommendations: _forYouMovies,
      continueWatching: _continueWatchingShows,
    );
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
        unawaited(_trackRecommendationImpression(_forYouPage.value));
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
    final session = _home.session;
    bool current() => mounted && _home.ownsSession(session);

    final originalIndex = _forYouMovies.indexWhere(
      (item) => item.id == movie.id,
    );
    if (originalIndex < 0) return;
    _home.removeRecommendation(movie.id);

    try {
      await RecommendationService.markMovieNotInterested(user.id, movie.id);
      if (!current()) return;
      messenger
        ..hideCurrentSnackBar()
        ..showFlixieToast(
          FlixieToast(
            type: FlixieToastType.info,
            content: Text('We won\'t recommend ${movie.name} again.'),
            duration: const Duration(seconds: 4),
            persist: false,
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                if (!current()) return;
                try {
                  await RecommendationService.removeMovieNotInterested(
                    user.id,
                    movie.id,
                  );
                  if (current() &&
                      !_forYouMovies.any((item) => item.id == movie.id)) {
                    _home.restoreRecommendation(movie, originalIndex);
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
      if (!current()) return;
      if (current() && !_forYouMovies.any((item) => item.id == movie.id)) {
        _home.restoreRecommendation(movie, originalIndex);
      }
      messenger.showFlixieToast(
        FlixieToast(
            type: FlixieToastType.error,
            content: const Text('Couldn\'t update recommendations.')),
      );
    }
  }

  Future<void> _refreshRecommendations() async {
    final session = _home.session;
    try {
      if (!await _home.refreshRecommendations() ||
          !mounted ||
          !_home.ownsSession(session)) {
        return;
      }
      _forYouPage.value = 0;
      if (_forYouPageController.hasClients) {
        await _forYouPageController.animateToPage(0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic);
      }
    } catch (error) {
      logger.w('[HomeScreen] recommendation refresh failed: $error');
      if (mounted && _home.ownsSession(session)) {
        ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
          type: FlixieToastType.error,
          content:
              const Text('Couldn’t refresh your picks. Try again shortly.'),
        ));
      }
    }
  }

  Future<void> _openHomeWatchPlan(
    HomeWatchPlanState state,
    models.User user,
  ) async {
    // The completed-plan recap is a one-time home prompt. The plan itself is
    // still available from Watch Plans; only this personalised home surface is
    // dismissed after it has been opened.
    if (state.type == HomeWatchPlanStateType.recap) {
      await WatchPlanVisibilityStore.closePlan(user.id, state.plan.id);
      if (mounted) {
        _home.watchPlans.removeRecap(user.id, state.plan.id);
      }
    }

    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    await context.push(state.route);
    if (!mounted) return;
    await _preloadInitialWatchPlans(auth.dbUser);
  }

  Future<void> _toggleHeroWatchlist(
    BuildContext context,
    MovieShort movie,
  ) async {
    final authProvider = context.read<AuthProvider>();
    final analytics = context.read<AnalyticsController>();
    final user = authProvider.dbUser;
    if (user == null) {
      context.push(movieDetailPath(movie.id, source: DetailSource.trending),
          extra: {'title': movie.name, 'poster': movie.poster});
      return;
    }
    final session = _home.session;
    bool current() => mounted && _home.ownsSession(session);
    final movieId = movie.id;
    if (_watchlistUpdatesInFlight.contains(movieId)) return;
    final inWatchlist = _watchlistMovieIds.contains(movieId);
    _home.setWatchlistMembership(movieId, !inWatchlist, pending: true);
    try {
      final currentWatchlist = List<WatchlistMovie>.from(
        user.movieWatchlist ?? [],
      );
      if (inWatchlist) {
        await _watchlistActions.removeFromWatchlist(user.id, movieId);
        if (!current()) return;
        await analytics.watchlistRemoved(
          contentType: 'movie',
          contentId: movieId,
          source: 'home',
        );
        currentWatchlist.removeWhere((item) => item.movieId == movieId);
      } else {
        final added = await _watchlistActions.addToWatchlist(user.id, movieId);
        if (!current()) return;
        await analytics.watchlistAdded(
          contentType: 'movie',
          contentId: movieId,
          source: 'home',
        );
        currentWatchlist.removeWhere((item) => item.movieId == movieId);
        currentWatchlist.add(added);
        if (!current()) return;
        authProvider.markActivityChanged();
      }
      if (!current()) return;
      authProvider.updateUserList(movieWatchlist: currentWatchlist);
      if (current() && context.mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger
          ..hideCurrentSnackBar()
          ..showFlixieToast(
            FlixieToast(
              type: FlixieToastType.success,
              content: Text(
                inWatchlist
                    ? '${movie.name} removed from your watchlist'
                    : '${movie.name} added to your watchlist',
                style: TextStyle(
                  color:
                      inWatchlist ? context.colors.textPrimary : Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              duration: const Duration(seconds: 2),
              backgroundColor:
                  inWatchlist ? context.colors.surface : context.colors.success,
            ),
          );
      }
    } catch (e) {
      logger.e('[HomeScreen] watchlist toggle error: $e');
      if (current()) {
        _home.setWatchlistMembership(movieId, inWatchlist);
      }
    } finally {
      if (current()) _home.finishWatchlistUpdate(movieId);
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
      ScaffoldMessenger.of(context).showFlixieToast(
        FlixieToast(
            type: FlixieToastType.error,
            content: const Text('Couldn’t open this trailer.')),
      );
    }
  }

  Future<void> _openWatchPlanCreation() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.dbUser?.id;
    if (userId == null || userId.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MovieWatchRequestSheet(
        movieId: null,
        movieTitle: null,
        requesterId: userId,
        friends: auth.cachedFriends?.friendships ?? const [],
        onSuccess: () {
          unawaited(WatchPlanVisibilityStore.dismissIntroduction(userId));
          if (mounted) {
            _home.watchPlans.markUsed(userId);
            unawaited(_preloadInitialWatchPlans(auth.dbUser));
          }
        },
        onError: () {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
            type: FlixieToastType.error,
            content: const Text('Could not create the Watch Plan'),
            backgroundColor: context.colors.danger,
          ));
        },
      ),
    );
  }

  Future<void> _dismissWatchPlansIntroduction() async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) return;
    await _home.watchPlans.dismissIntroduction(userId);
  }

  Future<void> _showWatchPlansExplanation() => showFlixiePromptSheet<void>(
        context: context,
        builder: (dialogContext) => FlixiePromptSheetContent(
          title: const Text('Choose together'),
          content: const Text(
            'Add a few movie options, invite a friend or group, then choose the final movie and arrange when and where to watch.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Got it'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _openWatchPlanCreation();
              },
              child: const Text('Make a plan'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final userId =
        context.select<AuthProvider, String?>((auth) => auth.dbUser?.id);
    return FlixiePageScaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.background,
        foregroundColor: context.colors.light,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: context.colors.light),
        actionsIconTheme: IconThemeData(color: context.colors.light),
        title: const FlixieWordmark(),
        actions: [
          HomeWatchlistAction(onPressed: () => context.push('/watchlist')),
          const HomeNotificationAction(),
        ],
      ),
      body: FlixieRefresh(
        color: FlixieColors.primary,
        backgroundColor: context.colors.background,
        onRefresh: _refreshAll,
        child: SingleChildScrollView(
          controller: _homeScrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HomeRefreshStatus(
                  secondaryError: _home.secondaryError,
                  onRetry: () async {
                    await context.read<AuthProvider>().retrySession();
                    if (mounted) await _refreshAll();
                  }),
              const HomeUnreadUpdates(),
              _buildGreetingAndPlans(),
              _buildTrendingSection(),
              if (userId != null)
                FindTonightsFilmSection(onPick: () async {
                  await context.push('/pick-for-us');
                  if (mounted) await _refreshAll();
                }),
              if (userId != null)
                HomeCommunitySection(key: _communityKey, userId: userId),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreetingAndPlans() => Selector<AuthProvider, models.User?>(
        selector: (_, auth) => auth.dbUser,
        builder: (context, user, _) => ListenableBuilder(
          listenable: _home.watchPlans,
          builder: (context, _) {
            final greetingName = (user?.firstName?.trim().isNotEmpty ?? false)
                ? user!.firstName!.trim()
                : user?.username;
            final selected = user == null
                ? null
                : selectHomeWatchPlanState(_watchPlansToShow, user.id);
            final attention = user == null
                ? 0
                : homeWatchPlanAttentionCount(_watchPlansToShow, user.id);
            final showIntro = user != null &&
                !_isLoadingWatchPlans &&
                !_watchPlansLoadFailed &&
                !_hasUsedWatchPlans &&
                !_watchPlansIntroDismissed;
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: GreetingHeader(
                        showShortcuts: false,
                        name: greetingName,
                        avatar: user?.avatar,
                        profileBadges: user?.profileBadges ?? const [],
                        requestCount: attention,
                        onSearch: () => context.push('/search'),
                        onWatchlist: () => context.push('/watchlist'),
                        onInvite: () => context.go('/social'),
                        onRequests: () => context.push('/plans'),
                        featureCard: showIntro
                            ? WatchPlansIntroductionCard(
                                onCreate: _openWatchPlanCreation,
                                onLearnMore: _showWatchPlansExplanation,
                                onDismiss: _dismissWatchPlansIntroduction)
                            : null,
                      )),
                  _buildUpcomingWatchPlanSection(context, user,
                      selectedState: selected, suppressEmptyState: showIntro),
                ]);
          },
        ),
      );

  Widget _buildTrendingSection() => ListenableBuilder(
        listenable: _home.trending,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ListenableBuilder(
              listenable:
                  Listenable.merge([_home.recommendations, _home.watchlist]),
              builder: (context, _) => _buildBecauseYouRatedSection(context)),
          ListenableBuilder(
              listenable: _home.continueWatching,
              builder: (context, _) => _buildContinueWatchingSection(context)),
        ]),
        builder: (context, secondarySections) {
          final movies = _heroMovies;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isLoading && movies.isEmpty)
                  _buildPosterRailLoadingState('Trending now'),
                if (_error != null)
                  ErrorRetryWidget(message: _error!, onRetry: _loadAll),
                if (movies.isNotEmpty) ...[
                  const HomeSectionHeader(title: 'Trending now'),
                  const SizedBox(height: 4),
                  _buildHeroCarousel(context, movies),
                  const SizedBox(height: 10),
                  _buildCarouselDots(movies),
                  const SizedBox(height: 20),
                  secondarySections!,
                ],
              ]);
        },
      );

  Widget _buildContinueWatchingSection(BuildContext context) {
    if (_home.continueWatching.value.loading &&
        _continueWatchingShows.isEmpty) {
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
    final session = _home.session;
    bool current() => mounted && _home.ownsSession(session);
    final index = _continueWatchingShows.indexWhere(
      (item) => item.showId == show.showId,
    );
    if (index < 0) return;

    _home.removeContinueWatching(show.showId);
    try {
      await ShowService.dismissContinueWatching(userId, show.showId);
      if (!mounted || !current()) return;
      ScaffoldMessenger.of(context).showFlixieToast(
        FlixieToast(
            type: FlixieToastType.success,
            content: Text('${show.name} removed from Continue Watching')),
      );
    } catch (_) {
      if (!mounted || !current()) return;
      _home.restoreContinueWatching(show, index);
      ScaffoldMessenger.of(context).showFlixieToast(
        FlixieToast(
            type: FlixieToastType.error,
            content: const Text('Could not remove that show right now')),
      );
    }
  }

  // ── Hero carousel ──────────────────────────────────────────────────────────

  Widget _buildHeroCarousel(BuildContext context, List<MovieShort> movies) {
    final count = movies.length.clamp(0, _maxHeroCarouselItems);
    final visibleMovies = movies.take(count).toList(growable: false);
    final sharedPosterHeight = visibleMovies.fold<double>(
      0,
      (largest, movie) => _heroPosterHeight(movie) > largest
          ? _heroPosterHeight(movie)
          : largest,
    );
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    // Every page reserves the height required by the largest card in this
    // carousel. This keeps card edges and pagination aligned when a title,
    // date, or social row takes more room than its neighbours.
    final carouselHeight = sharedPosterHeight + (220 * textScale);
    return SizedBox(
      height: carouselHeight,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: PageView.builder(
              controller: _heroPageController,
              padEnds: false,
              clipBehavior: Clip.none,
              onPageChanged: (index) {
                _heroPage.value = index;
                unawaited(_home.showHeroPage(index));
              },
              itemCount: count,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: ListenableBuilder(
                    listenable: Listenable.merge([
                      _home.watchlist,
                      _home.friendActivity(movies[index].id),
                    ]),
                    builder: (context, _) => _buildHeroCard(
                        context, movies[index],
                        posterHeight: sharedPosterHeight),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  double _heroPosterHeight(MovieShort movie) => 280.0;

  Widget _buildCarouselDots(List<MovieShort> movies) {
    final count = movies.length.clamp(0, _maxHeroCarouselItems);
    if (count <= 1) return const SizedBox.shrink();
    return ValueListenableBuilder<int>(
      valueListenable: _heroPage,
      builder: (context, page, _) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          count,
          (index) => AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: index == page ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: index == page
                  ? FlixieColors.primary
                  : Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, MovieShort movie,
          {required double posterHeight}) =>
      HomeHeroCard(
        movie: movie,
        posterHeight: posterHeight,
        inWatchlist: _watchlistMovieIds.contains(movie.id),
        isUpdating: _watchlistUpdatesInFlight.contains(movie.id),
        interactions: _home.friendActivity(movie.id).value.data,
        friendActivityLoading: context.read<AuthProvider>().dbUser != null &&
            !_home.friendActivityLoaded(movie.id),
        friendActivityFailed:
            _home.friendActivity(movie.id).value.error != null,
        onOpen: () => context.push(
            movieDetailPath(movie.id, source: DetailSource.trending),
            extra: {'title': movie.name, 'poster': movie.poster}),
        onDetails: () => context
            .push(movieDetailPath(movie.id, source: DetailSource.trending)),
        onWatchlist: () => _toggleHeroWatchlist(context, movie),
        onTrailer: () => _openHeroTrailer(context, movie),
        onFriendsRetry: () => _home.retryFriendActivity(movie),
      );

  Widget _buildBecauseYouRatedSection(BuildContext context) {
    if (_isLoadingRecommendations && _forYouMovies.isEmpty) {
      return _buildRecommendationsLoadingState();
    }
    if (_forYouMovies.isEmpty) return const SizedBox.shrink();

    final movies = _forYouMovies.take(10).toList(growable: false);

    return Column(
      key: _forYouSectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
          child: Row(
            children: [
              const Expanded(child: FlixieSectionHeader(title: 'Just for you')),
              IconButton(
                tooltip: 'Reload recommendations',
                onPressed:
                    _isLoadingRecommendations ? null : _refreshRecommendations,
                style: IconButton.styleFrom(
                  foregroundColor: context.colors.primaryText,
                  backgroundColor: FlixieColors.primary.withValues(alpha: 0.14),
                  disabledForegroundColor: context.colors.medium,
                  disabledBackgroundColor:
                      context.colors.surfaceElevated.withValues(alpha: 0.7),
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
              'Picked from your taste',
              key: ValueKey(_isLoadingRecommendations),
              style: TextStyle(
                color: context.colors.medium,
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
            child: PageView.builder(
              controller: _forYouPageController,
              padEnds: false,
              itemCount: movies.length,
              onPageChanged: (index) {
                _forYouPage.value = index;
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
                          (reason) => reason.toLowerCase().contains('rewatch'),
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
                      final analytics = context.read<AnalyticsController>();
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
                          attribution:
                              RecommendationAttribution.forPersonalisedMovie(
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
                      recommendation:
                          RecommendationAttribution.forPersonalisedMovie(
                        movie,
                        position: index,
                      ),
                    ),
                    onNotInterested: () => _markMovieNotInterested(movie),
                  ),
                );
              },
            ),
          ),
        ),
        if (!_isLoadingRecommendations && movies.length > 1) ...[
          const SizedBox(height: 12),
          ValueListenableBuilder<int>(
            valueListenable: _forYouPage,
            builder: (context, page, _) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                movies.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: index == page ? 22 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: index == page
                        ? FlixieColors.primary
                        : context.colors.mediumShade.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildRecommendationsLoadingState() => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeSectionHeader(title: 'Just for you'),
          Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SkeletonBox(
                  height: PersonalizedRecommendationCard.height,
                  borderRadius: 16)),
          SizedBox(height: 20),
        ],
      );

  Widget _buildUpcomingWatchPlanSection(
    BuildContext context,
    models.User? user, {
    required HomeWatchPlanState? selectedState,
    required bool suppressEmptyState,
  }) {
    final plans = _watchPlansToShow;
    if (plans.isNotEmpty && !_tracedPlanFrame) {
      _tracedPlanFrame = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          StartupTrace.mark('home.plans.first-frame', {'count': plans.length});
        }
      });
    }
    if (_isLoadingWatchPlans && plans.isEmpty && user != null) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeSectionHeader(title: 'Watch together'),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SkeletonBox(
              width: double.infinity,
              height: 116,
              borderRadius: 18,
            ),
          ),
          SizedBox(height: 16),
        ],
      );
    }
    if (user == null || suppressEmptyState) {
      return const SizedBox.shrink();
    }
    if (selectedState == null) {
      // Creation is always available from the quick action. Do not reserve a
      // full home section when there is no live plan to return to.
      return const SizedBox.shrink();
    }
    final carouselStates = homeWatchPlanStates(plans, user.id).take(5).toList(
          growable: false,
        );
    if (carouselStates.isEmpty) return const SizedBox.shrink();
    if (_watchPlansPage.value >= carouselStates.length) {
      _watchPlansPage.value = 0;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: 'Watch together',
          onSeeAll: () => context.push('/plans'),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            // Every plan uses the current contextual card, with a next-card
            // preview that makes the horizontal carousel discoverable.
            final cardWidth = carouselStates.length == 1
                ? constraints.maxWidth - 32
                : constraints.maxWidth >= 600
                    ? 460.0
                    : constraints.maxWidth * .90;
            final heightSignature = [
              cardWidth.toStringAsFixed(1),
              MediaQuery.textScalerOf(context).scale(1).toStringAsFixed(2),
              ...carouselStates.map(
                (state) => [
                  state.plan.id,
                  state.type.name,
                  state.eyebrow,
                  state.title,
                  state.supportingText,
                  state.actionLabel,
                ].join('|'),
              ),
            ].join(':');
            if (_watchPlansHeightSignature != heightSignature) {
              _watchPlansHeightSignature = heightSignature;
              _watchPlansCardHeight.value = null;
            }
            return ValueListenableBuilder<double?>(
              valueListenable: _watchPlansCardHeight,
              builder: (context, tallestCardHeight, _) => Column(
                children: [
                  NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollUpdateNotification &&
                          carouselStates.length > 1) {
                        final page =
                            (notification.metrics.pixels / (cardWidth + 12))
                                .round()
                                .clamp(0, carouselStates.length - 1);
                        if (_watchPlansPage.value != page) {
                          _watchPlansPage.value = page;
                        }
                      }
                      return false;
                    },
                    child: SingleChildScrollView(
                      controller: _watchPlansScrollController,
                      physics: WatchPlanSnapPhysics(itemExtent: cardWidth + 12),
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(
                          horizontal: (constraints.maxWidth - cardWidth) / 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var index = 0;
                              index < carouselStates.length;
                              index++) ...[
                            if (index > 0) const SizedBox(width: 12),
                            SizedBox(
                              width: cardWidth,
                              height: tallestCardHeight,
                              child: _WatchPlanCardHeightReporter(
                                onHeightChanged: (height) {
                                  final current = _watchPlansCardHeight.value;
                                  if (current == null || height > current) {
                                    _watchPlansCardHeight.value = height;
                                  }
                                },
                                child: HomeWatchPlanCard(
                                  state: carouselStates[index],
                                  onOpen: () => _openHomeWatchPlan(
                                    carouselStates[index],
                                    user,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (carouselStates.length > 1) ...[
                    const SizedBox(height: 10),
                    ValueListenableBuilder<int>(
                      valueListenable: _watchPlansPage,
                      builder: (context, page, _) => Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          carouselStates.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: index == page ? 20 : 7,
                            height: 7,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: index == page
                                  ? FlixieColors.primary
                                  : context.colors.medium
                                      .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildPosterRailLoadingState(String title) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeSectionHeader(title: title),
          const SizedBox(height: 12),
          SizedBox(
              height: 164,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 4,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, __) => const SkeletonBox(
                    width: 110, height: 148, borderRadius: 11),
              )),
          const SizedBox(height: 14),
        ],
      );

  Future<void> _toggleWatchlistState(
    BuildContext context, {
    required int movieId,
    required String movieTitle,
    required String? posterPath,
    required bool currentlyInWatchlist,
    bool offerUndo = true,
  }) async {
    final auth = context.read<AuthProvider>();
    final analytics = context.read<AnalyticsController>();
    final userId = auth.dbUser?.id;
    if (userId == null) return;
    final session = _home.session;
    bool current() => mounted && _home.ownsSession(session);

    if (_watchlistUpdatesInFlight.contains(movieId)) return;
    final existing = auth.dbUser?.movieWatchlist ?? [];
    final messenger = ScaffoldMessenger.of(context);
    _home.setWatchlistMembership(movieId, !currentlyInWatchlist, pending: true);
    try {
      if (currentlyInWatchlist) {
        await _watchlistActions.removeFromWatchlist(userId, movieId);
        if (!current()) return;
        await analytics.watchlistRemoved(
          contentType: 'movie',
          contentId: movieId,
          source: 'home',
        );
        if (!current()) return;
        auth.updateUserList(
          movieWatchlist: existing.where((w) => w.movieId != movieId).toList(),
        );
      } else {
        await _watchlistActions.addToWatchlist(userId, movieId);
        if (!current()) return;
        await analytics.watchlistAdded(
          contentType: 'movie',
          contentId: movieId,
          source: 'home',
        );
        final now = DateTime.now().toIso8601String();
        if (!current()) return;
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
      if (current()) {
        messenger.showFlixieToast(
          FlixieToast(
            type: FlixieToastType.success,
            content: Text(
              currentlyInWatchlist
                  ? '$movieTitle removed from watchlist'
                  : '$movieTitle added to watchlist',
            ),
            action: offerUndo
                ? SnackBarAction(
                    label: 'Undo',
                    onPressed: () {
                      if (current() &&
                          !_watchlistUpdatesInFlight.contains(movieId) &&
                          _watchlistMovieIds.contains(movieId) ==
                              !currentlyInWatchlist) {
                        _toggleWatchlistState(context,
                            movieId: movieId,
                            movieTitle: movieTitle,
                            posterPath: posterPath,
                            currentlyInWatchlist: !currentlyInWatchlist,
                            offerUndo: false);
                      }
                    })
                : null,
          ),
        );
      }
    } catch (e) {
      logger.w('[HomeScreen] watchlist toggle failed: $e');
      if (current()) {
        _home.setWatchlistMembership(movieId, currentlyInWatchlist);
        messenger.showFlixieToast(
          FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Could not update watchlist right now')),
        );
      }
    } finally {
      if (current()) {
        _home.finishWatchlistUpdate(movieId);
      }
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
      useRootNavigator: true,
      useSafeArea: true,
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
            _home.removeRecommendation(movieId);
            _home.setWatchlistMembership(movieId, false);
            if (_forYouMovies.isEmpty) {
              _forYouPage.value = 0;
            } else {
              _forYouPage.value = _forYouPage.value.clamp(
                0,
                _forYouMovies.length - 1,
              );
            }
            messenger.showFlixieToast(
              FlixieToast(
                  type: FlixieToastType.success,
                  content: Text('$movieTitle marked as watched')),
            );
          }
        },
      ),
    );

    if (!mounted || !context.mounted || !watchSaved) return;
    if (writeReview) {
      await showModalBottomSheet<Review>(
        context: this.context,
        useRootNavigator: true,
        useSafeArea: true,
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

class _WatchPlanCardHeightReporter extends StatefulWidget {
  const _WatchPlanCardHeightReporter({
    required this.child,
    required this.onHeightChanged,
  });

  final Widget child;
  final ValueChanged<double> onHeightChanged;

  @override
  State<_WatchPlanCardHeightReporter> createState() =>
      _WatchPlanCardHeightReporterState();
}

class _WatchPlanCardHeightReporterState
    extends State<_WatchPlanCardHeightReporter> {
  final GlobalKey _childKey = GlobalKey();
  bool _reportScheduled = false;

  @override
  Widget build(BuildContext context) {
    if (!_reportScheduled) {
      _reportScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _reportScheduled = false;
        if (!mounted) return;
        final renderObject = _childKey.currentContext?.findRenderObject();
        if (renderObject is RenderBox && renderObject.hasSize) {
          widget.onHeightChanged(renderObject.size.height);
        }
      });
    }
    return KeyedSubtree(key: _childKey, child: widget.child);
  }
}

/// Settles each plan at the viewport centre while retaining intrinsic card height.
class WatchPlanSnapPhysics extends ScrollPhysics {
  const WatchPlanSnapPhysics({required this.itemExtent, super.parent});
  final double itemExtent;

  @override
  WatchPlanSnapPhysics applyTo(ScrollPhysics? ancestor) => WatchPlanSnapPhysics(
      itemExtent: itemExtent, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final tolerance = toleranceFor(position);
    var page = position.pixels / itemExtent;
    if (velocity < -tolerance.velocity) {
      page -= 0.5;
    } else if (velocity > tolerance.velocity) {
      page += 0.5;
    }
    final target = (page.round() * itemExtent)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((target - position.pixels).abs() < tolerance.distance) return null;
    return ScrollSpringSimulation(spring, position.pixels, target, velocity,
        tolerance: tolerance);
  }

  @override
  bool get allowImplicitScrolling => false;
}
