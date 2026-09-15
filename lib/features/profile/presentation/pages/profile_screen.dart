import 'package:flixie_app/features/social/presentation/pages/social_screen.dart'
    show showProfileCreateGroupSheet;
import 'package:flixie_app/features/profile/presentation/controllers/review_reactions_controller.dart';
import 'package:flixie_app/features/movies/presentation/widgets/review_card.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_tile.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/movie_rating.dart';
import 'package:flixie_app/models/continue_watching_show.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/watch_request.dart';
import 'package:flixie_app/models/movie_wrapped.dart';
import 'package:flixie_app/models/person.dart';
import 'package:flixie_app/models/favorite_movie.dart';
import 'package:flixie_app/models/user.dart' as models;
import 'package:flixie_app/features/social/presentation/controllers/friend_actions_controller.dart';
import 'package:flixie_app/features/profile/presentation/controllers/profile_lookup_controller.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/core/utils/favourite_limits.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/core/widgets/flixie_page.dart';
import 'package:flixie_app/features/profile/presentation/widgets/friends_row.dart';
import 'package:flixie_app/features/profile/presentation/widgets/movie_taste_badge.dart';
import 'package:flixie_app/features/profile/presentation/widgets/lists_preview_section.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_header.dart';
import 'package:flixie_app/features/profile/presentation/widgets/ratings_section.dart';
import 'package:flixie_app/features/movies/data/show_service.dart';
import 'package:flixie_app/features/movies/data/person_service.dart';
import 'package:flixie_app/features/home/presentation/widgets/continue_watching_carousel.dart';
import 'package:flixie_app/core/widgets/flixie_section_header.dart';
import 'package:flixie_app/features/settings/presentation/widgets/watch_providers_sheet.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/features/social/data/request_service.dart';
import 'package:flixie_app/features/social/presentation/widgets/group_card.dart';

enum _ProfileTab { library, activity, social, stats }

