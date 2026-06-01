import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../models/activity_list_item.dart';
import '../models/favorite_movie.dart';
import '../models/friendship.dart';
import '../models/movie_rating.dart';
import '../models/movie_short.dart';
import '../models/review.dart';
import '../models/user.dart' as models;
import '../models/watched_movie.dart';
import '../models/watchlist_movie.dart';
import '../providers/auth/auth_notification_poller.dart';
import '../providers/auth/auth_prefetch_coordinator.dart';
import '../providers/auth/auth_prefetch_snapshot.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/movie_service.dart';
import '../services/push_notification_service.dart';
import '../services/user_service.dart';
import '../utils/app_logger.dart';

/// Auth states that the UI can observe.
enum AuthStatus { unknown, authenticated, unauthenticated }

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
    this._movieService, {
    AuthPrefetchCoordinator? prefetchCoordinator,
  }) : _prefetchCoordinator =
            prefetchCoordinator ?? AuthPrefetchCoordinator(movieService: _movieService) {
    _authService.authStateChanges.listen((user) {
      unawaited(_onAuthStateChanged(user));
    });
  }

  final AuthService _authService;
  final MovieService _movieService;
  final AuthPrefetchCoordinator _prefetchCoordinator;
  final AuthNotificationPoller _notificationPoller = AuthNotificationPoller();
  final _authStatusNotifier = _AuthStatusNotifier();

  AuthStatus _status = AuthStatus.unknown;
  firebase_auth.User? _firebaseUser;
  models.User? _dbUser;
  bool _isLoading = false;
  String? _errorMessage;
  int _activityVersion = 0;

  // Prefetched at login — screens use these to skip spinners
  List<ActivityListItem>? _cachedActivity;
  FriendsData? _cachedFriends;
  List<MovieRating>? _cachedRatings;
  List<Review>? _cachedReviews;
  List<MovieShort>? _cachedTrending;
  List<MovieShort>? _cachedNowPlaying;
  bool _isPrefetching = false;

  int _unreadNotificationCount = 0;

  /// Navigator key set by the app root so push notifications can navigate.
  GlobalKey<NavigatorState>? _navigatorKey;

  /// Call once the root navigator is ready (e.g. in [FlixieApp.initState]).
  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  AuthStatus get status => _status;
  firebase_auth.User? get firebaseUser => _firebaseUser;
  models.User? get dbUser => _dbUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  int get activityVersion => _activityVersion;

  List<ActivityListItem>? get cachedActivity => _cachedActivity;
  FriendsData? get cachedFriends => _cachedFriends;
  List<MovieRating>? get cachedRatings => _cachedRatings;
  List<Review>? get cachedReviews => _cachedReviews;
  List<MovieShort>? get cachedTrending => _cachedTrending;
  List<MovieShort>? get cachedNowPlaying => _cachedNowPlaying;
  bool get isPrefetching => _isPrefetching;
  int get unreadNotificationCount => _unreadNotificationCount;

  /// Update the reviews cache, e.g. after writing a new review.
  void updateCachedReviews(List<Review> reviews) {
    _cachedReviews = reviews;
    notifyListeners();
  }

  /// Update the friends cache, e.g. after accepting/declining a request.
  void updateCachedFriends(FriendsData friends) {
    _cachedFriends = friends;
    notifyListeners();
  }

  /// Call after adding an item to any list so activity-watching screens can refresh.
  void markActivityChanged() {
    _activityVersion++;
    notifyListeners();
  }

  /// A Listenable that only notifies when auth status changes, not when user data changes.
  /// Use this for router refresh to avoid unnecessary navigation rebuilds.
  Listenable get authStatusListenable => _authStatusNotifier;

  // Flag set during sign-up to prevent _onAuthStateChanged from running
  // getUserByExternalId before the DB user has been created.
  bool _isSigningUp = false;
  bool _isHandlingAuthState = false;

  Future<void> _onAuthStateChanged(firebase_auth.User? user) async {
    // During sign-up the flow is managed directly in signUp(); skip here.
    if (_isSigningUp) return;
    if (_isHandlingAuthState) return;
    _isHandlingAuthState = true;

    try {
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
        if (_dbUser?.id != null && _dbUser!.externalId != null) {
          unawaited(PushNotificationService.removeToken(_dbUser!.externalId!));
        }
        ApiClient.setToken(null);
        _dbUser = null;
        _status = AuthStatus.unauthenticated;
        _isPrefetching = false;
        _cachedActivity = null;
        _cachedFriends = null;
        _cachedRatings = null;
        _cachedReviews = null;
        _cachedTrending = null;
        _cachedNowPlaying = null;
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
    } finally {
      _isHandlingAuthState = false;
    }
  }

  /// Fetches profile/friend/home cache in parallel right after login.
  void _prefetch(String userId, {String region = 'US'}) {
    _isPrefetching = true;
    _prefetchCoordinator.prefetch(userId, region: region).then((snapshot) {
      _applyPrefetchSnapshot(snapshot);
      logger.i('[AuthProvider] Prefetch complete for $userId');
      _isPrefetching = false;
      _notificationPoller.start(
        interval: const Duration(seconds: 30),
        onTick: refreshNotificationCount,
      );

      // Initialise push notifications now that we have a valid user and the
      // widget tree is about to be ready. We do this inside a post-frame
      // callback to ensure the navigator key has been attached.
      final key = _navigatorKey;
      if (key != null) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          PushNotificationService.initialize(
            userId: _dbUser?.externalId ?? userId,
            navigatorKey: key,
          );
        });
      }

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

  void _applyPrefetchSnapshot(AuthPrefetchSnapshot snapshot) {
    _cachedActivity = snapshot.activity ?? _cachedActivity;
    _cachedFriends = snapshot.friends ?? _cachedFriends;
    _cachedFriendsActivity = snapshot.friendsActivity ?? _cachedFriendsActivity;
    _cachedRatings = snapshot.ratings ?? _cachedRatings;
    _cachedReviews = snapshot.reviews ?? _cachedReviews;
    _cachedTrending = snapshot.trending ?? _cachedTrending;
    _cachedNowPlaying = snapshot.nowPlaying ?? _cachedNowPlaying;
    _unreadNotificationCount =
        snapshot.unreadNotificationCount ?? _unreadNotificationCount;
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

  /// Creates a new account. Returns `true` on success.
  ///
  /// Creates the Firebase user first, then registers the user in the backend
  /// database. If the database call fails, the Firebase account is deleted so
  /// no orphaned credential is left behind.
  /// Creates a new account. Returns `true` on success.
  ///
  /// Creates the Firebase user first, then registers the user in the backend
  /// database. If the database call fails, the Firebase account is deleted so
  /// no orphaned credential is left behind.
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
    _setLoading(true);
    _setError(null);
    _isSigningUp = true;
    firebase_auth.UserCredential? credential;
    bool succeeded = false;
    try {
      final displayName = '${firstName.trim()} ${lastName.trim()}';
      credential = await _authService.signUp(email, password, displayName);

      final uid = credential.user!.uid;

      // Register in the backend database.
      final createUserBody = <String, dynamic>{
        'externalId': uid,
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'email': email.trim(),
        'username': username.trim(),
        'bio': '',
      };
      if (languageId != null) {
        createUserBody['languageId'] = languageId;
      }
      if (countryId != null) {
        createUserBody['countryId'] = countryId;
      }

      _dbUser = await UserService.createUser(createUserBody);

      // Save favourite genres if any were selected
      if (genreIds.isNotEmpty && _dbUser?.id != null) {
        await UserService.addFavoriteGenres(_dbUser!.id, genreIds);
      }

      _firebaseUser = credential.user;
      _status = AuthStatus.authenticated;
      if (_dbUser?.id != null) {
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
    } on firebase_auth.FirebaseAuthException catch (e) {
      _errorMessage = AuthService.messageFromAuthException(e);
      return false;
    } catch (e) {
      logger.e('Error during sign-up: $e');
      _errorMessage = 'Failed to create account. Please try again.';
      // Roll back the Firebase account so the user can try again.
      try {
        await credential?.user?.delete();
      } catch (deleteError) {
        logger.e('Failed to roll back Firebase account: $deleteError');
      }
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
    List<WatchlistMovie>? movieWatchlist,
    List<FavoriteMovie>? favoriteMovies,
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
    if (favoriteMovies != null) {
      logger.d('Favorites: ${favoriteMovies.length} items');
    }
    if (favoritePeople != null) {
      logger.d('Fav people: ${favoritePeople.length} items');
    }

    _dbUser = _dbUser!.copyWith(
      watchedMovies: watchedMovies ?? _dbUser!.watchedMovies,
      movieWatchlist: movieWatchlist ?? _dbUser!.movieWatchlist,
      favoriteMovies: favoriteMovies ?? _dbUser!.favoriteMovies,
      favoritePeople: favoritePeople ?? _dbUser!.favoritePeople,
    );
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
