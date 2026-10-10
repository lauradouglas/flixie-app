import 'package:flixie_app/core/widgets/watchlist_widget_sync.dart';
import 'package:flixie_app/features/movies/data/show_service.dart';
import 'package:flixie_app/features/social/data/starred_people.dart';
import 'package:flixie_app/features/social/data/people_cache.dart';
import 'package:flixie_app/features/social/data/community_service.dart';
import 'package:flixie_app/features/profile/data/milestone_cache.dart';
import 'package:flixie_app/core/safety/safety_service.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flixie_app/core/auth/startup_trace.dart';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/favorite_movie.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/movie_rating.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/models/movie_list.dart';
import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/models/user.dart' as models;
import 'package:flixie_app/models/watched_movie.dart';
import 'package:flixie_app/models/watchlist_movie.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/models/watch_request.dart';
import 'package:flixie_app/models/profile_avatar.dart';
import 'package:flixie_app/core/auth/auth_notification_poller.dart';
import 'package:flixie_app/core/auth/auth_prefetch_coordinator.dart';
import 'package:flixie_app/core/auth/auth_prefetch_snapshot.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_service.dart';
import 'package:flixie_app/core/auth/social_auth_provider.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/core/auth/push_notification_service.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/features/profile/data/avatar_service.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/core/utils/app_icon_badge_service.dart';
import 'package:flixie_app/core/auth/auth_account_cache.dart';
import 'package:flixie_app/core/auth/auth_session_recovery.dart';

/// Auth states that the UI can observe.
enum AuthStatus { unknown, authenticated, unauthenticated }

typedef BackendProfileCreator = Future<models.User> Function(
    Map<String, dynamic> body);
typedef BackendProfileLoader = Future<models.User?> Function(String externalId);
typedef AvatarSelector = Future<ProfileAvatar> Function(int avatarId);

/// Exposes Firebase auth state to the widget tree via [ChangeNotifier].
///
/// Screens can read [status], [firebaseUser], [dbUser], [isLoading] and [errorMessage] and call
/// [signIn], [signUp], [signOut] and [sendPasswordResetEmail].
class AuthProvider extends ChangeNotifier with WidgetsBindingObserver {
  final _watchlistWidget = WatchlistWidgetSync();

  @override
  void notifyListeners() {
    _watchlistWidget.sync(_dbUser);
    super.notifyListeners();
  }

  late final AuthAccountCache _accountCache;
  List<ActivityListItem>? get cachedFriendsActivity =>
      _accountCache.cachedFriendsActivity;
  AuthProvider(
    this._authService,
    MovieService movieService, {
    AuthPrefetchCoordinator? prefetchCoordinator,
    BackendProfileCreator? profileCreator,
    BackendProfileLoader? profileLoader,
    Future<bool> Function()? termsStatusLoader,
    bool prefetchAfterAuth = true,
    AvatarSelector? avatarSelector,
  })  : _prefetchCoordinator = prefetchCoordinator ??
            AuthPrefetchCoordinator(movieService: movieService),
        _profileCreator = profileCreator ?? UserService.createUser {
    _accountCache = AuthAccountCache(_prefetchCoordinator);
    _profileLoader = profileLoader ?? UserService.getUserByExternalId;
    _termsStatusLoader = termsStatusLoader ??
        () async {
          final response = await ApiClient.get('/users/me/terms');
          return response is Map && response['accepted'] == true;
        };
    _prefetchAfterAuth = prefetchAfterAuth;
    _avatarSelector = avatarSelector ?? AvatarService.selectAvatar;
    WidgetsBinding.instance.addObserver(this);
    ApiClient.setAuthTokenRefresher(_authService.refreshIdToken);
    _recovery = AuthSessionRecovery(
      user: () => _firebaseUser,
      loadProfile: _profileLoader,
      applyProfile: (profile) {
        _dbUser = profile;
        notifyListeners();
      },
      onExpired: () => _onAuthStateChanged(null),
      onChanged: notifyListeners,
      canResume: () => _status == AuthStatus.authenticated,
      onResumeSuccess: _onResumeRecovered,
      onThrottledResume: _startNotificationPoller,
      onRetry: _retrySessionRecovery,
    );
    _recovery.startBootstrap(() => _status == AuthStatus.unknown);
    _authStateSubscription = _authService.authStateChanges.listen(
      (user) {
        unawaited(
          _onAuthStateChanged(user)
              .catchError((Object error, StackTrace stack) {
            logger.e(
              'Auth state handler failed',
              error: error,
              stackTrace: stack,
            );
          }),
        );
      },
      onError: (Object error, StackTrace stack) {
        logger.e(
          'Firebase auth state stream failed',
          error: error,
          stackTrace: stack,
        );
        if (!_disposed) {
          _recovery.setError('Couldn’t check your session. Please retry.');
          notifyListeners();
        }
      },
    );
  }

  final AuthService _authService;
  final AuthPrefetchCoordinator _prefetchCoordinator;
  final BackendProfileCreator _profileCreator;
  late final BackendProfileLoader _profileLoader;
  late final bool _prefetchAfterAuth;
  late final AvatarSelector _avatarSelector;
  final AuthNotificationPoller _notificationPoller = AuthNotificationPoller();
  final _authStatusNotifier = _AuthStatusNotifier();
  StreamSubscription<firebase_auth.User?>? _authStateSubscription;
  late final AuthSessionRecovery _recovery;

  AuthStatus _status = AuthStatus.unknown;
  firebase_auth.User? _firebaseUser;
  models.User? _dbUser;
  bool _isLoading = false;
  String? _errorMessage;
  String? _errorCode;
  int _activityVersion = 0;
  int? _profileRefreshedActivityVersion;
  int get friendDataVersion => _accountCache.friendDataVersion;
  bool _pendingReferralQualification = false;