enum _ActivityFilter { all, watches, ratings, reviews, lists }

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<ActivityListItem> _activity = [];
  bool _activityLoading = true;
  String? _loadedForUserId;
  int _lastActivityVersion = -1;

  FriendsData? _friendsData;
  bool _friendsLoading = true;

  List<MovieRating> _ratings = [];
  bool _ratingsLoading = true;
  List<ContinueWatchingShow> _continueWatching = [];
  List<WatchProvider> _watchProviders = [];
  int _activityLimit = 20;
  String? _activityCursor;
  int _activityGeneration = 0;
  bool _activityFailed = false;
  bool _activityRequestRunning = false;
  List<Review> _reviews = [];
  int _reviewCount = 0;
  List<Group> _groups = [];
  List<WatchRequest> _watchRequests = [];
  bool _profileExtrasLoading = true;
  MovieWrapped? _wrapped;
  Map<int, Person> _directorPeople = {};

  _ProfileTab _selectedTab = _ProfileTab.library;
  _ActivityFilter _activityFilter = _ActivityFilter.all;
  AuthProvider? _authProvider;
  final FriendActionsController _friendActions =
      FriendActionsController.instance;
  final ProfileLookupController _profileLookup =
      ProfileLookupController.instance;

  MovieWrapped _emptyWrapped() => MovieWrapped(
        year: DateTime.now().year,
        totalMoviesWatched: 0,
        rewatchCount: 0,
        totalHoursWatched: 0,
        topGenres: const [],
        topDirectors: const [],
        topMovies: const [],
        highestRatedMovies: const [],
        monthlyWatchCounts: const [],
      );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authProvider ??= context.read<AuthProvider>();
  }

  @override
  void initState() {
    super.initState();
    ReviewReactionsController.deletedReviews.addListener(_onReviewDeleted);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authProvider?.addListener(_onAuthChanged);
      _loadAll();
    });
  }

  void _onReviewDeleted() {
    if (!mounted) return;
    setState(() {
      _reviews.removeWhere(ReviewReactionsController.isDeleted);
    });
  }

  @override
  void dispose() {
    ReviewReactionsController.deletedReviews.removeListener(_onReviewDeleted);
    _authProvider?.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final auth = _authProvider;
    final userId = auth?.dbUser?.id;
    final version = auth?.activityVersion ?? -1;
    if (userId != null &&
        (userId != _loadedForUserId || version != _lastActivityVersion)) {
      if (userId != _loadedForUserId) {
        _loadAll();
      } else {
        _loadActivity();
      }
    }
  }

  Future<void> _loadAll() async {
    logger.d('[ProfileScreen] _loadAll called');
    try {
      await Future.wait([
        _loadActivity(),
        _loadFriends(),
        _loadRatings(),
        _loadProfileExtras(),
      ]);
      logger.d('[ProfileScreen] All data loaded successfully');
    } catch (e, stackTrace) {
      logger.e('[ProfileScreen] Error in _loadAll: $e');
      logger.e('[ProfileScreen] Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _activityLoading = false;
          _ratingsLoading = false;
          _profileExtrasLoading = false;
        });
      }
    }
  }

  bool _statsFailed = false;
  bool _socialLoadFailed = false;

  Future<void> _loadProfileExtras() async {
    _socialLoadFailed = false;
    _statsFailed = false;
    final auth = context.read<AuthProvider>();
    final userId = auth.dbUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _profileExtrasLoading = false);
      return;
    }
    if (mounted) {
      setState(() {
        _reviews = auth.cachedReviews ?? _reviews;
        _reviewCount = _reviews.length;
        _groups = auth.cachedGroups ?? _groups;
        _watchRequests = auth.cachedWatchRequests ?? _watchRequests;
      });
    }
    final libraryFuture = Future.wait<Object>([
      ShowService.getContinueWatching(userId)
          .catchError((_) => <ContinueWatchingShow>[]),
      ProfileLookupController.instance
          .getUserWatchProviders(userId)
          .catchError((_) => <WatchProvider>[]),
    ]);
    final statsFuture = Future.wait<Object>([
      UserService.getUserReviews(userId).catchError((_) => _reviews),
      GroupService.getUserGroups(userId).catchError((_) {
        _socialLoadFailed = true;
        return _groups;
      }),
      RequestService.getWatchRequests(userId).catchError((_) {
        _socialLoadFailed = true;
        return _watchRequests;
      }),
      UserService.getMovieWrapped(userId, DateTime.now().year).catchError((_) {
        _statsFailed = true;
        return _wrapped ?? _emptyWrapped();
      }),
    ]);

    try {
      final results = await libraryFuture;
      if (!mounted) return;
      setState(() {
        _continueWatching = results[0] as List<ContinueWatchingShow>;
        _watchProviders = results[1] as List<WatchProvider>;
        _profileExtrasLoading = false;
      });
    } catch (e) {
      logger.e('[ProfileScreen] library extras load error: $e');
      if (mounted) setState(() => _profileExtrasLoading = false);
    }

    try {
      final results = await statsFuture.timeout(const Duration(seconds: 15));
      final wrapped = results[3] as MovieWrapped;
      if (!mounted) return;
      setState(() {
        if (!_statsFailed) _wrapped = wrapped;
        _reviews = results[0] as List<Review>;
        _reviewCount = _reviews.length;
      });
      final directorResults = await Future.wait(
        wrapped.topDirectors
            .where((director) => director.personId != null)
            .take(4)
            .map((director) async {
          final id = director.personId!;
          try {
            final person = await PersonService.getPersonById(id)
                .timeout(const Duration(seconds: 10));
            return (id: id, person: person);
          } catch (_) {
            return null;
          }
        }),
      );
      if (!mounted) return;
      final watchRequests = results[2] as List<WatchRequest>;
      setState(() {
        _reviews = results[0] as List<Review>;
        _reviewCount = _reviews.length;
        _groups = results[1] as List<Group>;
        _watchRequests = watchRequests;
        if (!_statsFailed) _wrapped = wrapped;
        _directorPeople = {
          for (final result
              in directorResults.whereType<({int id, Person person})>())
            result.id: result.person,
        };
      });
      context.read<AuthProvider>().updateCachedWatchRequests(watchRequests);
    } catch (e) {
      logger.e('[ProfileScreen] stats extras load error: $e');
      if (mounted) setState(() => _socialLoadFailed = true);
      if (mounted) setState(() => _statsFailed = true);
    }
  }

  Future<void> _removeContinueWatchingShow(ContinueWatchingShow show) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) return;
    final index = _continueWatching.indexWhere(
      (item) => item.showId == show.showId,
    );
    if (index < 0) return;

    setState(() => _continueWatching.removeAt(index));
    var undone = false;
    final notice = ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${show.name} removed from Continue watching'),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            undone = true;
            if (mounted) {
              setState(() => _continueWatching.insert(
                  index.clamp(0, _continueWatching.length), show));
            }
          }),
    ));
    await notice.closed;
    if (undone) return;
    try {
      await ShowService.dismissContinueWatching(userId, show.showId);
      if (!mounted) return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final restoredIndex = index.clamp(0, _continueWatching.length);
        _continueWatching.insert(restoredIndex, show);
      });
      ScaffoldMessenger.of(context).showFlixieToast(
        FlixieToast(
            type: FlixieToastType.error,
            content: const Text('Could not remove that show right now')),
      );
    }
  }

  Future<void> _openWatchProviders() async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) return;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WatchProvidersSheet(userId: userId),
    );
    if (mounted) await _loadProfileExtras();
  }

  Future<void> _loadActivity({bool more = false}) async {
    if (more && _activityRequestRunning) return;
    final generation = ++_activityGeneration;
    final auth = context.read<AuthProvider>();
    final userId = auth.dbUser?.id;
    if (userId == null) return;
    _loadedForUserId = userId;
    _lastActivityVersion = auth.activityVersion;
    setState(() {
      _activityRequestRunning = true;
      _activityLoading = !more;
      _activityFailed = false;
    });
    try {
      final page = await UserService.getUserActivityPage(userId,
          filter: _activityFilter.name, cursor: more ? _activityCursor : null);
      if (!mounted || generation != _activityGeneration) return;
      setState(() {
        _activity = more ? [..._activity, ...page.items] : page.items;
        _activityCursor = page.nextCursor;
        _activityLimit = _activity.length;
      });
    } catch (error) {
      if (mounted && generation == _activityGeneration) {
        setState(() => _activityFailed = true);
      }
    } finally {
      if (mounted && generation == _activityGeneration) {
        setState(() {
          _activityLoading = false;
          _activityRequestRunning = false;
        });
      }
    }
  }

  Future<void> _loadFriends() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.dbUser?.id;
    if (userId == null) return;

    // Use prefetched cache if ready
    if (auth.cachedFriends != null) {
      if (mounted) {
        setState(() {
          _friendsData = auth.cachedFriends;
          _friendsLoading = false;
        });
      }
      return;
    }

    try {
      final data = await _friendActions.getFriends(userId);
      if (mounted) {
        setState(() {
          _friendsData = data;
          _friendsLoading = false;
        });
      }
    } catch (e) {
      logger.e('[ProfileScreen] friends load error: $e');
      if (mounted) {
        setState(() {
          _friendsData = const FriendsData(
            friendships: [],
            pendingFriends: [],
            requestedFriends: [],
          );
          _friendsLoading = false;
        });
      }
    }
  }

  Future<void> _loadRatings() async {
    logger.d('[ProfileScreen] _loadRatings called');
    final auth = context.read<AuthProvider>();
    final userId = auth.dbUser?.id;
    logger.d('[ProfileScreen] userId for ratings: $userId');
    if (userId == null) {
      logger.w('[ProfileScreen] Cannot load ratings - userId is null');
      return;
    }

    // Use prefetched cache if ready
    if (auth.cachedRatings != null) {
      logger.i(
          '[ProfileScreen] Using cached ratings (${auth.cachedRatings!.length})');
      if (mounted) {
        setState(() {
          _ratings = auth.cachedRatings!;
          _ratingsLoading = false;
        });
      }
      return;
    }

    try {
      logger.d(
          '[ProfileScreen] Calling ProfileLookupController.getUserMovieRatings...');
      final ratings = await _profileLookup.getUserMovieRatings(userId);
      logger.i('[ProfileScreen] Loaded ${ratings.length} ratings');
      if (mounted) {
        setState(() {
          _ratings = ratings;
          _ratingsLoading = false;
        });
      }
    } catch (e, stackTrace) {
      logger.e('[ProfileScreen] ratings load error: $e');
      logger.e('[ProfileScreen] Stack trace: $stackTrace');
      if (mounted) setState(() => _ratingsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final auth = context.watch<AuthProvider>();
    final firebaseUser = auth.firebaseUser;
    final dbUser = auth.dbUser;

    // Prefer database user info, fallback to Firebase
    final displayName = dbUser?.firstName?.trim().isNotEmpty == true
        ? dbUser!.firstName!.trim()
        : dbUser?.username ?? firebaseUser?.displayName ?? 'Guest User';
    final username = dbUser?.username ?? firebaseUser?.displayName ?? '';
    final bio = dbUser?.bio;
    final userId = dbUser?.id;

    final favoriteMovies = (dbUser?.favoriteMovies ?? [])
        .where((favorite) => favorite.removed != true)
        .toList(growable: false);
    final favoriteShows = (dbUser?.favoriteShows ?? const <dynamic>[])
        .where(isActiveFavouriteShow)
        .toList(growable: false);
    final favoritePeople = dbUser?.favoritePeople ?? [];
    final watchedCount = (dbUser?.watchedMovies?.length ?? 0) +
        (dbUser?.watchedShows?.length ?? 0);
    final watchlistCount = (dbUser?.movieWatchlist?.length ?? 0) +
        (dbUser?.showWatchlist?.length ?? 0);
    final favoritesCount = favoriteMovies.length + favoriteShows.length;

    final visibleActivity = _activity;

    return FlixiePageScaffold(
      appBar: FlixieTitleAppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
          IconButton(
            tooltip: 'Notifications',
            icon: Badge(
              isLabelVisible: auth.unreadNotificationCount > 0,
              label: auth.unreadNotificationCount < 100
                  ? Text('${auth.unreadNotificationCount}')
                  : const Text('99+'),
              backgroundColor: FlixieColors.tertiary,
              textColor: Colors.black,
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () async {
              final authProvider = context.read<AuthProvider>();
              await context.push('/notifications');
              if (mounted) {
                authProvider.refreshNotificationCount();
              }
            },
          ),
        ],
      ),
      body: dbUser == null &&
              _activityLoading &&
              _ratingsLoading &&
              _profileExtrasLoading
          ? const ProfileScreenSkeleton()
          : RefreshIndicator(
              color: FlixieColors.primary,
              onRefresh: () async {
                await context.read<AuthProvider>().refreshUserData();
                await _loadAll();
              },
              child: CustomScrollView(
                key: PageStorageKey('profile-${_selectedTab.name}'),
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                      child: ProfileHeader(
                    displayName: displayName,
                    username: username,
                    bio: bio,
                    iconColor: dbUser?.iconColor,
                    avatar: dbUser?.avatar,
                    profileBadges: dbUser?.profileBadges ?? const [],
                    memberSince: _memberSinceLabel(dbUser?.createdAt),
                    onPreview: userId == null
                        ? null
                        : () => context.push('/friends/$userId?preview=true'),
                  )),
                  SliverToBoxAdapter(
                      child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          child: _ProfileDashboard(
                            watched: watchedCount,
                            watchlist: watchlistCount,
                            favorites: favoritesCount,
                            onWatchHistory: () =>
                                context.push('/watch-history'),
                            onWatchlist: () => context.push('/watchlist'),
                            onFavourites: () => setState(
                                () => _selectedTab = _ProfileTab.library),
                            onRecap: () => context.push('/stats'),
                          ))),
                  if (_wrapped?.insights != null)
                    SliverToBoxAdapter(
                        child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SocialSectionHeader(
                                title: 'This month',
                                onSeeAll: () => setState(
                                    () => _selectedTab = _ProfileTab.stats),
                                actionLabel: 'View stats'),
                            Text(
                                '${_wrapped!.insights!['monthMovies']} movie watches · ${_wrapped!.insights!['monthEpisodes']} episodes',
                                style:
                                    const TextStyle(color: FlixieColors.light)),
                            if (_wrapped!.insights!['milestone'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: Row(children: [
                                  const Icon(Icons.star_outline_rounded,
                                      color: FlixieColors.warning),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        const Text('Latest milestone',
                                            style: TextStyle(
                                                color: FlixieColors.medium,
                                                fontSize: 12)),
                                        Text(
                                            '${_wrapped!.insights!['milestone']['count']} unique films watched',
                                            style: const TextStyle(
                                                color: FlixieColors.white,
                                                fontWeight: FontWeight.w600)),
                                      ])),
                                ]),
                              ),
                          ]),
                    )),
                  SliverPersistentHeader(
                      pinned: true,
                      delegate: _ProfileTabsDelegate(
                          height: 48 +
                              (MediaQuery.textScalerOf(context).scale(16) -
                                      16) *
                                  2,
                          child: _ProfileTabSelector(
                              selected: _selectedTab,
                              onSelected: (tab) =>
                                  setState(() => _selectedTab = tab)))),
                  SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      sliver: _selectedTab == _ProfileTab.activity
                          ? _buildActivityTab(
                              context, textTheme, visibleActivity)
                          : SliverToBoxAdapter(
                              child: _buildSelectedTabContent(
                              context: context,
                              textTheme: textTheme,
                              userId: userId,
                              favoriteMovies: favoriteMovies,
                              favoritePeople: favoritePeople,
                              favoriteShows: favoriteShows,
                              favoriteGenres:
                                  dbUser?.favoriteGenres ?? const [],
                              user: dbUser,
                              visibleActivity: visibleActivity,
                            ))),
                ],
              ),
            ),
    );
  }

  Widget _buildSelectedTabContent({
    required BuildContext context,
    required TextTheme textTheme,
    required String? userId,
    required List<dynamic> favoriteMovies,
    required List<dynamic> favoritePeople,
    required List<dynamic> favoriteShows,
    required List<dynamic> favoriteGenres,
    required models.User? user,
    required List<ActivityListItem> visibleActivity,
  }) {
    switch (_selectedTab) {
      case _ProfileTab.library:
        return _buildLibraryTab(
          context: context,
          userId: userId,
          favoriteMovies: favoriteMovies,
          favoritePeople: favoritePeople,
          favoriteShows: favoriteShows,
        );
      case _ProfileTab.activity:
        return _buildActivityTab(context, textTheme, visibleActivity);
      case _ProfileTab.social:
        return _buildSocialTab(context);
      case _ProfileTab.stats:
        return _buildStatsTab(context, favoriteGenres, user);
    }
  }

  Widget _buildLibraryTab({
    required BuildContext context,
    required String? userId,
    required List<dynamic> favoriteMovies,
    required List<dynamic> favoritePeople,
    required List<dynamic> favoriteShows,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_continueWatching.isNotEmpty) ...[
          _ProfileContinueWatching(
            shows: _continueWatching,
            onRemove: _removeContinueWatchingShow,
          ),
          const SizedBox(height: 20),
        ],
        if (favoriteMovies.isNotEmpty ||
            favoritePeople.isNotEmpty ||
            favoriteShows.isNotEmpty) ...[
          _FavouritesLibrary(
            movies: favoriteMovies,
            people: favoritePeople,
            shows: favoriteShows,
          ),
        ] else
          _ProfileEmptyAction(
            icon: Icons.favorite_outline_rounded,
            title: 'No favourite movies yet',
            body: 'Favourite a few movies so your profile feels like you.',
            label: 'Find movies',
            onPressed: () => context.push('/search'),
          ),
        const SizedBox(height: 20),
        if (_profileExtrasLoading) ...[
          const _ProfileExtrasLoadingIndicator(),
          const SizedBox(height: 20),
        ],
        if (userId != null) ...[
          ListsPreviewSection(
            userId: userId,
            title: 'Your lists',
            emptyMessage: "You haven't created any lists yet.",
            allowManage: true,
            embedded: true,
          ),
          const SizedBox(height: 20),
        ],
        if (_reviews.isNotEmpty) ...[
          _RecentReviewsSummary(reviews: _reviews),
          const SizedBox(height: 16),
        ],
        if (_ratingsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          RatingsSection(ratings: _ratings),
          const SizedBox(height: 16),
        ],
        _WatchProvidersSummary(
          providers: _watchProviders,
          onManage: _openWatchProviders,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildActivityTab(
    BuildContext context,
    TextTheme textTheme,
    List<ActivityListItem> visibleActivity,
  ) {
    final filtered = visibleActivity
        .where((item) => switch (_activityFilter) {
              _ActivityFilter.all => true,
              _ActivityFilter.watches =>
                item.type == ActivityListType.movieWatched ||
                    item.type == ActivityListType.showWatched,
              _ActivityFilter.ratings =>
                item.type == ActivityListType.movieRating ||
                    item.type == ActivityListType.showRating,
              _ActivityFilter.reviews =>
                item.type == ActivityListType.movieReview ||
                    item.type == ActivityListType.showReview,
              _ActivityFilter.lists =>
                item.type == ActivityListType.movieWatchlist ||
                    item.type == ActivityListType.showWatchlist,
            })
        .toList()
      ..sort((a, b) {
        final dates = (DateTime.tryParse(b.timestamp) ?? DateTime(1970))
            .compareTo(DateTime.tryParse(a.timestamp) ?? DateTime(1970));
        return dates != 0
            ? dates
            : '${a.type.value}:${a.id}'.compareTo('${b.type.value}:${b.id}');
      });
    final rows = <Object>[];
    String? lastDate;
    for (final item in filtered.take(_activityLimit)) {
      final date = _activityDateLabel(item.timestamp);
      if (date != lastDate) {
        rows.add(date);
        lastDate = date;
      }
      rows.add(item);
    }
    return SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
      if (index == 0) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Your activity',
              style: TextStyle(
                  color: FlixieColors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final filter in _ActivityFilter.values)
                  Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: filter == _activityFilter,
                        showCheckmark: false,
                        label: Text(filter == _ActivityFilter.lists
                            ? 'Watchlist'
                            : _activityFilterLabel(filter)),
                        onSelected: (_) {
                          setState(() {
                            _activityFilter = filter;
                            _activity = [];
                            _activityCursor = null;
                          });
                          _loadActivity();
                        },
                      )),
              ])),
          const SizedBox(height: 12),
          if (_activityLoading)
            const LinearProgressIndicator()
          else if (_activityFailed)
            TextButton.icon(
                onPressed: _loadActivity,
                icon: const Icon(Icons.refresh),
                label: const Text('Couldn’t load activity · Retry'))
          else
            Text(
                filtered.isEmpty
                    ? 'No activity yet.'
                    : 'Showing ${filtered.take(_activityLimit).length} activities',
                style: const TextStyle(color: FlixieColors.medium)),
          const SizedBox(height: 12),
        ]);
      }
      if (index == rows.length + 1) {
        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: _activityCursor != null
                ? TextButton.icon(
                    onPressed: _activityRequestRunning
                        ? null
                        : () => _loadActivity(more: true),
                    icon: const Icon(Icons.expand_more),
                    label: Text(
                        _activityRequestRunning ? 'Loading…' : 'Load 20 more'))
                : filtered.isEmpty
                    ? const SizedBox.shrink()
                    : const Center(
                        child: Text('You’re up to date',
                            style: TextStyle(color: FlixieColors.medium))));
      }
      final row = rows[index - 1];
      if (row is String) {
        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(row,
                style: const TextStyle(
                    color: FlixieColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)));
      }
      final item = row as ActivityListItem;
      return ActivityTile(
          key: ValueKey('${item.type.value}:${item.id}'),
          item: item,
          compact: true);
    }, childCount: rows.length + 2));
  }

  Widget _buildSocialTab(BuildContext context) {
    final userId = context.read<AuthProvider>().dbUser?.id ?? '';
    final groups = _groups
        .where((group) => group.status?.toUpperCase() != 'CLOSED')
        .toList();
    final plans = _watchRequests
        .where((request) =>
            request.scheduledFor != null &&
            !request.isTerminal &&
            request.scheduledFor!.isAfter(DateTime.now()))
        .toList()
      ..sort((a, b) => a.scheduledFor!.compareTo(b.scheduledFor!));
    final needsReply = _watchRequests.where((request) {
      if (!request.isPending || request.requesterId == userId) return false;
      final participant = request.participantFor(userId);
      return participant == null ||
          participant.response.toLowerCase() == 'pending';
    }).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FriendsRow(
          data: _friendsData ??
              const FriendsData(
                friendships: [],
                pendingFriends: [],
                requestedFriends: [],
              ),
          isLoading: _friendsLoading,
          onFriendsChanged: (updated) {
            setState(() => _friendsData = updated);
            context.read<AuthProvider>().updateCachedFriends(updated);
          },
        ),
        const SizedBox(height: 22),
        _SocialSectionHeader(
          title: 'Your groups',
          count: groups.length,
          onSeeAll: () => context.push('/social?tab=groups'),
        ),
        const SizedBox(height: 10),
        if (groups.isEmpty)
          const Text('No groups yet.',
              style: TextStyle(color: FlixieColors.medium))
        else
          ...groups.take(3).map((group) => GroupCard(
                compact: true,
                group: group,
                memberCount: group.memberCount,
                onTap: () => context.push('/groups/${group.id}'),
              )),
        TextButton.icon(
          onPressed: () =>
              showProfileCreateGroupSheet(context, onCreated: (group) {
            if (mounted) setState(() => _groups.add(group));
          }),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Create group'),
        ),
        const SizedBox(height: 18),
        _SocialSectionHeader(
          title: 'Watch plans',
          count: plans.isEmpty ? null : plans.length,
          onSeeAll: () => context.push('/watch-requests'),
        ),
        if (needsReply > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: FlixieColors.tabBarBackgroundFocused,
              borderRadius: BorderRadius.circular(14),
              child: ListTile(
                onTap: () => context.push('/watch-requests'),
                title: const Text('Watch plan requests'),
                subtitle: const Text('Awaiting your reply'),
                leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: FlixieColors.warning,
                    child: Text('$needsReply',
                        style: const TextStyle(
                            color: Colors.black, fontWeight: FontWeight.w700))),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ),
          ),
        ...plans.take(2).map((request) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ProfileWatchPlanCard(request: request),
            )),
        if (_socialLoadFailed)
          TextButton.icon(
            onPressed: _loadProfileExtras,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Couldn’t refresh groups and plans. Retry'),
          ),
      ],
    );
  }

  Widget _buildStatsTab(
    BuildContext context,
    List<dynamic> favoriteGenres,
    models.User? user,
  ) {
    return _ProfileStatsContent(
      wrapped: _wrapped,
      failed: _statsFailed,
      onRetry: _loadProfileExtras,
      ratings: _ratings,
      reviewCount: _reviewCount,
      favoriteGenres: favoriteGenres,
      directorPeople: _directorPeople,
      onWrapped: () => context.push('/wrapped/${user?.id ?? ''}'),
      onFindMovies: () => context.push('/search'),
      onSeeRatings: () => context.push('/stats'),
    );
  }

  String? _memberSinceLabel(String? value) {
    final joined = DateTime.tryParse(value ?? '');
    if (joined == null) return null;
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
    return 'Member since ${months[joined.month - 1]} ${joined.year}';
  }
}

