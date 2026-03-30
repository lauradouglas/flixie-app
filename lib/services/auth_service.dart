import 'package:firebase_auth/firebase_auth.dart';

import '../utils/app_logger.dart';
import 'api_client.dart';

/// Wraps Firebase Authentication to provide login, sign-up, logout,
/// forgot-password, and user-profile operations.
class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// Stream that emits the current [User] whenever the auth state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// The currently signed-in [User], or `null` if not authenticated.
  User? get currentUser => _auth.currentUser;

  /// Signs in with [email] and [password].
  ///
  /// Throws a [FirebaseAuthException] on failure.
  Future<UserCredential> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // Get the ID token and set it in ApiClient
    final idToken = await credential.user?.getIdToken();
    if (idToken != null) {
      apiLogger.d('Got Firebase ID token, setting in ApiClient');
      ApiClient.setToken(idToken);
    }

    return credential;
  }

  /// Creates a new account with [email] and [password], then sets [displayName].
  ///
  /// Throws a [FirebaseAuthException] on failure.
  Future<UserCredential> signUp(
    String email,
    String password,
    String displayName,
  ) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.updateDisplayName(displayName.trim());

    // Get the ID token and set it in ApiClient
    final idToken = await credential.user?.getIdToken();
    if (idToken != null) {
      apiLogger.d('Got Firebase ID token after signup, setting in ApiClient');
      ApiClient.setToken(idToken);
    }

    return credential;
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    apiLogger.d('Signing out, clearing API token');
    ApiClient.setToken(null);
    await _auth.signOut();
  }

  /// Sends a password-reset email to [email].
  ///
  /// Throws a [FirebaseAuthException] on failure.
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Reauthenticates then changes the password of the current user.
  ///
  /// Throws a [FirebaseAuthException] on failure (e.g. wrong current password).
  Future<void> updatePassword(
      String currentPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw FirebaseAuthException(code: 'no-current-user');
    }
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  /// Reloads and returns an up-to-date [User] profile, or `null` if not
  /// authenticated.
  Future<User?> getUserProfile() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser;
  }

  /// Returns a human-readable message for common [FirebaseAuthException] codes.
  static String messageFromAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return e.message ?? 'An unexpected error occurred.';
    }
  }
}
