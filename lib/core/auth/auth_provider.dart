import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/favorite_movie.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/movie_rating.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/models/user.dart' as models;
import 'package:flixie_app/models/watched_movie.dart';
import 'package:flixie_app/models/watchlist_movie.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/models/profile_avatar.dart';
import 'package:flixie_app/core/auth/auth_notification_poller.dart';
import 'package:flixie_app/core/auth/auth_prefetch_coordinator.dart';
import 'package:flixie_app/core/auth/auth_prefetch_snapshot.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_service.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/core/auth/push_notification_service.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/features/profile/data/avatar_service.dart';
import 'package:flixie_app/core/utils/app_logger.dart';

/// Auth states that the UI can observe.
enum AuthStatus { unknown, authenticated, unauthenticated }

typedef BackendProfileCreator = Future<models.User> Function(
    Map<String, dynamic> body);
typedef AvatarSelector = Future<ProfileAvatar> Function(int avatarId);

/// Exposes Firebase auth state to the widget tree via [ChangeNotifier].
///
/// Screens can read [status], [firebaseUser], [dbUser], [isLoading] and [errorMessage] and call
/// [signIn], [signUp], [signOut] and [sendPasswordResetEmail].
class AuthProvider extends ChangeNotifier {
  // Prefetched friends activity for home screen
  List<ActivityListItem>? _cachedFriendsActivity;
  List<ActivityListItem>? get cachedFriendsActivity => _cachedFriendsActivity;
  AuthProvider(
    this._authService,
    MovieService movieService, {
    AuthPrefetchCoordinator? prefetchCoordinator,
    BackendProfileCreator? profileCreator,
    bool prefetchAfterAuth = true,
    AvatarSelector? avatarSelector,
  })  : _prefetchCoordinator = prefetchCoordinator ??
            AuthPrefetchCoordinator(movieService: movieService),
        _profileCreator = profileCreator ?? UserService.createUser {
    _prefetchAfterAuth = prefetchAfterAuth;
    _avatarSelector = avatarSelector ?? AvatarService.selectAvatar;
    _authStateSubscription = _authService.authStateChanges.listen((user) {
      unawaited(_onAuthStateChanged(user));
    });
  }

  final AuthService _authService;
  final AuthPrefetchCoordinator _prefetchCoordinator;
  final BackendProfileCreator _profileCreator;
  late final bool _prefetchAfterAuth;
  late final AvatarSelector _avatarSelector;
  final AuthNotificationPoller _notificationPoller = AuthNotificationPoller();
  final _authStatusNotifier = _AuthStatusNotifier();
  StreamSubscription<firebase_auth.User?>? _authStateSubscription;

  AuthStatus _status = AuthStatus.unknown;
  firebase_auth.User? _firebaseUser;
  models.User? _dbUser;
  bool _isLoading = false;
  String? _errorMessage;
  String? _errorCode;
  int _activityVersion = 0;

  // Prefetched at login — screens use these to skip spinners
  List<ActivityListItem>? _cachedActivity;
  FriendsData? _cachedFriends;
  List<Group>? _cachedGroups;
  List<MovieRating>? _cachedRatings;
  List<Review>? _cachedReviews;
  List<MovieShort>? _cachedTrending;
  List<MovieShort>? _cachedNowPlaying;
  List<FlixieNotification>? _cachedNotifications;
  bool _isPrefetching = false;
  final Map<int, List<WatchProvider>> _cachedWatchProvidersByMovieId = {};
  Set<int>? _cachedUserWatchProviderIds;
  Future<void>? _watchProviderCacheFuture;

  int _unreadNotificationCount = 0;

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

  List<ActivityListItem>? get cachedActivity => _cachedActivity;
  FriendsData? get cachedFriends => _cachedFriends;
  List<Group>? get cachedGroups => _cachedGroups;
  List<MovieRating>? get cachedRatings => _cachedRatings;
  List<Review>? get cachedReviews => _cachedReviews;
  List<MovieShort>? get cachedTrending => _cachedTrending;
  List<MovieShort>? get cachedNowPlaying => _cachedNowPlaying;
  List<FlixieNotification>? get cachedNotifications => _cachedNotifications;
  bool get isPrefetching => _isPrefetching;
  Map<int, List<WatchProvider>> get cachedWatchProvidersByMovieId =>
      Map.unmodifiable(_cachedWatchProvidersByMovieId);
  Set<int>? get cachedUserWatchProviderIds =>
      _cachedUserWatchProviderIds == null
          ? null
          : Set.unmodifiable(_cachedUserWatchProviderIds!);
  int get unreadNotificationCount => _unreadNotificationCount;