class _FavouritesLibrary extends StatelessWidget {
  const _FavouritesLibrary({
    required this.movies,
    required this.shows,
    required this.people,
  });

  final List<dynamic> movies;
  final List<dynamic> people;
  final List<dynamic> shows;

  @override
  Widget build(BuildContext context) {
    final movieItems = movies.whereType<FavoriteMovie>().map((favorite) {
      final movie = favorite.movie ?? const <String, dynamic>{};
      return _FavouriteDisplayItem(
        title: movie['title']?.toString() ?? 'Movie',
        imagePath: movie['posterPath']?.toString(),
        route: '/movies/${favorite.movieId}',
      );
    }).toList(growable: false);
    final showItems = shows.map((raw) {
      final outer =
          raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
      final show = outer['show'] is Map<String, dynamic>
          ? outer['show'] as Map<String, dynamic>
          : outer;
      final id = show['id'] ?? outer['showId'];
      return _FavouriteDisplayItem(
        title: (show['title'] ?? show['name'] ?? 'Show').toString(),
        imagePath: show['posterPath']?.toString(),
        route: id == null ? null : '/shows/$id',
      );
    }).toList(growable: false);
    final peopleItems = people.map((raw) {
      final person =
          raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
      final id = person['id'] ?? person['personId'];
      return _FavouriteDisplayItem(
        title: (person['name'] ?? 'Person').toString(),
        imagePath:
            (person['profileImgUrl'] ?? person['profilePath'])?.toString(),
        route: id == null ? null : '/people/$id',
      );
    }).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (movieItems.isNotEmpty)
          _FavouritePosterRail(
            title: 'Favourite movies',
            items: movieItems,
            limit: maxFavouriteMovies,
          ),
        if (movieItems.isNotEmpty &&
            (peopleItems.isNotEmpty || showItems.isNotEmpty))
          const SizedBox(height: 18),
        if (showItems.isNotEmpty)
          _FavouritePosterRail(
            title: 'Favourite shows',
            items: showItems,
            limit: maxFavouriteShows,
          ),
        if (showItems.isNotEmpty && peopleItems.isNotEmpty)
          const SizedBox(height: 18),
        if (peopleItems.isNotEmpty)
          _FavouritePosterRail(
            title: 'Favourite people',
            items: peopleItems,
            circular: true,
          ),
      ],
    );
  }
}

