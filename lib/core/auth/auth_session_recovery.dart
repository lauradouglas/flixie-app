import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/startup_trace.dart';
import 'package:flixie_app/models/user.dart' as models;

/// Per-provider recovery work. Reset at every account boundary, dispose with auth.
/// Profile/routing effects stay in the facade; this owner bounds and shares work.
class AuthSessionRecovery {
  AuthSessionRecovery({
    required firebase_auth.User? Function() user,
    required Future<models.User?> Function(String) loadProfile,
    required void Function(models.User) applyProfile,
    required Future<void> Function() onExpired,
    required void Function() onChanged,
    required bool Function() canResume,
    required void Function() onResumeSuccess,
    required void Function() onThrottledResume,
    required Future<void> Function() onRetry,
  })  : _user = user,
        _loadProfile = loadProfile,
        _applyProfile = applyProfile,
        _onExpired = onExpired,
        _onChanged = onChanged,
        _canResume = canResume,
        _onResumeSuccess = onResumeSuccess,
        _onThrottledResume = onThrottledResume,
        _onRetry = onRetry;

  static const tokenTimeout = Duration(seconds: 8);
  static const profileTimeout = Duration(seconds: 10);
  static const _resumeThrottle = Duration(minutes: 2);
  final firebase_auth.User? Function() _user;
  final Future<models.User?> Function(String) _loadProfile;
  final void Function(models.User) _applyProfile;
  final Future<void> Function() _onExpired;
  final void Function() _onChanged;
  final bool Function() _canResume;
  final void Function() _onResumeSuccess;
  final void Function() _onThrottledResume;
  final Future<void> Function() _onRetry;
  Timer? _bootstrapTimer;
  Timer? _retryTimer;
  int _attempts = 0;
  int _generation = 0;
  bool _disposed = false;
  bool _foreground = true;
  String? _error;
  DateTime? _lastResumeAt;
  Future<bool>? _profileFuture;
  Future<void>? _resumeFuture;

  String? get error => _error;
  bool get foreground => _foreground;

  static bool isExpired(Object error) =>
      error is firebase_auth.FirebaseAuthException &&
      const [
        'user-disabled',
        'user-not-found',
        'user-token-expired',
        'invalid-user-token',
      ].contains(error.code);

  void setError(String? error) => _error = error;

  void startBootstrap(bool Function() isPending) {
    _bootstrapTimer = Timer(tokenTimeout, () {
      if (_disposed || !isPending()) return;
      _error =
          'Couldn’t restore your session. Check your connection and retry.';
      _onChanged();
    });
  }

  void authStateReceived() => _bootstrapTimer?.cancel();

  /// Invalidate pending work without allowing old completion to clear new work.
  void reset() {
    _generation++;
    _profileFuture = null;
    _resumeFuture = null;
    _lastResumeAt = null;
    _error = null;
    _cancelRetry();
  }

  void succeeded() {
    _error = null;
    _cancelRetry();
  }

  void _cancelRetry() {
    _retryTimer?.cancel();
    _attempts = 0;
  }

  Future<void> retry() async {
    if (_disposed) return;
    _cancelRetry();
    await _onRetry();
  }

  void scheduleRetry() {
    if (_disposed ||
        !_foreground ||
        _attempts >= 3 ||
        _retryTimer?.isActive == true) {
      return;
    }
    final generation = _generation;
    final delay = const [5, 15, 30][_attempts++];
    _retryTimer = Timer(Duration(seconds: delay), () {
      if (_disposed || generation != _generation || !_foreground) return;
      unawaited(_onRetry());
    });
  }

  void setForeground(bool value) {
    _foreground = value;
    if (value) {
      _attempts = 0;
    } else {
      _retryTimer?.cancel();
    }
  }

  /// Reuse Firebase's valid token; do not overwrite a newer API 401 refresh.
  Future<void> refreshToken(firebase_auth.User user,
      {required bool Function() isCurrent}) async {
    final revision = ApiClient.tokenRevision;
    final token = await StartupTrace.run(
        'session-token', () => user.getIdToken(false).timeout(tokenTimeout));
    if (!isCurrent()) return;
    if (token == null) throw StateError('No authentication token available');
    if (revision == ApiClient.tokenRevision) ApiClient.setToken(token);
  }

  Future<bool> refreshProfile() async {
    if (_disposed) return false;
    final existing = _profileFuture;
    if (existing != null) return existing;
    final future = _refreshProfile();
    _profileFuture = future;
    try {
      return await future;
    } finally {
      if (identical(_profileFuture, future)) _profileFuture = null;
    }
  }

  Future<bool> _refreshProfile() async {
    final user = _user();
    if (user == null) return false;
    final generation = _generation;
    bool current() => !_disposed && generation == _generation;
    try {
      final profile = await StartupTrace.run(
          'profile', () => _loadProfile(user.uid).timeout(profileTimeout));
      if (!current()) return false;
      if (profile == null) throw StateError('Profile unavailable');
      _error = null;
      _applyProfile(profile);
      return true;
    } catch (error) {
      if (!current()) return false;
      if (isExpired(error)) {
        await _onExpired();
        return false;
      }
      _error = 'Couldn’t refresh. Your saved content is still available.';
      _onChanged();
      return false;
    }
  }

  Future<void> resume({bool force = false}) async {
    if (_disposed || !_canResume() || _user() == null) return;
    final existing = _resumeFuture;
    if (existing != null) return existing;
    if (!force &&
        _lastResumeAt != null &&
        DateTime.now().difference(_lastResumeAt!) < _resumeThrottle) {
      _onThrottledResume();
      return;
    }
    final future = StartupTrace.run('resume-recovery', _refreshAfterResume);
    _resumeFuture = future;
    try {
      await future;
    } finally {
      if (identical(_resumeFuture, future)) _resumeFuture = null;
    }
  }

  Future<void> _refreshAfterResume() async {
    final generation = _generation;
    final user = _user()!;
    bool current() => !_disposed && generation == _generation;
    try {
      await refreshToken(user, isCurrent: current);
      if (!current()) return;
      if (!await refreshProfile()) throw StateError('Profile refresh failed');
      if (!current()) return;
      _lastResumeAt = DateTime.now();
      succeeded();
      _onResumeSuccess();
    } catch (error) {
      if (!current()) return;
      if (isExpired(error)) {
        await _onExpired();
        return;
      }
      _error = 'Couldn’t refresh. Check your connection and retry.';
      _onChanged();
      scheduleRetry();
    }
  }

  void dispose() {
    _disposed = true;
    reset();
    _bootstrapTimer?.cancel();
  }
}