  /// Update the reviews cache, e.g. after writing a new review.
  void updateCachedReviews(List<Review> reviews) {
    _cachedReviews = reviews;
    notifyListeners();
  }

  void updateCachedNotifications(List<FlixieNotification> notifications) {
    _cachedNotifications = List.unmodifiable(notifications);
    _unreadNotificationCount =
        notifications.where((item) => !item.isRead).length;
    notifyListeners();
  }

  /// Clears the reviews cache so the next reviews screen visit fetches fresh data.
  void invalidateCachedReviews() {
    _cachedReviews = null;
    notifyListeners();
  }

  /// Update the friends cache, e.g. after accepting/declining a request.
  void updateCachedFriends(FriendsData friends) {
    _cachedFriends = friends;
    notifyListeners();
  }

  /// Keeps the Social tab's stale-while-refresh snapshot current.
  void updateCachedSocialData({
    required FriendsData friends,
    required List<ActivityListItem> activity,
    required List<Group> groups,
  }) {
    _cachedFriends = friends;
    _cachedFriendsActivity = activity;
    _cachedGroups = groups;
    notifyListeners();
  }

  void updateCachedGroups(List<Group> groups) {
    _cachedGroups = groups;
    notifyListeners();
  }

  void invalidateCachedFriends() {
    _cachedFriends = null;
    notifyListeners();
  }

  /// Call after adding an item to any list so activity-watching screens can refresh.
  void markActivityChanged() {
    _cachedActivity = null;
    _cachedFriendsActivity = null;
    _activityVersion++;
    notifyListeners();
  }

  /// A Listenable that only notifies when auth status changes, not when user data changes.
  /// Use this for router refresh to avoid unnecessary navigation rebuilds.
  Listenable get authStatusListenable => _authStatusNotifier;

  // Flag set during sign-up to prevent _onAuthStateChanged from running
  // getUserByExternalId before the DB user has been created.
  bool _isSigningUp = false;
  Map<String, dynamic>? _pendingSignupProfile;
  String? _pendingSignupEmail;
  int? _pendingAvatarId;
  bool _isHandlingAuthState = false;
  Future<void>? _authStateChangeFuture;

  Future<void> _onAuthStateChanged(firebase_auth.User? user) async {
    // During sign-up the flow is managed directly in signUp(); skip here.
    if (_isSigningUp) return;
    if (_isHandlingAuthState && _authStateChangeFuture != null) {
      return _authStateChangeFuture;
    }
    _isHandlingAuthState = true;
    _authStateChangeFuture = _handleAuthStateChanged(user);
    try {
      await _authStateChangeFuture;
    } finally {
      _authStateChangeFuture = null;
      _isHandlingAuthState = false;
    }
  }