class _FavouriteDisplayItem {
  const _FavouriteDisplayItem({
    required this.title,
    required this.imagePath,
    required this.route,
  });

  final String title;
  final String? imagePath;
  final String? route;
}

class _FavouritePosterRail extends StatelessWidget {
  const _FavouritePosterRail({
    required this.title,
    required this.items,
    this.limit,
    this.circular = false,
  });

  final String title;
  final List<_FavouriteDisplayItem> items;
  final int? limit;
  final bool circular;

  void _showAll(BuildContext context) {
    showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (context) => SizedBox(
            height: MediaQuery.sizeOf(context).height * .8,
            child: Column(children: [
              ListTile(
                  title: Text(title),
                  subtitle: limit == null
                      ? null
                      : Text('${items.length} of $limit favourites'),
                  trailing: IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context))),
              Expanded(
                  child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                            title: Text(item.title),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: item.route == null
                                ? null
                                : () => context.push(item.route!));
                      })),
            ])));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height:
          (circular ? 158 : 208) + MediaQuery.textScalerOf(context).scale(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FlixieSectionHeader(
            title: title,
            trailingLabel: '${items.length} · See all',
            onTrailingTap: () => _showAll(context),
            uppercase: false,
            accentHeight: 0,
            titleStyle: const TextStyle(
              color: FlixieColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                final rawPath = item.imagePath;
                final imageUrl = rawPath == null
                    ? null
                    : rawPath.startsWith('http')
                        ? rawPath
                        : 'https://image.tmdb.org/t/p/w342$rawPath';
                return SizedBox(
                  width: 104,
                  child: InkWell(
                    onTap: item.route == null
                        ? null
                        : () => context.push(item.route!),
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            circular ? 999 : 10,
                          ),
                          child: SizedBox(
                            width: circular ? 96 : 104,
                            height: circular ? 96 : 146,
                            child: imageUrl == null
                                ? const ColoredBox(
                                    color: FlixieColors.surfaceElevated,
                                    child: Icon(
                                      Icons.favorite_outline_rounded,
                                      color: FlixieColors.medium,
                                    ),
                                  )
                                : Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.image_not_supported_outlined,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: FlixieColors.light,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentReviewsSummary extends StatelessWidget {
  const _RecentReviewsSummary({required this.reviews});

  final List<Review> reviews;

  @override
  Widget build(BuildContext context) {
    final recent = reviews.take(3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FlixieSectionHeader(
          title: 'Recent reviews',
          uppercase: false,
          accentHeight: 0,
          titleStyle: const TextStyle(
            color: FlixieColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: .5,
          ),
          trailingLabel: 'See all',
          trailingColor: FlixieColors.primary,
          onTrailingTap: () => context.push('/my-reviews'),
        ),
        ...recent.map((review) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ProfileReviewCard(review: review),
            )),
      ],
    );
  }
}

class _ProfileReviewCard extends StatelessWidget {
  const _ProfileReviewCard({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(review.createdAt);
    final mediaRoute = review.showId != null
        ? showDetailPath(review.showId!)
        : review.movieId != null
            ? movieDetailPath(review.movieId!)
            : null;
    return Material(
      color: FlixieColors.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showReviewDetailSheet(context,
            review: review,
            currentUserId: context.read<AuthProvider>().dbUser?.id),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (review.moviePosterPath != null) ...[
              ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                      'https://image.tmdb.org/t/p/w342${review.moviePosterPath}',
                      width: 60,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const SizedBox(width: 60, height: 90))),
              const SizedBox(width: 12),
            ],
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  TextButton(
                      onPressed: mediaRoute == null
                          ? null
                          : () => context.push(mediaRoute),
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft),
                      child: Text(review.movieTitle ??
                          (review.showId != null
                              ? 'Show review'
                              : 'Movie review'))),
                  Text(review.title,
                      style: const TextStyle(
                          color: FlixieColors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  if (date != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                            '${date.day} ${const [
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
                            ][date.month - 1]} ${date.year}',
                            style: const TextStyle(
                                color: FlixieColors.medium, fontSize: 12))),
                  const SizedBox(height: 6),
                  Text(review.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: FlixieColors.light,
                          fontSize: 13,
                          height: 1.4)),
                  Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('★ ${review.rating}/10',
                            style:
                                const TextStyle(color: FlixieColors.warning)),
                        if (review.recommended)
                          const Icon(Icons.thumb_up_alt_outlined,
                              color: FlixieColors.success, size: 16),
                        TextButton(
                            onPressed: () => showReviewDetailSheet(context,
                                review: review,
                                currentUserId:
                                    context.read<AuthProvider>().dbUser?.id),
                            child: const Text('Read review ›')),
                        TextButton(
                            onPressed: () => context.push('/my-reviews'),
                            child: const Text('Manage')),
                      ]),
                ])),
          ]),
        ),
      ),
    );
  }
}

