import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';

import '../models/user.dart' as models;
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

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

  AuthStatus _status = AuthStatus.unknown;
  firebase_auth.User? _firebaseUser;
  models.User? _dbUser;
  bool _isLoading = false;
  String? _errorMessage;

  AuthStatus get status => _status;
  firebase_auth.User? get firebaseUser => _firebaseUser;
  models.User? get dbUser => _dbUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  void _onAuthStateChanged(firebase_auth.User? user) async {
    print('🔄 [AuthProvider] Auth state changed');
    print('   Firebase user: ${user?.email ?? "null"} (uid: ${user?.uid ?? "null"})');
    
    _firebaseUser = user;
    
    if (user != null) {
      // FIRST: Get Firebase ID token and set it in ApiClient
      try {
        final idToken = await user.getIdToken();
        if (idToken != null) {
          print('🔑 [AuthProvider] Got Firebase ID token, setting in ApiClient');
          ApiClient.setToken(idToken);
        } else {
          print('⚠️ [AuthProvider] ID token is null');
        }
      } catch (e) {
        print('⚠️ [AuthProvider] Failed to get ID token: $e');
      }
      
      // THEN: Fetch the database user using Firebase UID as externalId
      print('📥 [AuthProvider] Fetching database user with externalId: ${user.uid}');
      try {
        _dbUser = await UserService.getUserByExternalId(user.uid);
        print('✅ [AuthProvider] Database user fetched successfully');
        print('   DB User: ${_dbUser?.username} (id: ${_dbUser?.id})');
        print('   Email: ${_dbUser?.email}');
        print('   Name: ${_dbUser?.firstName} ${_dbUser?.lastName}');
        _status = AuthStatus.authenticated;
      } catch (e, stackTrace) {
        print('❌ [AuthProvider] Error fetching database user: $e');
        print('   Stack trace: $stackTrace');
        _dbUser = null;
        _status = AuthStatus.unauthenticated;
      }
    } else {
      print('👋 [AuthProvider] User signed out, clearing database user');
      ApiClient.setToken(null);
      _dbUser = null;
      _status = AuthStatus.unauthenticated;
    }
    
    print('📊 [AuthProvider] Final status: $_status');
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
  Future<bool> signUp(
    String email,
    String password,
    String displayName,
  ) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.signUp(email, password, displayName);
      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      _setError(AuthService.messageFromAuthException(e));
      return false;
    } finally {
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
  
  /// Refreshes the database user from the backend.
  Future<void> refreshDbUser() async {
    print('🔄 [AuthProvider] Manually refreshing database user');
    if (_firebaseUser == null) {
      print('⚠️ [AuthProvider] Cannot refresh - no Firebase user');
      return;
    }
    try {
      print('📥 [AuthProvider] Fetching user with externalId: ${_firebaseUser!.uid}');
      _dbUser = await UserService.getUserByExternalId(_firebaseUser!.uid);
      print('✅ [AuthProvider] Database user refreshed: ${_dbUser?.username}');
      notifyListeners();
    } catch (e, stackTrace) {
      print('❌ [AuthProvider] Error refreshing database user: $e');
      print('   Stack trace: $stackTrace');
    }
  }
}