  Future<void> _handleAuthStateChanged(firebase_auth.User? user) async {
    logger.i('Auth state changed');
    logger.d(
        'Firebase user: ${user?.email ?? "null"} (uid: ${user?.uid ?? "null"})');

    _firebaseUser = user;
    final oldStatus = _status;

    if (user != null) {
      // FIRST: Get Firebase ID token and set it in ApiClient.
      // Try a forced refresh first; on network failure fall back to the cached
      // token so the app stays authenticated on a flaky connection.
      try {
        final idToken = await user.getIdToken(true);
        if (idToken != null) {
          logger.d('Got Firebase ID token (fresh), setting in ApiClient');
          ApiClient.setToken(idToken);
        } else {
          logger.w('ID token is null');
        }
      } catch (e) {
        logger.w('Failed to get fresh ID token: $e — trying cached token');
        try {
          final cachedToken = await user.getIdToken(false);
          if (cachedToken != null) {
            logger.d('Got Firebase ID token (cached), setting in ApiClient');
            ApiClient.setToken(cachedToken);
          } else {
            logger.w(
                'Cached ID token is also null — API calls will be unauthorized');
          }
        } catch (e2) {
          logger.w('Failed to get cached ID token: $e2');
        }
      }

      // THEN: Fetch the database user using Firebase UID as externalId
      logger.d('Fetching database user with externalId: ${user.uid}');
      try {
        _dbUser = await UserService.getUserByExternalId(user.uid);
        logger.i(
            'Database user fetched: ${_dbUser?.username} (id: ${_dbUser?.id})');
        logger.d('Email: ${_dbUser?.email}');
        logger.d('Name: ${_dbUser?.firstName} ${_dbUser?.lastName}');
        _status = AuthStatus.authenticated;
        // Kick off background prefetch so screens have data ready immediately
        final region =
            (_dbUser?.country?['isoCode'] as String?)?.toUpperCase() ?? 'US';
        if (_dbUser?.id != null) _prefetch(_dbUser!.id, region: region);
      } catch (e, stackTrace) {
        logger.e('Error fetching database user: $e',
            error: e, stackTrace: stackTrace);
        _dbUser = null;
        _status = AuthStatus.unauthenticated;
      }
    } else {
      logger.i('User signed out, clearing database user');
      // Remove FCM token from backend before clearing the auth token so the
      // API request can still be authenticated. Fire-and-forget is intentional:
      // we do not want to block the sign-out flow on a network call, and any
      // failure is tolerable because the token will be re-registered on next
      // login.
      if (_dbUser?.externalId != null) {
        unawaited(PushNotificationService.removeToken(_dbUser!.externalId!));
      }
      ApiClient.setToken(null);
      _dbUser = null;
      _status = AuthStatus.unauthenticated;
      _isPrefetching = false;
      _cachedActivity = null;
      _cachedFriends = null;
      _cachedGroups = null;
      _cachedRatings = null;
      _cachedReviews = null;
      _cachedTrending = null;
      _cachedNowPlaying = null;
      _cachedNotifications = null;
      _cachedWatchProvidersByMovieId.clear();
      _cachedUserWatchProviderIds = null;
      _watchProviderCacheFuture = null;
      _notificationPoller.stop();
      _unreadNotificationCount = 0;
    }

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
        _authStatusNotifier.notify();
        SchedulerBinding.instance
            .addPostFrameCallback((_) => notifyListeners());
      });
    } else {
      notifyListeners();
    }
  }

  /// Fetches profile/friend/home cache in parallel right after login.
  void _prefetch(String userId, {String region = 'US'}) {
    _isPrefetching = true;
    // Token registration is independent of home/profile prefetching. Start it
    // immediately so a slow secondary API cannot delay push notifications.
    _initializePushNotifications(_dbUser?.externalId ?? userId);
    final watchlistMovieIds = _dbUser?.movieWatchlist
            ?.where((item) => item.removed != true)
            .map((item) => item.movieId) ??
        const <int>[];
    _prefetchCoordinator
        .prefetch(
      userId,
      region: region,
      watchlistMovieIds: watchlistMovieIds,
    )
        .then((snapshot) {
      _applyPrefetchSnapshot(snapshot);
      logger.i('[AuthProvider] Prefetch complete for $userId');
      _isPrefetching = false;
      _notificationPoller.start(
        interval: const Duration(seconds: 30),
        onTick: refreshNotificationCount,
      );

      // Defer navigation trigger to avoid mid-frame widget tree mutations
      // (same pattern used in _onAuthStateChanged).
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _authStatusNotifier.notify();
        SchedulerBinding.instance
            .addPostFrameCallback((_) => notifyListeners());
      });
    }).catchError((e) {
      logger.w('[AuthProvider] Prefetch error: $e');
      _isPrefetching = false;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _authStatusNotifier.notify();
        SchedulerBinding.instance
            .addPostFrameCallback((_) => notifyListeners());
      });
    });
  }

  void _initializePushNotifications(String userId) {
    final key = _navigatorKey;
    if (key == null) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      unawaited(PushNotificationService.initialize(
        userId: userId,
        navigatorKey: key,
      ));
    });
  }

  void _applyPrefetchSnapshot(AuthPrefetchSnapshot snapshot) {
    _cachedActivity = snapshot.activity ?? _cachedActivity;
    _cachedFriends = snapshot.friends ?? _cachedFriends;
    _cachedFriendsActivity = snapshot.friendsActivity ?? _cachedFriendsActivity;
    _cachedGroups = snapshot.groups ?? _cachedGroups;
    _cachedRatings = snapshot.ratings ?? _cachedRatings;
    _cachedReviews = snapshot.reviews ?? _cachedReviews;
    _cachedTrending = snapshot.trending ?? _cachedTrending;
    _cachedNowPlaying = snapshot.nowPlaying ?? _cachedNowPlaying;
    _cachedNotifications = snapshot.notifications ?? _cachedNotifications;
    _unreadNotificationCount =
        snapshot.unreadNotificationCount ?? _unreadNotificationCount;
    if (snapshot.watchProvidersByMovieId != null) {
      _cachedWatchProvidersByMovieId.addAll(snapshot.watchProvidersByMovieId!);
    }
    _cachedUserWatchProviderIds =
        snapshot.userWatchProviderIds ?? _cachedUserWatchProviderIds;
  }

  /// Loads only provider entries that are not already in the shared cache.
  /// Concurrent callers share the same request and re-check afterwards.
  Future<void> ensureWatchProviderCache({Iterable<int>? movieIds}) async {
    final user = _dbUser;
    if (user == null) return;
    final requestedIds = (movieIds ??
            user.movieWatchlist
                ?.where((item) => item.removed != true)
                .map((item) => item.movieId) ??
            const <int>[])
        .toSet();
    final missing = requestedIds
        .where((id) => !_cachedWatchProvidersByMovieId.containsKey(id))
        .toSet();
    if (missing.isEmpty && _cachedUserWatchProviderIds != null) return;

    if (_watchProviderCacheFuture != null) {
      await _watchProviderCacheFuture;
      return ensureWatchProviderCache(movieIds: requestedIds);
    }

    final future = _prefetchCoordinator
        .fetchWatchProviders(
      user.id,
      missing,
      region: user.countryAbbreviation ?? 'GB',
    )
        .then((value) {
      _cachedWatchProvidersByMovieId.addAll(value.providersByMovieId);
      _cachedUserWatchProviderIds = value.userProviderIds;
      notifyListeners();
    });
    _watchProviderCacheFuture = future;
    try {
      await future;
    } finally {
      _watchProviderCacheFuture = null;
    }
  }

  /// Directly updates the unread count from already-fetched notification data.
  /// Use this to keep the badge in sync without making an extra API call.
  void setUnreadNotificationCount(int count) {
    _unreadNotificationCount = count;
    notifyListeners();
  }

  /// Fetches the current user's unread notification count and notifies listeners.
  Future<void> refreshNotificationCount() async {
    final userId = _dbUser?.id;
    if (userId == null) return;
    final count = await _prefetchCoordinator.fetchUnreadCount(userId);
    if (count != null) {
      _unreadNotificationCount = count;
      notifyListeners();
    }
  }

  /// Re-fetches the db user and re-runs the full prefetch (user data, notifications,
  /// friends, reviews, trending, now playing). Call on manual pull-to-refresh.
  Future<void> refreshUserData() async {
    final firebaseUid = _firebaseUser?.uid;
    if (firebaseUid == null) return;
    try {
      _dbUser = await UserService.getUserByExternalId(firebaseUid);
      notifyListeners();
      final region =
          (_dbUser?.country?['isoCode'] as String?)?.toUpperCase() ?? 'US';
      if (_dbUser?.id != null) _prefetch(_dbUser!.id, region: region);
    } catch (e) {
      logger.w('[AuthProvider] refreshUserData error: $e');
    }
  }

  /// Replaces the cached db user with [user] and notifies listeners.
  /// Use when a service call already returns the updated user model.
  void updateCachedUser(models.User user) {
    _dbUser = user;
    notifyListeners();
  }

  /// Marks onboarding as complete on the backend and updates the cached user.
  /// Called when the user finishes or skips the post-signup onboarding flow.
  Future<void> completeOnboarding() async {
    final userId = _dbUser?.id;
    if (userId == null) return;
    try {
      final updated =
          await UserService.updateUserField(userId, 'completedSetup', true);
      _dbUser = updated;
    } catch (e) {
      // Optimistically mark complete locally so the user isn't stuck
      if (_dbUser != null) {
        _dbUser = _dbUser!.copyWith(completedSetup: true);
      }
      logger.w('[AuthProvider] completeOnboarding error: $e');
    }
    notifyListeners();
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

  Future<String> _resolveSignInEmail(String identifier) async {
    if (_looksLikeEmail(identifier)) {
      return identifier;
    }

    try {
      return (await UserService.getUserByUsername(identifier)).email;
    } on ApiException catch (error) {
      logger.w('Failed to resolve username during sign-in: $error');
      _errorMessage = error.statusCode == 404
          ? 'Username not found.'
          : 'Unable to verify username right now. Please try again.';
      rethrow;
    } catch (error) {
      logger.w('Unexpected username lookup failure during sign-in: $error');
      _errorMessage = 'Unable to verify username right now. Please try again.';
      rethrow;
    }
  }

  /// Signs in with email or username and password. Returns `true` on success.
  Future<bool> signIn(String emailOrUsername, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      final identifier = emailOrUsername.trim();
      if (identifier.isEmpty) {
        _errorMessage = 'Please enter your email or username.';
        _setLoading(false);
        return false;
      }

      final email = await _resolveSignInEmail(identifier);
      await _authService.signIn(email, password);

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
      return true;
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

  /// Creates Firebase identity once, then creates (or retries) the backend
  /// profile using the authenticated Firebase token.
  Future<bool> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String username,
    int? languageId,
    int? countryId,
    List<int> genreIds = const [],
  }) async {
    if (_isLoading) return false;
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
        'countryId': countryId,
        'languageId': languageId,
      };

      final canRetryProfile = _pendingSignupProfile != null &&
          _pendingSignupEmail == normalizedEmail &&
          _authService.currentUser != null;

      if (!canRetryProfile) {
        final displayName = '${firstName.trim()} ${lastName.trim()}';
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
      _pendingSignupEmail = null;
      _pendingSignupProfile = null;

      // Save favourite genres if any were selected
      if (genreIds.isNotEmpty && _dbUser?.id != null) {
        await UserService.addFavoriteGenres(_dbUser!.id, genreIds);
      }

      _status = AuthStatus.authenticated;
      if (_prefetchAfterAuth && _dbUser?.id != null) {
        _prefetch(_dbUser!.id); // region defaults to 'US' for new sign-ups
      }
      // Defer router notification so GoRouter navigates *after* the current
      // frame builds cleanly (same pattern as _onAuthStateChanged).
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _authStatusNotifier.notify();
        SchedulerBinding.instance
            .addPostFrameCallback((_) => notifyListeners());
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
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String username,
    int? languageId,
    int? countryId,
  }) async {
    if (_isLoading) return false;
    _setLoading(true);
    _setError(null);
    _isSigningUp = true;
    try {
      final normalizedEmail = email.trim();
      _pendingSignupProfile = {
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'username': username.trim(),
        'email': normalizedEmail,
        'bio': '',
        'countryId': countryId,
        'languageId': languageId,
      };
      _pendingSignupEmail = normalizedEmail;
      if (_authService.currentUser == null) {
        await _authService.signUp(
          normalizedEmail,
          password,
          '${firstName.trim()} ${lastName.trim()}',
        );
      }
      _firebaseUser = _authService.currentUser;

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
      _pendingSignupEmail = null;
      _pendingSignupProfile = null;
      _pendingAvatarId = null;
      _status = AuthStatus.authenticated;
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
        await _authService.refreshIdToken();
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
      await _authService.signOut();
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

  /// Reauthenticates, anonymises the backend profile, and asks the backend to
  /// delete the matching Firebase Authentication account.
  Future<String?> deactivateAccount(String currentPassword) async {
    final userId = _dbUser?.id;
    if (userId == null) return 'No signed-in account was found.';

    _setLoading(true);
    _setError(null);
    try {
      await _authService.reauthenticate(currentPassword);
      await ApiClient.post('/users/$userId/deactivate', body: {});
      await _authService.signOut();
      return null;
    } on firebase_auth.FirebaseAuthException catch (error) {
      final message = AuthService.messageFromAuthException(error);
      _setError(message);
      return message;
    } on ApiException catch (error) {
      final message = error.message.isEmpty
          ? 'Unable to deactivate your account right now.'
          : error.message;
      _setError(message);
      return message;
    } catch (_) {
      const message = 'Unable to deactivate your account right now.';
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
      _cachedWatchProvidersByMovieId
          .removeWhere((movieId, _) => !activeIds.contains(movieId));
      unawaited(ensureWatchProviderCache(movieIds: activeIds));
    }
    notifyListeners();
  }

  /// Refreshes the database user from the backend.
  Future<void> refreshDbUser() async {
    logger.d('Manually refreshing database user');
    if (_firebaseUser == null) {
      logger.w('Cannot refresh - no Firebase user');
      return;
    }
    try {
      logger.d('Fetching user with externalId: ${_firebaseUser!.uid}');
      _dbUser = await UserService.getUserByExternalId(_firebaseUser!.uid);
      logger.i('Database user refreshed: ${_dbUser?.username}');
      notifyListeners();
    } catch (e, stackTrace) {
      logger.e('Error refreshing database user: $e',
          error: e, stackTrace: stackTrace);
    }
  }

  @override
  void dispose() {
    _notificationPoller.stop();
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