class _ProfileStatsContent extends StatelessWidget {
  const _ProfileStatsContent({
    required this.wrapped,
    required this.failed,
    required this.onRetry,
    required this.ratings,
    required this.reviewCount,
    required this.favoriteGenres,
    required this.directorPeople,
    required this.onWrapped,
    required this.onFindMovies,
    required this.onSeeRatings,
  });

  final bool failed;
  final VoidCallback onRetry;
  final MovieWrapped? wrapped;
  final List<MovieRating> ratings;
  final int reviewCount;
  final List<dynamic> favoriteGenres;
  final Map<int, Person> directorPeople;
  final VoidCallback onWrapped;
  final VoidCallback onFindMovies;
  final VoidCallback onSeeRatings;

  @override
  Widget build(BuildContext context) {
    final data = wrapped;
    if (data == null) {
      return failed
          ? TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Couldn’t load stats. Retry'))
          : const Center(child: CircularProgressIndicator());
    }
    final average = ratings.isEmpty
        ? '–'
        : (ratings.fold<int>(0, (sum, item) => sum + item.rating) /
                ratings.length)
            .toStringAsFixed(1);
    final maxGenre = data.topGenres.isEmpty
        ? 1
        : data.topGenres
            .map((item) => item.count)
            .reduce((a, b) => a > b ? a : b);

    final sortedRatings = [...ratings]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final now = DateTime.now();
    final monthCount = data.year == now.year ? now.month : 12;
    final counts = List<int>.filled(monthCount, 0);
    for (final month in data.monthlyWatchCounts) {
      if (month.month > 0 && month.month <= monthCount) {
        counts[month.month - 1] = month.count;
      }
    }
    final maxMonth = counts.fold<int>(1, (a, b) => a > b ? a : b);
    final minutes = (data.totalHoursWatched * 60).round();
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
    Widget heading(String title) => Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 12),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: FlixieColors.white)),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (failed)
        TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Couldn’t refresh stats. Retry')),
      Text('Movie watching · ${data.year}',
          style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: FlixieColors.white)),
      const SizedBox(height: 14),
      Wrap(spacing: 28, runSpacing: 12, children: [
        _StatsValue('${data.rewatchCount}', 'Watches'),
        _StatsValue('${data.totalMoviesWatched}', 'Unique movies'),
        _StatsValue('${minutes ~/ 60}h ${minutes % 60}m', 'Estimated time'),
      ]),
      Align(
          alignment: Alignment.centerRight,
          child: TextButton(
              onPressed: onWrapped,
              child: Text('View ${data.year} Wrapped ›'))),
      heading('Monthly watches'),
      SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < counts.length; i++)
              Semantics(
                  label: '${months[i]} ${data.year}: ${counts[i]} watches',
                  child: ExcludeSemantics(
                      child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(children: [
                      Text('${counts[i]}',
                          style: const TextStyle(
                              color: FlixieColors.light, fontSize: 12)),
                      const SizedBox(height: 4),
                      SizedBox(
                          height: 70,
                          width: 28,
                          child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                height: counts[i] == 0
                                    ? 2
                                    : counts[i] / maxMonth * 70,
                                decoration: BoxDecoration(
                                    color: counts[i] == 0
                                        ? FlixieColors.surfaceElevated
                                        : FlixieColors.primaryText,
                                    borderRadius: BorderRadius.circular(4)),
                              ))),
                      const SizedBox(height: 6),
                      Text(months[i],
                          style: const TextStyle(
                              color: FlixieColors.light, fontSize: 12)),
                    ]),
                  ))),
          ])),
      if (data.year == now.year)
        Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('${months[now.month - 1]} in progress',
                style:
                    const TextStyle(color: FlixieColors.medium, fontSize: 12))),
      if (data.insights != null)
        _ExtraViewingStats(
            insights: data.insights!,
            year: data.year,
            movies: data.totalMoviesWatched),
      heading('Your ratings · All time'),
      Material(
          color: FlixieColors.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onSeeRatings,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Expanded(
                      child: Text(
                          '$average / 10 average · ${ratings.length} movie ratings',
                          style: const TextStyle(color: FlixieColors.light))),
                  const Icon(Icons.chevron_right,
                      color: FlixieColors.primaryText),
                ])),
          )),
      Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text('$reviewCount movie and show reviews · All time',
              style: const TextStyle(color: FlixieColors.medium))),
      if (data.topMovies.isNotEmpty && data.topMovies.first.watchCount > 1) ...[
        heading('Most watched again'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: () =>
              context.push(movieDetailPath(data.topMovies.first.movieId)),
          title: Text(data.topMovies.first.title),
          subtitle: Text(
              '${data.topMovies.first.watchCount} watches in ${data.year}'),
          leading: data.topMovies.first.posterPath == null
              ? const Icon(Icons.movie_outlined)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                      imageUrl:
                          'https://image.tmdb.org/t/p/w185${data.topMovies.first.posterPath}',
                      width: 40,
                      height: 60,
                      fit: BoxFit.cover)),
          trailing: const Icon(Icons.chevron_right),
        ),
      ],
      if (data.topGenres.isNotEmpty) ...[
        heading('Top genres · ${data.year}'),
        ...data.topGenres.take(4).map((genre) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(children: [
              Row(children: [
                Expanded(child: Text(genre.name)),
                Text('${genre.count}')
              ]),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                  value: maxGenre <= 0 ? 0 : genre.count / maxGenre,
                  minHeight: 5,
                  color: FlixieColors.primaryText,
                  backgroundColor: FlixieColors.surfaceElevated),
            ]))),
        const Text('Viewing counts by genre; movies can have several genres.',
            style: TextStyle(color: FlixieColors.medium, fontSize: 12)),
      ],
      if (favoriteGenres.isNotEmpty) ...[
        heading('Your taste'),
        MovieTasteBadge(favoriteGenres: favoriteGenres, compact: true),
      ],
      if (data.topDirectors.isNotEmpty) ...[
        heading('Top directors · ${data.year}'),
        ...data.topDirectors.take(4).map((director) {
          final profile = directorPeople[director.personId]?.profileImgUrl;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
                backgroundImage: profile == null
                    ? null
                    : CachedNetworkImageProvider(
                        'https://image.tmdb.org/t/p/w185$profile'),
                child:
                    profile == null ? const Icon(Icons.person_outline) : null),
            title: Text(director.name),
            subtitle: Text('${director.count} films'),
            trailing: director.personId == null
                ? null
                : const Icon(Icons.chevron_right),
            onTap: director.personId == null
                ? null
                : () => context.push(personDetailPath(director.personId!)),
          );
        }),
      ],
      if (ratings.isNotEmpty) ...[
        const SizedBox(height: 18),
        _SocialSectionHeader(title: 'Recent ratings', onSeeAll: onSeeRatings),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final rating in sortedRatings.take(8))
                Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _RecentRatingTile(rating: rating)),
            ])),
      ],
    ]);
  }
}

