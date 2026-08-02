import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  List<Review> _reviews = [];
  int _reviewCount = 0;
  List<Group> _groups = [];
  List<WatchRequest> _watchRequests = [];
  bool _profileExtrasLoading = true;
  MovieWrapped? _wrapped;
  Map<int, Person> _directorPeople = {};
  Map<int, List<PersonCreditItem>> _directorCredits = {};

  _ProfileTab _selectedTab = _ProfileTab.library;
  _ActivityFilter _activityFilter = _ActivityFilter.all;
  AuthProvider? _authProvider;
  final FriendActionsController _friendActions =
      FriendActionsController.instance;
  final ProfileLookupController _profileLookup =
      ProfileLookupController.instance;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authProvider ??= context.read<AuthProvider>();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authProvider?.addListener(_onAuthChanged);
      _loadAll();
    });
  }

  @override
  void dispose() {
    _authProvider?.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final auth = _authProvider;
    final userId = auth?.dbUser?.id;
    final version = auth?.activityVersion ?? -1;
    if (userId != null &&
        (userId != _loadedForUserId || version != _lastActivityVersion)) {
      _loadAll();
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

  Future<void> _loadProfileExtras() async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _profileExtrasLoading = false);
      return;
    }
    final libraryFuture = Future.wait<Object>([
      ShowService.getContinueWatching(userId)
          .catchError((_) => <ContinueWatchingShow>[]),
      ProfileLookupController.instance
          .getUserWatchProviders(userId)
          .catchError((_) => <WatchProvider>[]),
    ]);
    final statsFuture = Future.wait<Object>([
      ProfileLookupController.instance
          .getUserMovieReviews(userId)
          .catchError((_) => <Review>[]),
      GroupService.getUserGroups(userId).catchError((_) => <Group>[]),
      RequestService.getWatchRequests(userId)
          .catchError((_) => <WatchRequest>[]),
      UserService.getMovieWrapped(userId, DateTime.now().year)
          .catchError((_) => MovieWrapped(
                year: DateTime.now().year,
                totalMoviesWatched: 0,
                rewatchCount: 0,
                totalHoursWatched: 0,
                topGenres: const [],
                topDirectors: const [],
                topMovies: const [],
                highestRatedMovies: const [],
                monthlyWatchCounts: const [],
              )),
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
      final results = await statsFuture;
      final wrapped = results[5] as MovieWrapped;
      final directorResults = await Future.wait(
        wrapped.topDirectors
            .where((director) => director.personId != null)
            .take(4)
            .map((director) async {
          final id = director.personId!;
          try {
            final values = await Future.wait<Object>([
              PersonService.getPersonById(id),
              PersonService.getPersonCredits(id),
            ]);
            return (
              id: id,
              person: values[0] as Person,
              credits: values[1] as PersonCredits
            );
          } catch (_) {
            return null;
          }
        }),
      );
      if (!mounted) return;
      setState(() {
        _reviews = results[2] as List<Review>;
        _reviewCount = _reviews.length;
        _groups = results[3] as List<Group>;
        _watchRequests = results[4] as List<WatchRequest>;
        _wrapped = wrapped;
        _directorPeople = {
          for (final result in directorResults
              .whereType<({int id, Person person, PersonCredits credits})>())
            result.id: result.person,
        };
        _directorCredits = {
          for (final result in directorResults
              .whereType<({int id, Person person, PersonCredits credits})>())
            result.id: result.credits.knownForCredits,
        };
      });
    } catch (e) {
      logger.e('[ProfileScreen] stats extras load error: $e');
    }
  }

  Future<void> _openWatchProviders() async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WatchProvidersSheet(userId: userId),
    );
    if (mounted) await _loadProfileExtras();
  }

  Future<void> _loadActivity() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.dbUser?.id;
    if (userId == null) return;

    // Use prefetched cache if ready — no spinner needed
    if (auth.cachedActivity != null) {
      if (mounted) {
        setState(() {
          _activity = auth.cachedActivity!;
          _loadedForUserId = userId;
          _lastActivityVersion = auth.activityVersion;
          _activityLoading = false;
        });
      }
      return;
    }

    try {
      final activity = await _profileLookup.getUserActivity(userId);
      if (mounted) {
        setState(() {
          _activity = activity;
          _loadedForUserId = userId;
          _lastActivityVersion = context.read<AuthProvider>().activityVersion;
          _activityLoading = false;
        });
      }
    } catch (e) {
      logger.e('[ProfileScreen] activity load error: $e');
      if (mounted) setState(() => _activityLoading = false);
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

    final favoriteMovies = dbUser?.favoriteMovies ?? [];
    final favoritePeople = dbUser?.favoritePeople ?? [];
    final watchedCount = (dbUser?.watchedMovies?.length ?? 0) +
        (dbUser?.watchedShows?.length ?? 0);
    final watchlistCount = (dbUser?.movieWatchlist?.length ?? 0) +
        (dbUser?.showWatchlist?.length ?? 0);
    final favoritesCount = favoriteMovies.length +
        (dbUser?.favoriteShows?.length ?? 0) +
        favoritePeople.length;
    final averageRating = _averageRatingLabel(_ratings);

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
      body: _activityLoading && _ratingsLoading && _profileExtrasLoading
          ? const ProfileScreenSkeleton()
          : RefreshIndicator(
              color: FlixieColors.primary,
              onRefresh: () async {
                await context.read<AuthProvider>().refreshUserData();
                await _loadAll();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Avatar, name, bio & edit (full-width, no side padding)
                    ProfileHeader(
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
                    ),

                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ProfileDashboard(
                            watched: watchedCount,
                            watchlist: watchlistCount,
                            favorites: favoritesCount,
                            averageRating: averageRating,
                            onWatchHistory: () =>
                                context.push('/watch-history'),
                            onWatchlist: () => context.push('/watchlist'),
                            onFavourites: () => setState(
                                () => _selectedTab = _ProfileTab.library),
                            onRecap: () => context.push('/stats'),
                          ),
                          const SizedBox(height: 18),
                          _ProfileTabSelector(
                            selected: _selectedTab,
                            onSelected: (tab) =>
                                setState(() => _selectedTab = tab),
                          ),
                          const SizedBox(height: 16),
                          _buildSelectedTabContent(
                            context: context,
                            textTheme: textTheme,
                            userId: userId,
                            favoriteMovies: favoriteMovies,
                            favoritePeople: favoritePeople,
                            favoriteShows: dbUser?.favoriteShows ?? const [],
                            favoriteGenres: dbUser?.favoriteGenres ?? const [],
                            user: dbUser,
                            visibleActivity: visibleActivity,
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                ),
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
    if (_profileExtrasLoading) {
      return const _ProfileLibraryLoadingState();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (favoriteMovies.isNotEmpty ||
            favoritePeople.isNotEmpty ||
            favoriteShows.isNotEmpty) ...[
          _FavouritesLibrary(
            movies: favoriteMovies,
            people: favoritePeople,
            shows: favoriteShows,
          ),
          const SizedBox(height: 20),
        ] else
          _ProfileEmptyAction(
            icon: Icons.favorite_outline_rounded,
            title: 'No favourite movies yet',
            body: 'Favourite a few movies so your profile feels like you.',
            label: 'Find movies',
            onPressed: () => context.push('/search'),
          ),
        if (userId != null) ...[
          if (_continueWatching.isNotEmpty) ...[
            _ProfileContinueWatching(shows: _continueWatching),
            const SizedBox(height: 20),
          ],
          ListsPreviewSection(
            userId: userId,
            title: 'Your lists',
            emptyMessage: "You haven't created any lists yet.",
            allowManage: true,
            embedded: true,
          ),
          const SizedBox(height: 16),
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
        _ProfileActionGrid(
          actions: [
            _ProfileAction(
              icon: Icons.bookmarks_outlined,
              label: 'Lists',
              onTap: () => context.push('/movie-lists'),
            ),
            _ProfileAction(
              icon: Icons.star_outline,
              label: 'Reviews',
              onTap: () => context.push('/my-reviews'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActivityTab(
    BuildContext context,
    TextTheme textTheme,
    List<ActivityListItem> visibleActivity,
  ) {
    final filtered = _activity.where((item) {
      return switch (_activityFilter) {
        _ActivityFilter.all => true,
        _ActivityFilter.watches => item.type == ActivityListType.movieWatched ||
            item.type == ActivityListType.showWatched,
        _ActivityFilter.ratings => item.type == ActivityListType.movieRating ||
            item.type == ActivityListType.showRating,
        _ActivityFilter.reviews => item.type == ActivityListType.movieReview ||
            item.type == ActivityListType.showReview,
        _ActivityFilter.lists => item.type == ActivityListType.movieWatchlist ||
            item.type == ActivityListType.showWatchlist,
      };
    }).toList();
    final grouped = <String, List<ActivityListItem>>{};
    for (final item in filtered) {
      grouped
          .putIfAbsent(_activityDateLabel(item.timestamp), () => [])
          .add(item);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _ActivityFilter.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final filter = _ActivityFilter.values[index];
              final selected = filter == _activityFilter;
              return ChoiceChip(
                showCheckmark: false,
                selected: selected,
                label: Text(_activityFilterLabel(filter)),
                onSelected: (_) => setState(() => _activityFilter = filter),
                selectedColor: FlixieColors.primary.withValues(alpha: .17),
                backgroundColor: Colors.transparent,
                side: BorderSide(
                  color: selected
                      ? FlixieColors.primary
                      : FlixieColors.tabBarBorder,
                ),
                labelStyle: TextStyle(
                  color: selected ? FlixieColors.primary : FlixieColors.light,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        Text(
          '${filtered.length} ${filtered.length == 1 ? 'activity' : 'activities'} this month',
          style: textTheme.bodyMedium?.copyWith(color: FlixieColors.medium),
        ),
        const SizedBox(height: 18),
        if (_activityLoading)
          const Center(child: CircularProgressIndicator())
        else if (filtered.isEmpty)
          _ProfileEmptyAction(
            icon: Icons.auto_graph_rounded,
            title:
                'No ${_activityFilterLabel(_activityFilter).toLowerCase()} yet',
            body: 'Your activity will appear here as you use Flixie.',
            label: 'Browse',
            onPressed: () => context.push('/search'),
          )
        else
          ...grouped.entries.expand((entry) => [
                Text(entry.key,
                    style: const TextStyle(
                        color: FlixieColors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                ...entry.value.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ProfileActivityCard(item: item),
                    )),
                const SizedBox(height: 4),
              ]),
      ],
    );
  }

  Widget _buildSocialTab(BuildContext context) {
    final userId = context.read<AuthProvider>().dbUser?.id ?? '';
    final groups = _groups
        .where((group) => group.status?.toUpperCase() != 'CLOSED')
        .take(3)
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
          onSeeAll: () => context.push('/social'),
        ),
        const SizedBox(height: 10),
        if (groups.isEmpty)
          const Text('No groups yet.',
              style: TextStyle(color: FlixieColors.medium))
        else
          ...groups.map((group) => GroupCard(
                group: group,
                memberCount: group.memberCount,
                onTap: () => context.push('/groups/${group.id}'),
              )),
        if (plans.isNotEmpty) ...[
          const SizedBox(height: 18),
          _SocialSectionHeader(
            title: 'Watch plans',
            count: plans.length,
            onSeeAll: () => context.push('/watch-requests'),
          ),
          const SizedBox(height: 10),
          ...plans.take(2).map((request) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ProfileWatchPlanCard(request: request),
              )),
        ],
        const SizedBox(height: 18),
        const Text('Requests',
            style: TextStyle(
                color: FlixieColors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Material(
          color: FlixieColors.surface.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => context.push('/watch-requests'),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: FlixieColors.tabBarBorder),
              ),
              child: Row(
                children: [
                  Badge(
                    isLabelVisible: needsReply > 0,
                    label: Text('$needsReply'),
                    backgroundColor: FlixieColors.primary,
                    child: const Icon(Icons.person_outline_rounded,
                        color: FlixieColors.primary, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          needsReply == 0
                              ? 'No requests need your reply'
                              : '$needsReply ${needsReply == 1 ? 'request needs' : 'requests need'} your reply',
                          style: const TextStyle(
                              color: FlixieColors.white,
                              fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                            'Friend requests · Group invites · Watch plans',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: FlixieColors.medium, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: FlixieColors.medium),
                ],
              ),
            ),
          ),
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
      ratings: _ratings,
      reviewCount: _reviewCount,
      favoriteGenres: favoriteGenres,
      directorPeople: _directorPeople,
      directorCredits: _directorCredits,
      onWrapped: () => context.push('/wrapped/${user?.id ?? ''}'),
      onFindMovies: () => context.push('/search'),
      onSeeRatings: () => context.push('/stats'),
    );
  }

  String _averageRatingLabel(List<MovieRating> ratings) {
    if (ratings.isEmpty) return '--';
    final total = ratings.fold<int>(0, (sum, rating) => sum + rating.rating);
    return (total / ratings.length).toStringAsFixed(1);
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
          _FavouritePosterRail(title: 'Favourite movies', items: movieItems),
        if (movieItems.isNotEmpty &&
            (peopleItems.isNotEmpty || showItems.isNotEmpty))
          const SizedBox(height: 18),
        if (peopleItems.isNotEmpty)
          _FavouritePosterRail(
            title: 'Favourite people',
            items: peopleItems,
            circular: true,
          ),
        if (peopleItems.isNotEmpty && showItems.isNotEmpty)
          const SizedBox(height: 18),
        if (showItems.isNotEmpty)
          _FavouritePosterRail(title: 'Favourite shows', items: showItems),
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
    this.circular = false,
  });

  final String title;
  final List<_FavouriteDisplayItem> items;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: circular ? 158 : 208,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FlixieSectionHeader(
            title: title,
            uppercase: false,
            accentHeight: 22,
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
          accentHeight: 22,
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
    final poster = review.moviePosterPath;
    final date = DateTime.tryParse(review.createdAt);
    final dateLabel = date == null
        ? ''
        : '${date.day}/${date.month}/${date.year.toString().substring(2)}';

    return SizedBox(
      height: 128,
      child: Material(
        color: FlixieColors.surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: review.movieId == null
              ? null
              : () => context.push('/movies/${review.movieId}'),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: FlixieColors.tabBarBorder),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 82,
                  height: 126,
                  child: poster == null
                      ? const ColoredBox(
                          color: FlixieColors.surfaceElevated,
                          child: Icon(
                            Icons.movie_outlined,
                            color: FlixieColors.medium,
                          ),
                        )
                      : Image.network(
                          'https://image.tmdb.org/t/p/w342$poster',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.movie_outlined),
                        ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                review.movieTitle ?? 'Movie review',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: FlixieColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (dateLabel.isNotEmpty)
                              Text(
                                dateLabel,
                                style: const TextStyle(
                                  color: FlixieColors.medium,
                                  fontSize: 10,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          review.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: FlixieColors.light,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          review.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: FlixieColors.medium,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: FlixieColors.warning,
                              size: 16,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${review.rating}/10',
                              style: const TextStyle(
                                color: FlixieColors.light,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (review.recommended) ...[
                              const SizedBox(width: 10),
                              const Icon(
                                Icons.thumb_up_alt_outlined,
                                color: FlixieColors.success,
                                size: 15,
                              ),
                            ],
                            const Spacer(),
                            if (review.containsSpoilers)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: FlixieColors.warning
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'SPOILER',
                                  style: TextStyle(
                                    color: FlixieColors.warning,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
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
}

class _ProfileStatsContent extends StatelessWidget {
  const _ProfileStatsContent({
    required this.wrapped,
    required this.ratings,
    required this.reviewCount,
    required this.favoriteGenres,
    required this.directorPeople,
    required this.directorCredits,
    required this.onWrapped,
    required this.onFindMovies,
    required this.onSeeRatings,
  });

  final MovieWrapped? wrapped;
  final List<MovieRating> ratings;
  final int reviewCount;
  final List<dynamic> favoriteGenres;
  final Map<int, Person> directorPeople;
  final Map<int, List<PersonCreditItem>> directorCredits;
  final VoidCallback onWrapped;
  final VoidCallback onFindMovies;
  final VoidCallback onSeeRatings;

  @override
  Widget build(BuildContext context) {
    final data = wrapped;
    if (data == null) {
      return const Center(child: CircularProgressIndicator());
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${data.year} so far',
                            style: const TextStyle(
                                color: FlixieColors.primary,
                                fontSize: 18,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(
                          '${data.rewatchCount} watches · ${data.totalMoviesWatched} movies · ${data.totalHoursWatched.toStringAsFixed(1)} hours',
                          style: const TextStyle(
                              color: FlixieColors.medium, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onWrapped,
                    icon: const Icon(Icons.card_giftcard_rounded, size: 17),
                    label: Text('View ${data.year} Wrapped'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 72,
                width: double.infinity,
                child: CustomPaint(
                  painter: _MonthlyStatsPainter(data.monthlyWatchCounts),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (favoriteGenres.isNotEmpty)
          MovieTasteBadge(favoriteGenres: favoriteGenres)
        else
          _ProfileEmptyAction(
            icon: Icons.explore_outlined,
            title: 'Build your taste profile',
            body: 'Rate and favourite movies to reveal your viewing taste.',
            label: 'Find movies',
            onPressed: onFindMovies,
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _StatsMetric(
                    icon: Icons.star_outline_rounded,
                    value: average,
                    label: 'Average rating',
                    subtitle: 'Your scoring style',
                    color: FlixieColors.warning)),
            const SizedBox(width: 10),
            Expanded(
                child: _StatsMetric(
                    icon: Icons.bookmark_added_outlined,
                    value: '${ratings.length}',
                    label: 'Ratings',
                    subtitle: 'Keep it up',
                    color: FlixieColors.primary)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child: _StatsMetric(
                    icon: Icons.chat_bubble_outline_rounded,
                    value: '$reviewCount',
                    label: 'Reviews',
                    subtitle: 'Your voice matters',
                    color: FlixieColors.danger)),
            const SizedBox(width: 10),
            Expanded(
                child: _StatsMetric(
                    icon: Icons.replay_rounded,
                    value: data.topMovies.isEmpty
                        ? '–'
                        : '${data.topMovies.first.watchCount}×',
                    label: data.topMovies.isEmpty
                        ? 'Most rewatched'
                        : data.topMovies.first.title,
                    subtitle: 'Most rewatched',
                    posterPath: data.topMovies.isEmpty
                        ? null
                        : data.topMovies.first.posterPath,
                    color: FlixieColors.danger)),
          ],
        ),
        if (data.topGenres.isNotEmpty) ...[
          const SizedBox(height: 12),
          _StatsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Top genres',
                    style: TextStyle(
                        color: FlixieColors.primary,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                ...data.topGenres.take(4).toList().asMap().entries.map((entry) {
                  final genre = entry.value;
                  const colors = [
                    FlixieColors.success,
                    FlixieColors.danger,
                    Color(0xFF5B8DEF),
                    FlixieColors.warning
                  ];
                  final color = colors[entry.key % colors.length];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      Icon(Icons.explore_outlined, color: color, size: 17),
                      const SizedBox(width: 7),
                      SizedBox(
                          width: 82,
                          child: Text(genre.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: FlixieColors.light,
                                  fontWeight: FontWeight.w700))),
                      Expanded(
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                  value: genre.count / maxGenre,
                                  minHeight: 5,
                                  backgroundColor: FlixieColors.surfaceElevated,
                                  color: color))),
                      const SizedBox(width: 10),
                      Text('${genre.count}',
                          style: const TextStyle(color: FlixieColors.medium)),
                    ]),
                  );
                }),
              ],
            ),
          ),
        ],
        if (data.topDirectors.isNotEmpty) ...[
          const SizedBox(height: 12),
          _StatsCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Top directors',
                  style: TextStyle(
                      color: FlixieColors.primary,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              SizedBox(
                height: 132,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: data.topDirectors.take(4).length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, index) {
                    final director = data.topDirectors[index];
                    final id = director.personId;
                    return _TopDirectorCard(
                      director: director,
                      person: id == null ? null : directorPeople[id],
                      credits: id == null
                          ? const []
                          : directorCredits[id] ?? const [],
                    );
                  },
                ),
              ),
            ]),
          ),
        ],
        if (ratings.isNotEmpty) ...[
          const SizedBox(height: 12),
          _StatsCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('Recent ratings',
                    style: TextStyle(
                        color: FlixieColors.primary,
                        fontWeight: FontWeight.w800)),
                const Spacer(),
                TextButton(
                    onPressed: onSeeRatings, child: const Text('See all')),
              ]),
              SizedBox(
                height: 170,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: ratings.take(8).length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, index) =>
                      _RecentRatingTile(rating: ratings[index]),
                ),
              ),
            ]),
          ),
        ],
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: FlixieColors.surface.withValues(alpha: .68),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: FlixieColors.tabBarBorder)),
        child: child,
      );
}

