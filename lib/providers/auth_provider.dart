import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../models/activity_list_item.dart';
import '../models/friendship.dart';
import '../models/movie_rating.dart';
import '../models/review.dart';
import '../models/user.dart' as models;
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/friend_service.dart';
import '../services/user_service.dart';
import '../utils/app_logger.dart';

/// Auth states that the UI can observe.
enum AuthStatus { unknown, authenticated, unauthenticated }

/// Exposes Firebase auth state to the widget tree via [ChangeNotifier].
///
/// Screens can read [status], [firebaseUser], [dbUser], [isLoading] and [errorMessage] and call
/// [signIn], [signUp], [signOut] and [sendPasswordResetEmail].
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._authService) {
    _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  final AuthService _authService;
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
  bool _isPrefetching = false;

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
  bool get isPrefetching => _isPrefetching;

  /// Update the reviews cache, e.g. after writing a new review.
  void updateCachedReviews(List<Review> reviews) {
    _cachedReviews = reviews;
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

  void _onAuthStateChanged(firebase_auth.User? user) async {
    // During sign-up the flow is managed directly in signUp(); skip here.
    if (_isSigningUp) return;

    logger.i('Auth state changed');
    logger.d(
        'Firebase user: ${user?.email ?? "null"} (uid: ${user?.uid ?? "null"})');

    _firebaseUser = user;
    final oldStatus = _status;

    if (user != null) {
      // FIRST: Get Firebase ID token and set it in ApiClient
      try {
        final idToken = await user.getIdToken();
        if (idToken != null) {
          logger.d('Got Firebase ID token, setting in ApiClient');
          ApiClient.setToken(idToken);
        } else {
          logger.w('ID token is null');
        }
      } catch (e) {
        logger.w('Failed to get ID token: $e');
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
        if (_dbUser?.id != null) _prefetch(_dbUser!.id);
      } catch (e, stackTrace) {
        logger.e('Error fetching database user: $e',
            error: e, stackTrace: stackTrace);
        _dbUser = null;
        _status = AuthStatus.unauthenticated;
      }
    } else {
      logger.i('User signed out, clearing database user');
      ApiClient.setToken(null);
      _dbUser = null;
      _status = AuthStatus.unauthenticated;
      _isPrefetching = false;
      _cachedActivity = null;
      _cachedFriends = null;
      _cachedRatings = null;
      _cachedReviews = null;
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

  /// Fetches activity, friends, ratings and reviews in parallel right after
  /// login. Screens consume the results to avoid showing spinners on first load.
  void _prefetch(String userId) {
    Future.wait([
      UserService.getUserActivity(userId)
          .then((v) => _cachedActivity = v, onError: (_) {}),
      FriendService.getFriends(userId)
          .then((v) => _cachedFriends = v, onError: (_) {}),
      UserService.getUserMovieRatings(userId)
          .then((v) => _cachedRatings = v, onError: (_) {}),
      UserService.getUserMovieReviews(userId)
          .then((v) => _cachedReviews = v, onError: (_) {}),
    ]).then((_) {
      logger.i('[AuthProvider] Prefetch complete for $userId');
      notifyListeners();
    }).catchError((e) {
      logger.w('[AuthProvider] Prefetch error: $e');
    });
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

  /// Signs in with email and password. Returns `true` on success.
  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.signIn(email, password);
      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      _setError(AuthService.messageFromAuthException(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

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
    required int languageId,
    required int countryId,
  }) async {
    _setLoading(true);
    _setError(null);
    _isSigningUp = true;
    firebase_auth.UserCredential? credential;
    try {
      final displayName = '${firstName.trim()} ${lastName.trim()}';
      credential = await _authService.signUp(email, password, displayName);

      final uid = credential.user!.uid;

      // Register in the backend database.
      _dbUser = await UserService.createUser({
        'externalId': uid,
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'email': email.trim(),
        'username': username.trim(),
        'bio': '',
        'languageId': languageId,
        'countryId': countryId,
      });

      _firebaseUser = credential.user;
      _status = AuthStatus.authenticated;
      if (_dbUser?.id != null) _prefetch(_dbUser!.id);
      // Defer router notification: _setLoading(false) in the finally block calls
      // notifyListeners() immediately, marking the signup screen dirty. If
      // _authStatusNotifier.notify() fired in the same frame, GoRouter would
      // deactivate the screen while it is still in _dirtyElements → crash.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _authStatusNotifier.notify();
        SchedulerBinding.instance
            .addPostFrameCallback((_) => notifyListeners());
      });
      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      _setError(AuthService.messageFromAuthException(e));
      return false;
    } catch (e) {
      logger.e('Error during sign-up: $e');
      _setError('Failed to create account. Please try again.');
      // Roll back the Firebase account so the user can try again.
      try {
        await credential?.user?.delete();
      } catch (deleteError) {
        logger.e('Failed to roll back Firebase account: $deleteError');
      }
      return false;
    } finally {
      _isSigningUp = false;
      _setLoading(false);
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
    List<dynamic>? watchedMovies,
    List<dynamic>? movieWatchlist,
    List<dynamic>? favoriteMovies,
    List<dynamic>? favoritePeople,
  }) {
    if (_dbUser == null) return;

    logger.d('Updating user lists:');
    if (watchedMovies != null)
      logger.d('Watched: ${watchedMovies.length} items');
    if (movieWatchlist != null)
      logger.d('Watchlist: ${movieWatchlist.length} items');
    if (favoriteMovies != null)
      logger.d('Favorites: ${favoriteMovies.length} items');
    if (favoritePeople != null)
      logger.d('Fav people: ${favoritePeople.length} items');

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
}

/// A minimal ChangeNotifier that only notifies when auth status changes.
/// This is used by GoRouter to avoid rebuilding routes when user data changes.
class _AuthStatusNotifier extends ChangeNotifier {
  void notify() {
    notifyListeners();
  }
}