class _StatsValue extends StatelessWidget {
  const _StatsValue(this.value, this.label);
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: FlixieColors.white)),
        Text(label,
            style: const TextStyle(color: FlixieColors.medium, fontSize: 13)),
      ]);
}

class _RecentRatingTile extends StatelessWidget {
  const _RecentRatingTile({required this.rating});
  final MovieRating rating;
  @override
  Widget build(BuildContext context) {
    final path = rating.movie?.posterPath;
    return GestureDetector(
      onTap: () => context.push(movieDetailPath(rating.movieId)),
      child: SizedBox(
          width: 88,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: SizedBox(
                    width: 88,
                    height: 132,
                    child: path == null
                        ? const ColoredBox(
                            color: FlixieColors.surfaceElevated,
                            child: Icon(Icons.movie_outlined))
                        : CachedNetworkImage(
                            imageUrl: 'https://image.tmdb.org/t/p/w342$path',
                            fit: BoxFit.cover))),
            const SizedBox(height: 5),
            Text(rating.movie?.title ?? 'Movie',
                style:
                    const TextStyle(color: FlixieColors.light, fontSize: 12)),
            Row(children: [
              const Icon(Icons.star_rounded,
                  color: FlixieColors.warning, size: 15),
              const SizedBox(width: 3),
              Text('${rating.rating}/10',
                  style: const TextStyle(
                      color: FlixieColors.light,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700))
            ]),
          ])),
    );
  }
}

class _SocialSectionHeader extends StatelessWidget {
  const _SocialSectionHeader({
    required this.title,
    required this.onSeeAll,
    this.count,
    this.actionLabel = 'See all',
  });

  final String actionLabel;
  final String title;
  final int? count;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: OverflowBar(
          alignment: MainAxisAlignment.spaceBetween,
          overflowAlignment: OverflowBarAlignment.end,
          spacing: 12,
          children: [
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: FlixieColors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                if (count != null) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: FlixieColors.primary.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text('$count',
                        style: const TextStyle(
                            color: FlixieColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ),
                ],
              ],
            ),
            TextButton(onPressed: onSeeAll, child: Text(actionLabel)),
          ],
        ),
      );
}

class _ProfileWatchPlanCard extends StatelessWidget {
  const _ProfileWatchPlanCard({required this.request});
  final WatchRequest request;