  bool _isPrefetching = false;
  bool _hasResetAppBadgeThisSession = false;

  /// Navigator key set by the app root so push notifications can navigate.
  GlobalKey<NavigatorState>? _navigatorKey;

  /// Call once the root navigator is ready (e.g. in [FlixieApp.initState]).
  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
    final externalId = _dbUser?.externalId;
    if (externalId != null && _status == AuthStatus.authenticated) {
      _initializePushNotifications(externalId);
    }
  }

  AuthStatus get status => _status;
  firebase_auth.User? get firebaseUser => _firebaseUser;
  models.User? get dbUser => _dbUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get errorCode => _errorCode;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  int get activityVersion => _activityVersion;

  /// Whether this activity notification already includes a refreshed profile.
  /// Action notifications still require screens to fetch updated profile data.
  bool get activityIncludesRefreshedProfile =>
      _profileRefreshedActivityVersion == _activityVersion;

  /// Screen-facing data is owned and reset by the account cache.
  List<ActivityListItem>? get cachedActivity => _accountCache.cachedActivity;
  FriendsData? get cachedFriends => _accountCache.cachedFriends;
  List<Group>? get cachedGroups => _accountCache.cachedGroups;
  List<MovieRating>? get cachedRatings => _accountCache.cachedRatings;
  List<Review>? get cachedReviews => _accountCache.cachedReviews;
  List<MovieShort>? get cachedTrending => _accountCache.cachedTrending;
  List<MovieShort>? get cachedNowPlaying => _accountCache.cachedNowPlaying;
  List<MovieList>? get cachedMovieLists => _accountCache.cachedMovieLists;
  List<FlixieNotification>? get cachedNotifications =>
      _accountCache.cachedNotifications;
  List<WatchRequest>? get cachedWatchRequests =>
      _accountCache.cachedWatchRequests;
  bool get isPrefetching => _isPrefetching;
  Map<int, List<WatchProvider>> get cachedWatchProvidersByMovieId =>
      _accountCache.cachedWatchProvidersByMovieId;
  Set<int>? get cachedUserWatchProviderIds =>
      _accountCache.cachedUserWatchProviderIds;

  void updateCachedUserWatchProviderIds(Iterable<int> providerIds) {
    _accountCache.updateCachedUserWatchProviderIds(providerIds);
    notifyListeners();
  }

  int get unreadNotificationCount => _accountCache.unreadNotificationCount;

  void _syncUnreadNotificationCount(int count) {
    _accountCache.setUnreadNotificationCount(count);
    unawaited(AppIconBadgeService.setCount(unreadNotificationCount));
  }

  void updateCachedReviews(List<Review> reviews) {
    _accountCache.updateCachedReviews(reviews);
    notifyListeners();
  }

  void updateCachedNotifications(List<FlixieNotification> notifications,
      {int? unreadCount}) {
    _accountCache.updateCachedNotifications(notifications,
        userId: _dbUser?.id, unreadCount: unreadCount);
    _syncUnreadNotificationCount(unreadNotificationCount);
    notifyListeners();
  }

  void removeCachedNotification(String notificationId) {
    _accountCache.removeCachedNotification(notificationId, userId: _dbUser?.id);
    _syncUnreadNotificationCount(unreadNotificationCount);
    notifyListeners();
  }

  void removeCachedWatchPlanNotifications(String requestId) {
    _accountCache.removeCachedWatchPlanNotifications(requestId,
        userId: _dbUser?.id);
    _syncUnreadNotificationCount(unreadNotificationCount);
    notifyListeners();
  }

  void updateCachedWatchRequests(List<WatchRequest> requests) {
    _accountCache.updateCachedWatchRequests(requests);
    notifyListeners();
  }

  void invalidateCachedReviews() {
    _accountCache.invalidateCachedReviews();
    notifyListeners();
  }

  void updateCachedFriends(FriendsData friends) {
    _accountCache.updateCachedFriends(friends);
    notifyListeners();
  }

  void updateCachedSocialData(
      {required FriendsData friends,
      required List<ActivityListItem> activity,
      required List<Group> groups}) {
    _accountCache.updateCachedSocialData(
        friends: friends, activity: activity, groups: groups);
    notifyListeners();
  }

  void updateCachedGroups(List<Group> groups) {
    _accountCache.updateCachedGroups(groups);
    notifyListeners();
  }

  void updateCachedMovieLists(List<MovieList> lists) {
    _accountCache.updateCachedMovieLists(lists);
    notifyListeners();
  }

  void invalidateCachedMovieLists() {
    _accountCache.invalidateCachedMovieLists();
    notifyListeners();
  }

  void invalidateCachedFriends() {
    _accountCache.invalidateCachedFriends();
    notifyListeners();
  }

  void markActivityChanged() {
    MilestoneCache.instance.invalidate();
    _accountCache.invalidateActivity();
    _activityVersion++;
    notifyListeners();
  }

  /// A Listenable that only notifies when auth status changes, not when user data changes.
  /// Use this for router refresh to avoid unnecessary navigation rebuilds.
  Listenable get authStatusListenable => _authStatusNotifier;

  // Flag set during sign-up to prevent _onAuthStateChanged from running
  // getUserByExternalId before the DB user has been created.
  bool _isSigningUp = false;
  bool _needsSocialProfile = false;
  bool get needsSocialProfile => _needsSocialProfile;
  bool isProviderConnected(SocialAuthProvider provider) =>
      _firebaseUser?.providerData
          .any((info) => info.providerId == provider.id) ??
      false;
  bool get hasConnectedSocialProvider =>
      SocialAuthProvider.values.any(isProviderConnected);
  bool get hasPassword =>
      _firebaseUser?.providerData
          .any((info) => info.providerId == 'password') ??
      false;
  bool get deletionNeedsPassword =>
      hasPassword && !isProviderConnected(SocialAuthProvider.apple);
  Map<String, dynamic>? _pendingSignupProfile;
  String? _pendingSignupEmail;
  int? _pendingAvatarId;
  Future<void>? _authStateChangeFuture;
  // Inactive can be a permission sheet or the initial foreground transition.
  // Only hidden/paused marks a genuine return that needs session recovery.
  bool _hasBackgrounded = false;
  int _sessionGeneration = 0;
  int _prefetchGeneration = 0;
  bool _disposed = false;
  String? get recoveryError => _recovery.error;

  Future<void> _onAuthStateChanged(firebase_auth.User? user,
      {bool retry = false}) async {
    if (_isSigningUp || _disposed) return;
    // Returning from a native provider dialog must not skip avatar selection.
    if (user != null &&
        _needsSocialProfile &&
        _pendingSignupProfile != null &&
        _dbUser != null) {
      return;
    }
    _recovery.authStateReceived();
    final sameUser = _firebaseUser?.uid == user?.uid;
    if (sameUser && _authStateChangeFuture != null) {
      return _authStateChangeFuture;
    }
    if (sameUser && !retry && _status == AuthStatus.authenticated) return;
    if (!sameUser || user == null) {
      SafetyService.reset();
      MilestoneCache.instance.clear();
      _termsVerified = false;
      _sessionGeneration++;
      _prefetchGeneration++;
      ShowService.clearSummaryCache();
      _recovery.reset();
      _profileRefreshedActivityVersion = null;
      _isPrefetching = false;
      _accountCache.clear();
      ApiClient.setToken(null);
      if (user != null) {
        _dbUser = null;
        PeopleCache.instance.selectAccount(null);
        _notificationPoller.stop();
        _status = AuthStatus.unknown;
      }
    }
    _firebaseUser = user;
    _recovery.setError(null);
    _errorMessage = null;
    notifyListeners();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) _authStatusNotifier.notify();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
    final generation = _sessionGeneration;
    final future = _handleAuthStateChanged(user, generation);
    _authStateChangeFuture = future;
    try {
      await future;
    } finally {
      if (identical(_authStateChangeFuture, future)) {
        _authStateChangeFuture = null;
      }
    }
  }

  Future<void> retrySession() async {
    if (_dbUser != null) {
      unawaited(StarredPeople.instance.refresh().catchError((_) {}));
    }
    await _recovery.retry();
  }

  Future<void> _retrySessionRecovery() async {
    if (_dbUser == null) {
      await _onAuthStateChanged(_authService.currentUser, retry: true);
    } else {
      await handleAppResumed(force: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _hasBackgrounded = true;
    }
    _recovery.setForeground(state == AppLifecycleState.resumed);
    if (!_recovery.foreground) {
      _notificationPoller.stop();
      return;
    }
    final returningFromBackground = _hasBackgrounded;
    _hasBackgrounded = false;
    if (!returningFromBackground && recoveryError == null) {
      // Startup owns restoration. Reuse its profile and avoid invalidating Home
      // again when iOS first becomes active or a native sheet closes.
      if (_status == AuthStatus.authenticated) _startNotificationPoller();
      return;
    }
    if (_dbUser == null && _firebaseUser != null) {
      unawaited(_onAuthStateChanged(_firebaseUser, retry: true));
    } else {
      unawaited(handleAppResumed());
    }
  }

  Future<void> _handleAuthStateChanged(
      firebase_auth.User? user, int generation) async {
    bool current() => !_disposed && generation == _sessionGeneration;
    logger.i('Auth state changed');
    logger.d(
        'Firebase user: ${user?.email ?? "null"} (uid: ${user?.uid ?? "null"})');

    _firebaseUser = user;
    final oldStatus = _status;

    if (user != null) {
      _hasResetAppBadgeThisSession = false;
      try {
        await _recovery.refreshToken(user, isCurrent: current);
        if (!current()) return;
        models.User? profile;
        try {
          profile = await StartupTrace.run(
              'profile',
              () => _profileLoader(user.uid)
                  .timeout(AuthSessionRecovery.profileTimeout));
        } on ApiException catch (error) {
          if (error.statusCode != 404) rethrow;
        }
        if (!current()) return;
        if (profile == null &&
            user.providerData.any((info) =>
                info.providerId == 'apple.com' ||
                info.providerId == 'google.com')) {
          _needsSocialProfile = true;
          _status = AuthStatus.unauthenticated;
          _recovery.succeeded();
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (!_disposed) _authStatusNotifier.notify();
          });
          notifyListeners();
          return;
        }
        if (profile == null) throw StateError('Profile unavailable');
        _needsSocialProfile = false;
        _dbUser = profile;
        _profileRefreshedActivityVersion = _activityVersion;
        // Resolve account consent before the router sees an authenticated
        // session. An unknown value must not briefly open the agreement page.
        try {
          await verifyTerms().timeout(AuthSessionRecovery.profileTimeout);
        } catch (_) {
          // Keep deletion and the existing retry UI available on lookup failure.
          // A failed check must never grant access.
        }
        if (!current()) return;
        _status = AuthStatus.authenticated;
        _recovery.succeeded();
        MilestoneCache.instance.useOwner(profile.id);
        if (_prefetchAfterAuth) _prefetch(profile.id);
      } catch (error) {
        if (!current()) return;
        final invalid = AuthSessionRecovery.isExpired(error);
        if (invalid) {
          ApiClient.setToken(null);
          _dbUser = null;
          PeopleCache.instance.selectAccount(null);
          _status = AuthStatus.unauthenticated;
          _errorMessage = 'Your session expired. Please sign in again.';
        } else {
          _status =
              _dbUser == null ? AuthStatus.unknown : AuthStatus.authenticated;
          _recovery.setError(
              'Couldn’t connect to Flixie. Check your connection and retry.');
          _errorMessage = recoveryError;
          _recovery.scheduleRetry();
        }
      }
    } else {
      logger.i('User signed out, clearing database user');
      _needsSocialProfile = false;
      _pendingSignupEmail = null;
      _pendingSignupProfile = null;
      _pendingAvatarId = null;
      // The session has already ended; only deregister this device locally.
      if (_dbUser?.externalId != null) {
        unawaited(PushNotificationService.removeToken(_dbUser!.externalId!,
            removeFromBackend: false));
      }
      ApiClient.setToken(null);
      _dbUser = null;
      PeopleCache.instance.selectAccount(null);
      _status = AuthStatus.unauthenticated;
      _isPrefetching = false;
      _notificationPoller.stop();
      _syncUnreadNotificationCount(0);
      _hasResetAppBadgeThisSession = false;
    }

    if (!current()) return;
    logger.d('Final status: $_status');

    // Notify auth status listener only if status actually changed
    if (oldStatus != _status) {
      // Defer _authStatusNotifier.notify() to a post-frame callback so that
      // GoRouter's redirect is scheduled for a *later* frame than the one
      // where _setLoading(false) marks the current auth screen dirty.  If
      // both the dirty-marking and the Navigator deactivation land in the
      // same build scope Flutter throws:
      //   '_elements.contains(element)': is not true.
      // By deferring the router notification we guarantee:
      //   Frame A – _setLoading(false) dirty-mark is processed, screen rebuilds.
      //   Frame B – GoRouter redirects and deactivates the auth screen (clean).
      //   Post-frame B – notifyListeners() fires; screen is already inactive so
      //                  markNeedsBuild() returns early with no crash.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_disposed) return;
        _authStatusNotifier.notify();
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!_disposed) notifyListeners();
        });
        SchedulerBinding.instance.ensureVisualUpdate();
      });
      // Post-frame callbacks alone do not request a frame. An idle screen
      // must redirect on logout without waiting for a gesture or refresh.
      SchedulerBinding.instance.ensureVisualUpdate();
    } else {
      notifyListeners();
    }
  }

  /// Warms compact shared data after the authenticated route has painted.
  void _prefetch(String userId, {String? region}) {
    final session = _sessionGeneration;
    // Let the authenticated route paint before starting background warming.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_disposed || session != _sessionGeneration || _dbUser?.id != userId) {
        return;
      }
      _runPrefetch(userId, region: region);
    });
  }

  void _runPrefetch(String userId, {String? region}) {
    PeopleCache.instance.selectAccount(userId);
    unawaited(StarredPeople.instance.refresh().catchError((_) {}));
    unawaited(
        PeopleCache.instance.load(const CommunityService().followedPeople));
    // Independent of startup readiness and all other prefetch work.
    // Milestone details load when the milestone screen is opened.
    final session = _sessionGeneration;
    final generation = ++_prefetchGeneration;
    bool current() =>
        !_disposed &&
        session == _sessionGeneration &&
        generation == _prefetchGeneration &&
        _dbUser?.id == userId;
    final providerRegion = region ?? _dbUser?.watchProviderRegion ?? 'GB';
    _accountCache.selectWatchProviderRegion(providerRegion,
        preserveUnspecified: true);
    _isPrefetching = true;
    if (!_hasResetAppBadgeThisSession) {
      _hasResetAppBadgeThisSession = true;
      unawaited(AppIconBadgeService.clear());
    }
    // Token registration is independent of home/profile prefetching. Start it
    // immediately so a slow secondary API cannot delay push notifications.
    _initializePushNotifications(_dbUser?.externalId ?? userId);
    unawaited(ShowService.warmLibrarySummaries([
      ...?_dbUser?.showWatchlist,
      ...?_dbUser?.favoriteShows,
    ]));
    final watchlistMovieIds = _dbUser?.movieWatchlist
            ?.where((item) => item.removed != true)
            .map((item) => item.movieId) ??
        const <int>[];
    _prefetchCoordinator
        .prefetch(
      userId,
      region: providerRegion,
      watchlistMovieIds: watchlistMovieIds,
    )
        .then((snapshot) {
      if (!current()) return;
      _applyPrefetchSnapshot(snapshot);
      logger.i('[AuthProvider] Prefetch complete for $userId');
      _isPrefetching = false;
      _startNotificationPoller();

      // Defer navigation trigger to avoid mid-frame widget tree mutations
      // (same pattern used in _onAuthStateChanged).
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_disposed) return;
        _authStatusNotifier.notify();
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!_disposed) notifyListeners();
        });
      });
    }).catchError((e) {
      if (!current()) return;
      logger.w('[AuthProvider] Prefetch error: $e');
      _isPrefetching = false;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_disposed) return;
        _authStatusNotifier.notify();
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!_disposed) notifyListeners();
        });
      });
    });
  }

  void _initializePushNotifications(String userId) {
    final key = _navigatorKey;
    final databaseUserId = _dbUser?.id;
    if (key == null || databaseUserId == null) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_disposed || _dbUser?.id != databaseUserId) return;
      unawaited(PushNotificationService.initialize(
        userId: userId,
        databaseUserId: databaseUserId,
        navigatorKey: key,
      ));
    });
  }

  void _applyPrefetchSnapshot(AuthPrefetchSnapshot snapshot) {
    _accountCache.applyPrefetchSnapshot(snapshot);
    final userId = _dbUser?.id;
    if (snapshot.notifications != null && userId != null) {
      PushNotificationService.observeInbox(userId, cachedNotifications!,
          announce: false);
    }
    _syncUnreadNotificationCount(unreadNotificationCount);
  }

  /// Loads missing provider entries through the account cache's shared request.
  Future<void> ensureWatchProviderCache({Iterable<int>? movieIds}) async {
    final user = _dbUser;
    if (user == null) return;
    final session = _sessionGeneration;
    await _accountCache.ensureWatchProviders(
      userId: user.id,
      region: user.watchProviderRegion,
      movieIds: movieIds ??
          user.movieWatchlist
              ?.where((item) => item.removed != true)
              .map((item) => item.movieId) ??
          const <int>[],
      isCurrent: () =>
          !_disposed && session == _sessionGeneration && _dbUser?.id == user.id,
      onChanged: notifyListeners,
    );
  }

  /// Directly updates the unread count from already-fetched notification data.
  /// Use this to keep the badge in sync without making an extra API call.
  void setUnreadNotificationCount(int count) {
    _syncUnreadNotificationCount(count);
    notifyListeners();
  }

  /// Fetches the current user's unread notification count and notifies listeners.
  Future<void> refreshNotificationCount({bool announce = true}) async {
    final userId = _dbUser?.id;
    if (userId == null) return;
    final session = _sessionGeneration;
    final page = await _prefetchCoordinator.fetchNotificationPage(userId);
    if (!_disposed &&
        session == _sessionGeneration &&
        _dbUser?.id == userId &&
        page != null) {
      PushNotificationService.observeInbox(userId, page.items,
          announce: announce && _recovery.foreground);
      updateCachedNotifications(page.items, unreadCount: page.unreadCount);
    }
  }

  /// Refreshes the profile without restarting startup prefetch. The requesting
  /// screen owns its secondary data refresh and can retain existing content.
  Future<void> refreshUserData() async {
    await _refreshProfile();
  }

  Future<bool> _refreshProfile() => _recovery.refreshProfile();

  Future<void> handleAppResumed({bool force = false}) async {
    final restoring = _authStateChangeFuture;
    if (!force && restoring != null) {
      // A return during startup shares the same account restoration, including
      // its error handling, rather than racing another token/profile request.
      await restoring;
      return;
    }
    await _recovery.resume(force: force);
  }

  void _startNotificationPoller() {
    if (_recovery.foreground && !_disposed && _dbUser != null) {
      _notificationPoller.start(
          interval: const Duration(seconds: 5),
          onTick: refreshNotificationCount);
    }
  }

  void _onResumeRecovered() {
    _activityVersion++;
    _profileRefreshedActivityVersion = _activityVersion;
    _accountCache.invalidateFriendsActivity();
    _startNotificationPoller();
    unawaited(refreshNotificationCount(announce: false));
    notifyListeners();
  }

  /// Applies a profile update without discarding omitted collections.
  void updateCachedUser(models.User user) {
    _dbUser = user.preservingCollectionsFrom(_dbUser);
    notifyListeners();
  }

  /// Marks onboarding as complete on the backend and updates the cached user.
  /// Called when the user finishes or skips the post-signup onboarding flow.
  Future<bool> completeOnboarding() async {
    final userId = _dbUser?.id;
    if (userId == null) return false;
    final qualifiedReferral = _pendingReferralQualification;
    try {
      final updated = await UserService.completeUserSetup(userId);
      if (_disposed || _dbUser?.id != userId) return false;
      // Setup returns profile fields without library relations. Keep the
      // freshly loaded library instead of interpreting omitted lists as empty.
      final current = _dbUser!;
      _dbUser = updated.copyWith(
        movieWatchlist: updated.movieWatchlist ?? current.movieWatchlist,
        showWatchlist: updated.showWatchlist ?? current.showWatchlist,
        watchedMovies: updated.watchedMovies ?? current.watchedMovies,
        watchedShows: updated.watchedShows ?? current.watchedShows,
        favoriteMovies: updated.favoriteMovies ?? current.favoriteMovies,
        favoriteShows: updated.favoriteShows ?? current.favoriteShows,
        favoritePeople: updated.favoritePeople ?? current.favoritePeople,
        favoriteGenres: updated.favoriteGenres ?? current.favoriteGenres,
      );
    } catch (e) {
      logger.w('[AuthProvider] completeOnboarding error: $e');
      rethrow;
    }
    _pendingReferralQualification = false;
    notifyListeners();
    return qualifiedReferral;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    if (message == null) _errorCode = null;
    notifyListeners();
  }

  void clearError() => _setError(null);

  bool _looksLikeEmail(String value) =>
      value.contains('@') && value.substring(value.indexOf('@')).contains('.');

  Future<String> _resolveSignInEmail(String identifier, String password) async {
    if (_looksLikeEmail(identifier)) {
      return identifier;
    }

    try {
      final result = await ApiClient.post('/auth/username-session',
          body: {
            'username': identifier,
            'password': password,
            'apiKey': Firebase.app().options.apiKey,
          },
          logRequestBody: false);
      return result['email'] as String;
    } on ApiException catch (error) {
      logger.w('Failed to resolve username during sign-in: $error');
      _errorMessage = error.statusCode == 401
          ? 'Incorrect username or password.'
          : 'Unable to verify username right now. Please try again.';
      rethrow;
    } catch (error) {
      logger.w('Unexpected username lookup failure during sign-in: $error');
      _errorMessage = 'Unable to verify username right now. Please try again.';
      rethrow;
    }
  }

  /// Signs in with email or username and password. Returns `true` on success.
  late final Future<bool> Function() _termsStatusLoader;
  bool _termsVerified = false;
  bool get termsVerified => _termsVerified;

  Future<bool> verifyTerms({bool accept = false}) async {
    final generation = _sessionGeneration;
    final response = accept
        ? await ApiClient.post('/users/me/terms', body: {
            'termsAccepted': true,
            'version': '2026-09-16',
          })
        : {'accepted': await _termsStatusLoader()};
    if (generation != _sessionGeneration || _disposed) return false;
    _termsVerified = response is Map && response['accepted'] == true;
    if (_termsVerified) _authStatusNotifier.notify();
    return _termsVerified;
  }

  Future<bool> signIn(String emailOrUsername, String password) async {
    if (_isLoading) return false;
    _setLoading(true);
    _setError(null);
    try {
      final identifier = emailOrUsername.trim();
      if (identifier.isEmpty) {
        _errorMessage = 'Please enter your email or username.';
        _setLoading(false);
        return false;
      }

      final email = await _resolveSignInEmail(identifier, password);
      await StartupTrace.run(
          'sign-in',
          () => _authService
              .signIn(email, password)
              .timeout(const Duration(seconds: 15)));

      // Force a one-time sync of auth-dependent state right after sign-in.
      // This avoids a stuck loading/login screen if authStateChanges callback
      // arrives late on some devices.
      final signedInUser = _authService.currentUser;
      if (signedInUser != null) {
        await _onAuthStateChanged(signedInUser);
        _setLoading(false);
      } else {
        logger.w('Sign-in succeeded but currentUser is null');
        _isLoading = false;
        notifyListeners();
      }
      return _status == AuthStatus.authenticated;
    } on ApiException {
      _setLoading(false);
      return false;
    } on firebase_auth.FirebaseAuthException catch (e) {
      _errorMessage = AuthService.messageFromAuthException(e);
      _setLoading(false);
      return false;
    } on TimeoutException {
      _errorMessage = 'Connection timed out. Check your network and try again.';
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred. Please try again.';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signInWithSocialProvider(SocialAuthProvider provider) async {
    if (_isLoading) return false;
    _setLoading(true);
    _setError(null);
    try {
      await _authService.signInWithSocialProvider(provider);
      await _onAuthStateChanged(_authService.currentUser);
      return isAuthenticated || needsSocialProfile;
    } on firebase_auth.FirebaseAuthException catch (error) {
      if (!AuthService.isCancellation(error)) {
        _errorMessage = AuthService.messageFromAuthException(error);
      }
      return false;
    } catch (_) {
      _errorMessage = 'Unable to sign in. Please try again.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> connectSocialProvider(SocialAuthProvider provider) async {
    if (_isLoading || !isAuthenticated) return false;
    if (hasConnectedSocialProvider) {
      _setError('A sign-in provider is already connected to this account.');
      return false;
    }
    _setLoading(true);
    _setError(null);
    try {
      await _authService.linkSocialProvider(provider);
      _firebaseUser = _authService.currentUser;
      return true;
    } on firebase_auth.FirebaseAuthException catch (error) {
      _errorCode = error.code;
      if (!AuthService.isCancellation(error)) {
        _errorMessage = error.code == 'email-already-in-use'
            ? 'Firebase could not connect ${provider.label} because the email it supplied is already in use. Your current Flixie account has not been changed. Contact support to check the conflicting account.'
            : AuthService.messageFromAuthException(error);
      }
      return false;
    } catch (_) {
      _errorMessage = 'Unable to connect your account. Please try again.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Creates Firebase identity once, then creates (or retries) the backend
  /// profile using the authenticated Firebase token.
  Future<bool> signUp({
    required bool termsAccepted,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String username,
    int? languageId,
    int? countryId,
    List<int> genreIds = const [],
    String? referralCode,
  }) async {
    if (_isLoading) return false;
    if (!termsAccepted) {
      _setError('Please agree to the Terms of Use to continue.');
      return false;
    }
    _setLoading(true);
    _setError(null);
    _isSigningUp = true;
    bool succeeded = false;
    try {
      final normalizedEmail = email.trim();
      final createUserBody = <String, dynamic>{
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'username': username.trim(),
        'email': normalizedEmail,
        'bio': '',
        'termsAccepted': termsAccepted,
        'countryId': countryId,
        'languageId': languageId,
        if (referralCode?.trim().isNotEmpty == true)
          'referralCode': referralCode!.trim().toUpperCase(),
      };

      final canRetryProfile = _pendingSignupProfile != null &&
          _pendingSignupEmail == normalizedEmail &&
          _authService.currentUser != null;

      if (!canRetryProfile) {
        final displayName = '${firstName.trim()} ${lastName.trim()}'.trim();
        await _authService.signUp(normalizedEmail, password, displayName);
        _pendingSignupEmail = normalizedEmail;
        _pendingSignupProfile = createUserBody;
      } else {
        _pendingSignupProfile = createUserBody;
      }

      _firebaseUser = _authService.currentUser;
      _dbUser = await _createBackendProfileWithAuthRetry(
        _pendingSignupProfile ?? createUserBody,
      );
      // Successful profile creation confirms the backend saved signup consent.
      // Set this before publishing the authenticated state to the router.
      _termsVerified = termsAccepted;
      _pendingSignupEmail = null;
      _pendingSignupProfile = null;

      // Save favourite genres if any were selected
      if (genreIds.isNotEmpty && _dbUser?.id != null) {
        await UserService.addFavoriteGenres(_dbUser!.id, genreIds);
      }

      _status = AuthStatus.authenticated;
      if (_dbUser?.id != null) {
        MilestoneCache.instance.useOwner(_dbUser!.id);
        if (_prefetchAfterAuth) _prefetch(_dbUser!.id);
      }
      // Defer router notification so GoRouter navigates *after* the current
      // frame builds cleanly (same pattern as _onAuthStateChanged).
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_disposed) return;
        _authStatusNotifier.notify();
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!_disposed) notifyListeners();
        });
      });
      succeeded = true;
      return true;
    } on ApiException catch (e) {
      logger.e('Backend rejected sign-up: $e');
      _errorCode = e.code;
      _errorMessage = _signupApiErrorMessage(e);
      return false;
    } on firebase_auth.FirebaseAuthException catch (e) {
      _errorMessage = AuthService.messageFromAuthException(e);
      return false;
    } catch (e) {
      logger.e('Error during sign-up: $e');
      _errorMessage = _pendingSignupProfile != null
          ? 'Your account was created, but your Flixie profile could not be saved. Please try again.'
          : 'Failed to create account. Please try again.';
      return false;
    } finally {
      _isSigningUp = false;
      if (succeeded) {
        // On success, silently clear loading without triggering notifyListeners().
        // The deferred post-frame callback above already schedules the next
        // notification. Calling notifyListeners() now would mark the signup
        // screen dirty in the same frame GoRouter deactivates it → crash.
        _isLoading = false;
      } else {
        // On failure, notify immediately so the error state is visible.
        _setLoading(false);
      }
    }
  }

  Future<bool> beginAvatarSignUp({
    required bool termsAccepted,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String username,
    int? languageId,
    int? countryId,
    String? referralCode,
  }) async {
    if (_isLoading) return false;
    if (!termsAccepted) {
      _setError('Please agree to the Terms of Use to continue.');
      return false;
    }
    _setLoading(true);
    _setError(null);
    _isSigningUp = true;
    try {
      final normalizedEmail = _needsSocialProfile
          ? (_authService.currentUser?.email ?? '').trim()
          : email.trim();
      if (_needsSocialProfile && normalizedEmail.isEmpty) {
        _errorMessage =
            'Your provider did not share an email. Please use another sign-in method.';
        return false;
      }
      _pendingSignupProfile = {
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'username': username.trim(),
        'email': normalizedEmail,
        'bio': '',
        'termsAccepted': termsAccepted,
        'countryId': countryId,
        'languageId': languageId,
        if (referralCode?.trim().isNotEmpty == true)
          'referralCode': referralCode!.trim().toUpperCase(),
      };
      _pendingReferralQualification = referralCode?.trim().isNotEmpty == true;
      _pendingSignupEmail = normalizedEmail;
      if (_authService.currentUser == null) {
        await _authService.signUp(
          normalizedEmail,
          password,
          '${firstName.trim()} ${lastName.trim()}'.trim(),
        );
      }
      _firebaseUser = _authService.currentUser;
      if (_needsSocialProfile) {
        ApiClient.setToken(await _authService.refreshIdToken());
      }

      // Do not let the user continue to avatar selection or onboarding until
      // both identity stores agree that the account exists. Firebase account
      // creation rejects an email that is already registered there, while the
      // backend profile creation enforces the database uniqueness rules.
      _dbUser ??= await _createBackendProfileWithAuthRetry(
        _pendingSignupProfile!,
      );
      return true;
    } on ApiException catch (error) {
      _errorCode = error.code;
      _errorMessage = _signupApiErrorMessage(error);
      return false;
    } on firebase_auth.FirebaseAuthException catch (error) {
      _pendingSignupProfile = null;
      _pendingSignupEmail = null;
      _errorMessage = AuthService.messageFromAuthException(error);
      return false;
    } catch (error) {
      logger.e('Account creation failed: $error');
      _errorMessage = _authService.currentUser == null
          ? 'Failed to create account. Please try again.'
          : 'Your account was created, but your Flixie profile could not be saved. Please try again.';
      return false;
    } finally {
      _isSigningUp = false;
      _setLoading(false);
    }
  }

  Future<bool> completeAvatarSignUp(int avatarId) async {
    if (_isLoading || _pendingSignupProfile == null) return false;
    _setLoading(true);
    _setError(null);
    _isSigningUp = true;
    _pendingAvatarId = avatarId;
    try {
      // Normally created by beginAvatarSignUp before this screen is shown.
      // Keep this fallback for a safe retry if an older in-progress signup is
      // resumed after an app update.
      _dbUser ??= await _createBackendProfileWithAuthRetry(
        _pendingSignupProfile!,
      );
      final avatar = await _avatarSelector(_pendingAvatarId!);
      _dbUser = _dbUser!.copyWith(avatar: avatar);
      // The backend already persisted this agreement when creating the profile.
      // Publish consent and authentication together to avoid the terms route.
      _termsVerified = _pendingSignupProfile!['termsAccepted'] == true;
      _pendingSignupEmail = null;
      _pendingSignupProfile = null;
      _pendingAvatarId = null;
      _needsSocialProfile = false;
      _status = AuthStatus.authenticated;
      MilestoneCache.instance.useOwner(_dbUser!.id);
      if (_prefetchAfterAuth) _prefetch(_dbUser!.id);
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _authStatusNotifier.notify();
        notifyListeners();
      });
      return true;
    } on ApiException catch (error) {
      _errorCode = error.code;
      _errorMessage = _signupApiErrorMessage(error);
      return false;
    } catch (error) {
      logger.e('Avatar signup completion failed: $error');
      _errorMessage = _dbUser == null
          ? 'Your Flixie profile could not be created. Please try again.'
          : 'Your profile was created, but the avatar could not be assigned. Please retry.';
      return false;
    } finally {
      _isSigningUp = false;
      _setLoading(false);
    }
  }

  Future<models.User> _createBackendProfileWithAuthRetry(
      Map<String, dynamic> body) async {
    try {
      return await _profileCreator(body);
    } on ApiException catch (error) {
      if (error.statusCode != 401) rethrow;
      try {
        await ApiClient.refreshAuthToken();
      } catch (_) {
        throw const ApiException(
          statusCode: 401,
          message: 'Your session expired. Please sign in again.',
        );
      }
      return _profileCreator(body);
    }
  }

  String _signupApiErrorMessage(ApiException error) {
    switch (error.code) {
      case 'USERNAME_NOT_AVAILABLE':
      case 'VALIDATION_ERROR':
        return error.message;
      case 'USER_ALREADY_EXISTS':
        return 'This Firebase account already has a Flixie profile.';
      case 'VERIFIED_EMAIL_REQUIRED':
        return 'A verified email address is required to create your profile.';
      default:
        return error.statusCode == 401
            ? 'Your session expired. Please sign in again.'
            : 'Your account was created, but your Flixie profile could not be saved. Please try again.';
    }
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    _setLoading(true);
    try {
      final userId = _dbUser?.externalId;
      if (userId != null) {
        await PushNotificationService.removeToken(userId);
      }
      await _onAuthStateChanged(null);
      await _authService.signOut().timeout(AuthSessionRecovery.tokenTimeout);
    } finally {
      _setLoading(false);
    }
  }

  /// Sends a password-reset email. Returns `true` on success.
  Future<bool> sendPasswordResetEmail(String email) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.sendPasswordResetEmail(email);
      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      _setError(AuthService.messageFromAuthException(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Reauthenticates and updates the current user's password.
  /// Returns `null` on success, or an error message string on failure.
  Future<String?> updatePassword(
      String currentPassword, String newPassword) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.updatePassword(currentPassword, newPassword);
      return null;
    } on firebase_auth.FirebaseAuthException catch (e) {
      final msg = AuthService.messageFromAuthException(e);
      _setError(msg);
      return msg;
    } finally {
      _setLoading(false);
    }
  }

  /// Reauthenticates and permanently deletes the user's Flixie data and
  /// matching Firebase Authentication account.
  Future<String?> deleteAccount(String currentPassword) async {
    final userId = _dbUser?.id;
    if (userId == null) return 'No signed-in account was found.';

    _setLoading(true);
    _setError(null);
    try {
      await _authService.prepareAccountDeletion(currentPassword);
      ApiClient.setToken(await _authService.refreshIdToken());
      await ApiClient.post('/users/$userId/delete-account', body: {});
      await _authService.signOut();
      return null;
    } on firebase_auth.FirebaseAuthException catch (error) {
      final message = AuthService.messageFromAuthException(error);
      _setError(message);
      return message;
    } on ApiException catch (error) {
      final message = error.message.isEmpty
          ? 'Unable to delete your account right now.'
          : error.message;
      _setError(message);
      return message;
    } catch (_) {
      const message = 'Unable to delete your account right now.';
      _setError(message);
      return message;
    } finally {
      _setLoading(false);
    }
  }

  /// Reloads and returns the current user profile from Firebase.
  Future<firebase_auth.User?> getUserProfile() => _authService.getUserProfile();

  /// Updates the database user without making an API call.
  /// Use this when you already have updated user data from an API response.
  void updateDbUser(models.User user) {
    logger.d('Updating database user: ${user.username}');
    _dbUser = user;
    notifyListeners();
  }

  /// Updates a specific list field on the user
  void updateUserList({
    List<WatchedMovie>? watchedMovies,
    List<dynamic>? watchedShows,
    List<WatchlistMovie>? movieWatchlist,
    List<dynamic>? showWatchlist,
    List<FavoriteMovie>? favoriteMovies,
    List<dynamic>? favoriteShows,
    List<dynamic>? favoritePeople,
  }) {
    if (_dbUser == null) return;

    logger.d('Updating user lists:');
    if (watchedMovies != null) {
      logger.d('Watched: ${watchedMovies.length} items');
    }
    if (movieWatchlist != null) {
      logger.d('Watchlist: ${movieWatchlist.length} items');
    }
    if (showWatchlist != null) {
      logger.d('Show watchlist: ${showWatchlist.length} items');
    }
    if (favoriteMovies != null) {
      logger.d('Favorites: ${favoriteMovies.length} items');
    }
    if (favoriteShows != null) {
      logger.d('Favorite shows: ${favoriteShows.length} items');
    }
    if (favoritePeople != null) {
      logger.d('Fav people: ${favoritePeople.length} items');
    }

    _dbUser = _dbUser!.copyWith(
      watchedMovies: watchedMovies ?? _dbUser!.watchedMovies,
      watchedShows: watchedShows ?? _dbUser!.watchedShows,
      movieWatchlist: movieWatchlist ?? _dbUser!.movieWatchlist,
      showWatchlist: showWatchlist ?? _dbUser!.showWatchlist,
      favoriteMovies: favoriteMovies ?? _dbUser!.favoriteMovies,
      favoriteShows: favoriteShows ?? _dbUser!.favoriteShows,
      favoritePeople: favoritePeople ?? _dbUser!.favoritePeople,
    );
    if (movieWatchlist != null) {
      final activeIds = movieWatchlist
          .where((item) => item.removed != true)
          .map((item) => item.movieId)
          .toSet();
      _accountCache.retainWatchProviderMovies(activeIds);
      // The watchlist screen requests visible pages. Editing one entry must not
      // restart provider lookups for every saved title in a large library.
    }
    notifyListeners();
  }

  /// Refreshes the database user from the backend.
  Future<void> refreshDbUser() async {
    await _refreshProfile();
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionGeneration++;
    _prefetchGeneration++;
    _accountCache.clear();
    _isPrefetching = false;
    _recovery.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _notificationPoller.stop();
    ApiClient.setAuthTokenRefresher(null);
    _authStateSubscription?.cancel();
    _authStatusNotifier.dispose();
    super.dispose();
  }
}

/// A minimal ChangeNotifier that only notifies when auth status changes.
/// This is used by GoRouter to avoid rebuilding routes when user data changes.
class _AuthStatusNotifier extends ChangeNotifier {
  void notify() {
    notifyListeners();
  }
}