class _StatsMetric extends StatelessWidget {
  const _StatsMetric(
      {required this.icon,
      required this.value,
      required this.label,
      required this.subtitle,
      this.posterPath,
      required this.color});
  final IconData icon;
  final String value;
  final String label;
  final String subtitle;
  final String? posterPath;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          color.withValues(alpha: .11),
          FlixieColors.surface.withValues(alpha: .76),
        ]),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Row(children: [
        Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: .55))),
            child: Icon(icon, color: color, size: 21)),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: FlixieColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900)),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(color: FlixieColors.light, fontSize: 11.5)),
          Text(subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  TextStyle(color: color.withValues(alpha: .82), fontSize: 10))
        ])),
        if (posterPath != null) ...[
          const SizedBox(width: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: CachedNetworkImage(
              imageUrl: posterPath!.startsWith('http')
                  ? posterPath!
                  : 'https://image.tmdb.org/t/p/w185$posterPath',
              width: 32,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ]));
}

class _TopDirectorCard extends StatelessWidget {
  const _TopDirectorCard({
    required this.director,
    required this.person,
    required this.credits,
  });
  final WrappedNamedCount director;
  final Person? person;
  final List<PersonCreditItem> credits;

  @override
  Widget build(BuildContext context) {
    final profile = person?.profileImgUrl;
    final visibleCredits =
        credits.where((credit) => credit.posterPath != null).take(4).toList();
    return GestureDetector(
      onTap: director.personId == null
          ? null
          : () => context.push('/people/${director.personId}'),
      child: SizedBox(
        width: 260,
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border:
                  Border.all(color: FlixieColors.primary.withValues(alpha: .7)),
            ),
            child: CircleAvatar(
              radius: 37,
              backgroundColor: FlixieColors.surfaceElevated,
              backgroundImage: profile == null
                  ? null
                  : CachedNetworkImageProvider(
                      'https://image.tmdb.org/t/p/w185$profile'),
              child: profile == null
                  ? const Icon(Icons.person_outline, color: FlixieColors.medium)
                  : null,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(director.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: FlixieColors.white,
                            fontWeight: FontWeight.w800)),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: FlixieColors.medium, size: 18),
                ]),
                Text('${director.count} films',
                    style: const TextStyle(
                        color: FlixieColors.medium, fontSize: 12)),
                const SizedBox(height: 7),
                SizedBox(
                  height: 52,
                  child: Row(
                    children: visibleCredits
                        .map((credit) => Padding(
                              padding: const EdgeInsets.only(right: 5),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: CachedNetworkImage(
                                  imageUrl:
                                      'https://image.tmdb.org/t/p/w92${credit.posterPath}',
                                  width: 34,
                                  height: 52,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _RecentRatingTile extends StatelessWidget {
  const _RecentRatingTile({required this.rating});
  final MovieRating rating;
  @override
  Widget build(BuildContext context) {
    final path = rating.movie?.posterPath;
    return GestureDetector(
      onTap: () => context.push('/movies/${rating.movieId}'),
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

class _MonthlyStatsPainter extends CustomPainter {
  _MonthlyStatsPainter(this.values);
  final List<WrappedMonthlyCount> values;
  @override
  void paint(Canvas canvas, Size size) {
    final counts = List<double>.filled(12, 0);
    for (final value in values) {
      if (value.month >= 1 && value.month <= 12) {
        counts[value.month - 1] = value.count.toDouble();
      }
    }
    final max = counts.fold<double>(1, (a, b) => a > b ? a : b);
    final line = Paint()
      ..color = FlixieColors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    for (var i = 0; i < 12; i++) {
      final x = i * size.width / 11;
      final y = 42 - (counts[i] / max * 34);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, line);
    const labels = [
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
    for (var i = 0; i < 12; i++) {
      final painter = TextPainter(
          text: TextSpan(
              text: labels[i],
              style: const TextStyle(color: FlixieColors.medium, fontSize: 9)),
          textDirection: TextDirection.ltr)
        ..layout();
      painter.paint(
          canvas, Offset(i * size.width / 11 - painter.width / 2, 54));
    }
  }

  @override
  bool shouldRepaint(covariant _MonthlyStatsPainter oldDelegate) =>
      oldDelegate.values != values;
}

class _SocialSectionHeader extends StatelessWidget {
  const _SocialSectionHeader({
    required this.title,
    required this.onSeeAll,
    this.count,
  });

  final String title;
  final int? count;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(title,
              style: const TextStyle(
                  color: FlixieColors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
          const Spacer(),
          TextButton(onPressed: onSeeAll, child: const Text('See all')),
        ],
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
  if (days < 7) return '$days days ago';
  return '${date.day}/${date.month}/${date.year}';
}

class _ProfileActivityCard extends StatelessWidget {
  const _ProfileActivityCard({required this.item});

  final ActivityListItem item;

  bool get _isWatch =>
      item.type == ActivityListType.movieWatched ||
      item.type == ActivityListType.showWatched;
  bool get _isRating =>
      item.type == ActivityListType.movieRating ||
      item.type == ActivityListType.showRating;
  bool get _isReview =>
      item.type == ActivityListType.movieReview ||
      item.type == ActivityListType.showReview;
  bool get _isFavourite =>
      item.type == ActivityListType.favoriteMovie ||
      item.type == ActivityListType.favoriteShow ||
      item.type == ActivityListType.favoritePerson;

  String get _action {
    if (_isFavourite) return 'You added';
    if (_isWatch) {
      final count = item.watchCount ?? (item.isRewatch ? 2 : 1);
      return count > 1 ? 'You logged watch #$count of' : 'You watched';
    }
    if (_isRating) return 'You rated';
    if (_isReview) return 'You reviewed';
    if (item.type == ActivityListType.movieWatchlist ||
        item.type == ActivityListType.showWatchlist) {
      return 'You added';
    }
    return 'You updated';
  }

  String? get _suffix {
    if (_isFavourite) return 'to favourites';
    if (item.type == ActivityListType.movieWatchlist ||
        item.type == ActivityListType.showWatchlist) {
      return 'to your watchlist';
    }
    return null;
  }

  Color get _accent {
    if (_isFavourite) return Colors.redAccent;
    if (_isWatch) return FlixieColors.success;
    if (_isRating) return FlixieColors.warning;
    if (_isReview) return FlixieColors.secondary;
    return FlixieColors.primary;
  }

  IconData get _chipIcon {
    if (_isFavourite) return Icons.favorite_rounded;
    if (_isWatch) return Icons.check_rounded;
    if (_isRating) return Icons.star_rounded;
    if (_isReview) return Icons.rate_review_outlined;
    return Icons.bookmark_outline_rounded;
  }

  String get _chipLabel {
    if (_isFavourite) return 'Favourite';
    if (_isWatch) return item.isRewatch ? 'Watched again' : 'Watched';
    if (_isRating) return '${_rating(item.mediaRating)}/10';
    if (_isReview) return 'Reviewed';
    return 'Watchlist';
  }

  String _rating(double? value) {
    if (value == null) return '–';
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  void _open(BuildContext context) {
    if (item.movieId != null) context.push('/movies/${item.movieId}');
    if (item.showId != null) context.push('/shows/${item.showId}');
    if (item.personId != null) context.push('/people/${item.personId}');
  }

  @override
  Widget build(BuildContext context) {
    final rawPoster = item.mediaPosterPath;
    final poster = rawPoster == null || rawPoster.isEmpty
        ? null
        : rawPoster.startsWith('http')
            ? rawPoster
            : 'https://image.tmdb.org/t/p/w342$rawPoster';
    final excerpt = item.reviewData?.body.trim().isNotEmpty == true
        ? item.reviewData!.body.trim()
        : item.notes?.trim();

    return Material(
      color: FlixieColors.surface.withValues(alpha: .72),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
        child: Container(
          height: (excerpt ?? '').isNotEmpty ? 168 : 144,
          decoration: BoxDecoration(
            border: Border.all(color: FlixieColors.tabBarBorder),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 92,
                child: poster == null
                    ? Container(
                        color: FlixieColors.surfaceElevated,
                        child: const Icon(Icons.movie_outlined,
                            color: FlixieColors.medium),
                      )
                    : CachedNetworkImage(
                        imageUrl: poster,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: FlixieColors.surfaceElevated,
                          child: const Icon(Icons.movie_outlined,
                              color: FlixieColors.medium),
                        ),
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          style: const TextStyle(
                              color: FlixieColors.light,
                              fontSize: 14,
                              height: 1.4),
                          children: [
                            TextSpan(text: '$_action '),
                            TextSpan(
                              text: item.mediaTitle ?? 'Untitled',
                              style: const TextStyle(
                                  color: FlixieColors.white,
                                  fontWeight: FontWeight.w800),
                            ),
                            if (_suffix != null) TextSpan(text: ' $_suffix'),
                          ],
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 10,
                        runSpacing: 7,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: _accent),
                              color: _accent.withValues(alpha: .1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_chipIcon, color: _accent, size: 14),
                                const SizedBox(width: 5),
                                Text(_chipLabel,
                                    style: TextStyle(
                                        color: _accent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                          if (item.recommended != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  item.recommended!
                                      ? Icons.thumb_up_alt_outlined
                                      : Icons.thumb_down_alt_outlined,
                                  color: item.recommended!
                                      ? FlixieColors.success
                                      : FlixieColors.danger,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  item.recommended!
                                      ? 'Recommends'
                                      : "Doesn't recommend",
                                  style: TextStyle(
                                      color: item.recommended!
                                          ? FlixieColors.success
                                          : FlixieColors.danger,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                        ],
                      ),
                      if ((excerpt ?? '').isNotEmpty) ...[
                        const SizedBox(height: 9),
                        Text('“$excerpt”',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: FlixieColors.medium,
                                fontStyle: FontStyle.italic,
                                fontSize: 12.5)),
                      ],
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.chevron_right_rounded,
                    color: FlixieColors.medium),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileContinueWatching extends StatelessWidget {
  const _ProfileContinueWatching({required this.shows});

  final List<ContinueWatchingShow> shows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlixieSectionHeader(
          title: 'Continue watching',
          uppercase: false,
          accentHeight: 22,
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
          onTap: (show) => context.push('/shows/${show.showId}'),
        ),
      ],
    );
  }
}

class _ProfileLibraryLoadingState extends StatelessWidget {
  const _ProfileLibraryLoadingState();

  @override
  Widget build(BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FlixieSectionHeader(
            title: 'Favourite movies',
            uppercase: false,
            accentHeight: 22,
            titleStyle: TextStyle(
              color: FlixieColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 10),
          Row(children: [
            Expanded(child: _ProfileLibrarySkeletonCard()),
            SizedBox(width: 8),
            Expanded(child: _ProfileLibrarySkeletonCard()),
            SizedBox(width: 8),
            Expanded(child: _ProfileLibrarySkeletonCard()),
            SizedBox(width: 8),
            Expanded(child: _ProfileLibrarySkeletonCard()),
          ]),
          SizedBox(height: 18),
          FlixieSectionHeader(
            title: 'Favourite people',
            uppercase: false,
            accentHeight: 22,
            titleStyle: TextStyle(
              color: FlixieColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 10),
          Row(children: [
            Expanded(child: _ProfileLibrarySkeletonPerson()),
            SizedBox(width: 8),
            Expanded(child: _ProfileLibrarySkeletonPerson()),
            SizedBox(width: 8),
            Expanded(child: _ProfileLibrarySkeletonPerson()),
            SizedBox(width: 8),
            Expanded(child: _ProfileLibrarySkeletonPerson()),
          ]),
          SizedBox(height: 18),
          FlixieSectionHeader(
            title: 'Favourite shows',
            uppercase: false,
            accentHeight: 22,
            titleStyle: TextStyle(
              color: FlixieColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 10),
          Row(children: [
            Expanded(child: _ProfileLibrarySkeletonCard()),
            SizedBox(width: 8),
            Expanded(child: _ProfileLibrarySkeletonCard()),
            SizedBox(width: 8),
            Expanded(child: _ProfileLibrarySkeletonCard()),
            SizedBox(width: 8),
            Expanded(child: _ProfileLibrarySkeletonCard()),
          ]),
          SizedBox(height: 20),
          FlixieSectionHeader(
            title: 'Continue watching',
            uppercase: false,
            accentHeight: 22,
            titleStyle: TextStyle(
              color: FlixieColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 10),
          Row(children: [
            Expanded(child: SkeletonBox(height: 108, borderRadius: 14)),
            SizedBox(width: 8),
            Expanded(child: SkeletonBox(height: 108, borderRadius: 14)),
          ]),
          SizedBox(height: 20),
          FlixieSectionHeader(
            title: 'Your lists',
            uppercase: false,
            accentHeight: 22,
            titleStyle: TextStyle(
              color: FlixieColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 12),
          SkeletonBox(height: 86, borderRadius: 14),
          SizedBox(height: 10),
          SkeletonBox(height: 86, borderRadius: 14),
        ],
      );
}

class _ProfileLibrarySkeletonCard extends StatelessWidget {
  const _ProfileLibrarySkeletonCard();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SkeletonBox(height: 154, borderRadius: 14),
          SizedBox(height: 8),
          SkeletonBox(height: 12, borderRadius: 4),
        ],
      );
}

class _ProfileLibrarySkeletonPerson extends StatelessWidget {
  const _ProfileLibrarySkeletonPerson();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: const [
          Center(child: SkeletonBox(width: 78, height: 78, borderRadius: 39)),
          SizedBox(height: 8),
          SkeletonBox(width: double.infinity, height: 12, borderRadius: 4),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FlixieColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FlixieColors.tabBarBorder),
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
                          .join(' · '),
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
    required this.averageRating,
    required this.onWatchHistory,
    required this.onWatchlist,
    required this.onFavourites,
    required this.onRecap,
  });

  final int watched;
  final int watchlist;
  final int favorites;
  final String averageRating;
  final VoidCallback onWatchHistory;
  final VoidCallback onWatchlist;
  final VoidCallback onFavourites;
  final VoidCallback onRecap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Taste snapshot',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: FlixieColors.light,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const Spacer(),
            TextButton(
              onPressed: onRecap,
              child: const Text('View stats'),
            ),
          ],
        ),
        SizedBox(
          height: 68,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              SizedBox(
                width: 122,
                child: _DashboardMetric(
                  icon: Icons.visibility_outlined,
                  label: 'Watched',
                  value: '$watched',
                  onTap: onWatchHistory,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 122,
                child: _DashboardMetric(
                  icon: Icons.bookmark_border_rounded,
                  label: 'Watchlist',
                  value: '$watchlist',
                  onTap: onWatchlist,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 122,
                child: _DashboardMetric(
                  icon: Icons.favorite_border_rounded,
                  label: 'Favourites',
                  value: '$favorites',
                  onTap: onFavourites,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 122,
                child: _DashboardMetric(
                  icon: Icons.star_border_rounded,
                  label: 'Avg rating',
                  value: averageRating,
                ),
              ),
            ],
          ),
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
    return Material(
      color: FlixieColors.surfaceElevated,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: FlixieColors.primary, size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: FlixieColors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: FlixieColors.medium,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
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
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _ProfileTab.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tab = _ProfileTab.values[index];
          final isSelected = tab == selected;
          return ChoiceChip(
            selected: isSelected,
            avatar: Icon(
              _tabIcon(tab),
              size: 16,
              color: isSelected ? Colors.black : FlixieColors.medium,
            ),
            label: Text(_tabLabel(tab)),
            selectedColor: FlixieColors.primary,
            backgroundColor: FlixieColors.tabBarBackgroundFocused,
            labelStyle: TextStyle(
              color: isSelected ? Colors.black : FlixieColors.light,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
            side: BorderSide(
              color: isSelected
                  ? FlixieColors.primary
                  : Colors.white.withValues(alpha: 0.08),
            ),
            onSelected: (_) => onSelected(tab),
          );
        },
      ),
    );
  }

  IconData _tabIcon(_ProfileTab tab) {
    return switch (tab) {
      _ProfileTab.library => Icons.video_library_outlined,
      _ProfileTab.activity => Icons.timeline_rounded,
      _ProfileTab.social => Icons.group_outlined,
      _ProfileTab.stats => Icons.insights_outlined,
    };
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

class _ProfileAction {
  const _ProfileAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _ProfileActionGrid extends StatelessWidget {
  const _ProfileActionGrid({required this.actions});

  final List<_ProfileAction> actions;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 3.6,
      children: actions
          .map(
            (action) => Material(
              color: FlixieColors.tabBarBackgroundFocused,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: action.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(action.icon, color: FlixieColors.primary, size: 19),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          action.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: FlixieColors.light,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: FlixieColors.medium,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}