  @override
  Widget build(BuildContext context) {
    final date = request.scheduledFor!.toLocal();
    final dateLabel =
        '${date.day}/${date.month}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final posterPath = request.movie?.posterPath;
    final poster = posterPath == null
        ? null
        : posterPath.startsWith('http')
            ? posterPath
            : 'https://image.tmdb.org/t/p/w342$posterPath';
    final title = request.movie?.title ?? request.groupName ?? 'Watch plan';

    return Material(
      color: FlixieColors.surface.withValues(alpha: .72),
      borderRadius: BorderRadius.circular(15),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/watch-requests/${request.id}'),
        child: Container(
          height: 126,
          decoration: BoxDecoration(
            border: Border.all(color: FlixieColors.tabBarBorder),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 86,
                height: double.infinity,
                child: poster == null
                    ? const ColoredBox(
                        color: FlixieColors.surfaceElevated,
                        child: Icon(Icons.movie_outlined,
                            color: FlixieColors.medium),
                      )
                    : CachedNetworkImage(
                        imageUrl: poster,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const ColoredBox(
                          color: FlixieColors.surfaceElevated,
                          child: Icon(Icons.movie_outlined,
                              color: FlixieColors.medium),
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined,
                            color: FlixieColors.primary, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(dateLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: FlixieColors.primary, fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: FlixieColors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Text(
                      request.requesterId ==
                              context.read<AuthProvider>().dbUser?.id
                          ? 'Planned by you'
                          : 'Planned with friends',
                      style: const TextStyle(
                          color: FlixieColors.medium, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: FlixieColors.medium),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }
}

String _activityFilterLabel(_ActivityFilter filter) => switch (filter) {
      _ActivityFilter.all => 'All',
      _ActivityFilter.watches => 'Watches',
      _ActivityFilter.ratings => 'Ratings',
      _ActivityFilter.reviews => 'Reviews',
      _ActivityFilter.lists => 'Lists',
    };

String _activityDateLabel(String raw) {
  final date = DateTime.tryParse(raw)?.toLocal();
  if (date == null) return 'Earlier';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final value = DateTime(date.year, date.month, date.day);
  final days = today.difference(value).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days > 1 && days < 7) return '$days days ago';
  return '${date.day} ${const [
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
  ][date.month - 1]} ${date.year}';
}

class _ProfileContinueWatching extends StatelessWidget {
  const _ProfileContinueWatching({
    required this.shows,
    required this.onRemove,
  });

  final List<ContinueWatchingShow> shows;
  final ValueChanged<ContinueWatchingShow> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlixieSectionHeader(
          title: 'Continue watching',
          uppercase: false,
          accentHeight: 0,
          titleStyle: TextStyle(
            color: FlixieColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: .5,
          ),
        ),
        const SizedBox(height: 10),
        ContinueWatchingCarousel(
          shows: shows.take(10).toList(),
          contentPadding: EdgeInsets.zero,
          onTap: (show) => context.push(showDetailPath(show.showId)),
          onRemove: onRemove,
        ),
      ],
    );
  }
}

class _ProfileExtrasLoadingIndicator extends StatelessWidget {
  const _ProfileExtrasLoadingIndicator();

  @override
  Widget build(BuildContext context) => const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Text(
            'Updating the rest of your profile…',
            style: TextStyle(color: FlixieColors.medium),
          ),
        ],
      );
}

class _WatchProvidersSummary extends StatelessWidget {
  const _WatchProvidersSummary({
    required this.providers,
    required this.onManage,
  });

  final List<WatchProvider> providers;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: FlixieColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.live_tv_outlined, color: FlixieColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Watch providers',
                  style: TextStyle(
                    color: FlixieColors.light,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  providers.isEmpty
                      ? 'Choose where you stream'
                      : providers
                              .take(3)
                              .map((provider) => provider.providerName)
                              .join(' · ') +
                          (providers.length > 3
                              ? ' +${providers.length - 3}'
                              : ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FlixieColors.medium,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onManage,
            child: const Text('Manage'),
          ),
        ],
      ),
    );
  }
}

// Retained during the profile migration for hot-reload compatibility.
// ignore: unused_element
class _StatsBreakdown extends StatelessWidget {
  const _StatsBreakdown({
    required this.watchedMovies,
    required this.watchedShows,
    required this.watchlistMovies,
    required this.watchlistShows,
    required this.ratings,
    required this.averageRating,
    required this.reviews,
    required this.lists,
    required this.friends,
    required this.activity,
  });

  final int watchedMovies;
  final int watchedShows;
  final int watchlistMovies;
  final int watchlistShows;
  final int ratings;
  final String averageRating;
  final int reviews;
  final int lists;
  final int friends;
  final int activity;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      (Icons.movie_outlined, 'Movies watched', '$watchedMovies'),
      (Icons.tv_outlined, 'Shows watched', '$watchedShows'),
      (Icons.bookmark_outline_rounded, 'Movies saved', '$watchlistMovies'),
      (Icons.live_tv_outlined, 'Shows saved', '$watchlistShows'),
      (Icons.star_outline_rounded, 'Ratings', '$ratings'),
      (Icons.insights_outlined, 'Average rating', averageRating),
      (Icons.rate_review_outlined, 'Reviews', '$reviews'),
      (Icons.playlist_play_rounded, 'Lists', '$lists'),
      (Icons.people_outline_rounded, 'Friends', '$friends'),
      (Icons.bolt_outlined, 'Activity', '$activity'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your numbers',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: FlixieColors.light,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.2,
          ),
          itemBuilder: (context, index) {
            final metric = metrics[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: FlixieColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: FlixieColors.tabBarBorder),
              ),
              child: Row(
                children: [
                  Icon(metric.$1, color: FlixieColors.primary, size: 19),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          metric.$3,
                          style: const TextStyle(
                            color: FlixieColors.light,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          metric.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: FlixieColors.medium,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ProfileDashboard extends StatelessWidget {
  const _ProfileDashboard({
    required this.watched,
    required this.watchlist,
    required this.favorites,
    required this.onWatchHistory,
    required this.onWatchlist,
    required this.onFavourites,
    required this.onRecap,
  });

  final int watched;
  final int watchlist;
  final int favorites;
  final VoidCallback onWatchHistory;
  final VoidCallback onWatchlist;
  final VoidCallback onFavourites;
  final VoidCallback onRecap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Expanded(
              child: _DashboardMetric(
                icon: Icons.visibility_outlined,
                label: 'Watched',
                value: '$watched',
                onTap: onWatchHistory,
              ),
            ),
            Container(width: 1, height: 48, color: FlixieColors.tabBarBorder),
            Expanded(
              child: _DashboardMetric(
                icon: Icons.bookmark_border_rounded,
                label: 'Watchlist',
                value: '$watchlist',
                onTap: onWatchlist,
              ),
            ),
            Container(width: 1, height: 48, color: FlixieColors.tabBarBorder),
            Expanded(
              child: _DashboardMetric(
                icon: Icons.favorite_border_rounded,
                label: 'Favourites',
                value: '$favorites',
                onTap: onFavourites,
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(value,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: FlixieColors.white,
                fontWeight: FontWeight.w900,
                fontSize: 24)),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: FlixieColors.medium,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _ProfileTabSelector extends StatelessWidget {
  const _ProfileTabSelector({
    required this.selected,
    required this.onSelected,
  });

  final _ProfileTab selected;
  final ValueChanged<_ProfileTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
        children: _ProfileTab.values
            .map((tab) => Expanded(
                  child: Semantics(
                    selected: tab == selected,
                    button: true,
                    child: InkWell(
                      onTap: () => onSelected(tab),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 4),
                        decoration: BoxDecoration(
                            border: Border(
                                bottom: BorderSide(
                                    width: tab == selected ? 3 : 1,
                                    color: tab == selected
                                        ? FlixieColors.primary
                                        : FlixieColors.tabBarBorder))),
                        child: Text(_tabLabel(tab),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: tab == selected
                                    ? FlixieColors.white
                                    : FlixieColors.light,
                                fontWeight: tab == selected
                                    ? FontWeight.w700
                                    : FontWeight.w500)),
                      ),
                    ),
                  ),
                ))
            .toList());
  }

  String _tabLabel(_ProfileTab tab) {
    return switch (tab) {
      _ProfileTab.library => 'Library',
      _ProfileTab.activity => 'Activity',
      _ProfileTab.social => 'Social',
      _ProfileTab.stats => 'Stats',
    };
  }
}

class _ProfileEmptyAction extends StatelessWidget {
  const _ProfileEmptyAction({
    required this.icon,
    required this.title,
    required this.body,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String body;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FlixieColors.tabBarBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: FlixieColors.primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: FlixieColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: FlixieColors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: const TextStyle(
                    color: FlixieColors.medium,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            tooltip: label,
            onPressed: onPressed,
            style: IconButton.styleFrom(
              backgroundColor: FlixieColors.primary,
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
        ],
      ),
    );
  }
}

class _ProfileTabsDelegate extends SliverPersistentHeaderDelegate {
  _ProfileTabsDelegate({required this.child, required this.height});
  final Widget child;
  final double height;
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      ColoredBox(
          color: FlixieColors.background,
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: child));
  @override
  bool shouldRebuild(covariant _ProfileTabsDelegate oldDelegate) => true;
}

class _ExtraViewingStats extends StatelessWidget {
  const _ExtraViewingStats(
      {required this.insights, required this.year, required this.movies});
  final int movies;
  final Map<String, dynamic> insights;
  final int year;

  void _showBreakdown(BuildContext context, String title, List<dynamic> rows,
      {bool ratings = false}) {
    showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (context) => SizedBox(
              height: MediaQuery.sizeOf(context).height * .65,
              child: Column(children: [
                Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Expanded(
                          child: Text(title,
                              style: Theme.of(context).textTheme.titleLarge)),
                      IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close)),
                    ])),
                Expanded(
                    child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                      Text(
                          ratings
                              ? 'All-time movie ratings · Minimum 3 ratings per genre'
                              : 'Unique movies watched in $year',
                          style: const TextStyle(color: FlixieColors.medium)),
                      if (rows.isEmpty)
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Text('Not enough logged data yet.')),
                      for (final row in rows)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${row['name']}'),
                          subtitle:
                              ratings ? Text('${row['count']} ratings') : null,
                          trailing: Text(ratings
                              ? '${(row['average'] as num).toStringAsFixed(1)}/10'
                              : '${row['count']}'),
                        ),
                    ])),
              ]),
            ));
  }

  @override
  Widget build(BuildContext context) {
    final first = (insights['firstWatches'] as num).toInt();
    final repeat = (insights['rewatches'] as num).toInt();
    final distribution = (insights['distribution'] as List).cast<num>();
    final peak = distribution.fold<num>(1, (a, b) => a > b ? a : b);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 20),
      const Text('Your viewing',
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: FlixieColors.white)),
      const SizedBox(height: 4),
      Text('Based on your watch logs · $year',
          style: const TextStyle(color: FlixieColors.medium, fontSize: 13)),
      const SizedBox(height: 18),
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(child: _ViewingTotal('$movies', 'Movies')),
        Container(width: 1, height: 36, color: FlixieColors.tabBarBorder),
        Expanded(child: _ViewingTotal('${insights['episodes']}', 'Episodes')),
        Container(width: 1, height: 36, color: FlixieColors.tabBarBorder),
        Expanded(child: _ViewingTotal('${insights['shows']}', 'Shows')),
      ]),
      const SizedBox(height: 22),
      const Divider(color: FlixieColors.tabBarBorder),
      const SizedBox(height: 16),
      const Text('First watches & rewatches',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 14),
      Semantics(
          label: '$first first watches and $repeat rewatches',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
                height: 24,
                child: first + repeat == 0
                    ? const ColoredBox(color: FlixieColors.surfaceElevated)
                    : Row(children: [
                        if (first > 0)
                          Expanded(
                              flex: first,
                              child: const ColoredBox(
                                  color: FlixieColors.primary,
                                  child: SizedBox.expand())),
                        if (repeat > 0)
                          Expanded(
                              flex: repeat,
                              child: const ColoredBox(
                                  color: FlixieColors.primaryText,
                                  child: SizedBox.expand())),
                      ])),
          )),
      const SizedBox(height: 12),
      Wrap(spacing: 20, runSpacing: 8, children: [
        _WatchLegend(
            color: FlixieColors.primary, label: '$first first watches'),
        _WatchLegend(
            color: FlixieColors.primaryText, label: '$repeat rewatches'),
      ]),
      const SizedBox(height: 12),
      SizedBox(
          width: double.infinity,
          child: OverflowBar(
              alignment: MainAxisAlignment.spaceBetween,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: 12,
              children: [
                const Text('Based on your recorded movie history.',
                    style: TextStyle(color: FlixieColors.medium, fontSize: 12)),
                Text('${first + repeat} total',
                    style: const TextStyle(
                        color: FlixieColors.medium, fontSize: 12)),
              ])),
      const SizedBox(height: 22),
      const Divider(color: FlixieColors.tabBarBorder),
      const SizedBox(height: 16),
      const Text('How you rate · All time',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < distribution.length; i++)
              Semantics(
                  label: '${i + 1} out of 10: ${distribution[i]} ratings',
                  child: ExcludeSemantics(
                      child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Column(children: [
                            Text('${distribution[i]}',
                                style: const TextStyle(fontSize: 12)),
                            SizedBox(
                                width: 26,
                                height: 65,
                                child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Container(
                                        height: distribution[i] == 0
                                            ? 2
                                            : distribution[i] / peak * 65,
                                        color: FlixieColors.primary))),
                            Text('${i + 1}',
                                style: const TextStyle(
                                    color: FlixieColors.medium)),
                          ])))),
          ])),
      const SizedBox(height: 12),
      for (final entry in const {
        'Highest-rated genres': 'highestRatedGenres',
        'Movies by decade': 'decades',
        'Original languages explored': 'languages'
      }.entries)
        ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(entry.key),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showBreakdown(
                context, entry.key, insights[entry.value] as List? ?? [],
                ratings: entry.value == 'highestRatedGenres')),
      const SizedBox(height: 12),
      const Divider(color: FlixieColors.tabBarBorder),
      ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        title: const Text('Watch plans',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: FlixieColors.white)),
        subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
                '${insights['confirmedPlans']} confirmed watches · $year')),
        trailing: const Icon(Icons.chevron_right_rounded,
            color: FlixieColors.primaryText),
        onTap: () => context.push('/watch-requests'),
      ),
    ]);
  }
}

class _ViewingTotal extends StatelessWidget {
  const _ViewingTotal(this.value, this.label);
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value,
            style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: FlixieColors.white)),
        const SizedBox(height: 3),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: FlixieColors.light)),
      ]);
}

class _WatchLegend extends StatelessWidget {
  const _WatchLegend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 7),
        Text(label,
            style: const TextStyle(color: FlixieColors.light, fontSize: 13)),
      ]);
}
