import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'social_auth_provider.dart';

import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/core/api/api_client.dart';

/// Wraps Firebase Authentication to provide login, sign-up, logout,
/// forgot-password, and user-profile operations.
class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  static Future<void>? _googleInitialization;

  AuthProvider _provider(SocialAuthProvider provider) =>
      provider == SocialAuthProvider.apple
          ? (AppleAuthProvider()
            ..addScope('email')
            ..addScope('name'))
          : (GoogleAuthProvider()
            ..setCustomParameters({'prompt': 'select_account'}));

  Future<AuthCredential> _googleCredential() async {
    try {
      const serverClientId =
          String.fromEnvironment('FLIXIE_GOOGLE_WEB_CLIENT_ID');
      await (_googleInitialization ??= GoogleSignIn.instance.initialize(
        serverClientId: serverClientId.isEmpty ? null : serverClientId,
      ));
    } catch (_) {
      _googleInitialization = null;
      rethrow;
    }
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw FirebaseAuthException(code: 'missing-id-token');
      }
      return GoogleAuthProvider.credential(idToken: idToken);
    } on GoogleSignInException catch (error) {
      throw FirebaseAuthException(
        code: error.code == GoogleSignInExceptionCode.canceled
            ? 'sign-in-cancelled'
            : 'google-sign-in-failed',
      );
    }
  }

  /// Authenticates with the provider, leaving profile loading to AuthProvider.
  Future<UserCredential> signInWithSocialProvider(
      SocialAuthProvider provider) async {
    if (kIsWeb) return _auth.signInWithPopup(_provider(provider));
    if (provider == SocialAuthProvider.google) {
      return _auth.signInWithCredential(await _googleCredential());
    }
    return _auth.signInWithProvider(_provider(provider));
  }

  /// Adds a sign-in method to the current UID; never switches or merges users.
  Future<void> linkSocialProvider(SocialAuthProvider provider) async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-current-user');
    if (user.providerData.any((info) => SocialAuthProvider.values
        .any((provider) => provider.id == info.providerId))) {
      throw FirebaseAuthException(code: 'provider-already-linked');
    }
    if (kIsWeb) {
      await user.linkWithPopup(_provider(provider));
    } else if (provider == SocialAuthProvider.google) {
      await user.linkWithCredential(await _googleCredential());
    } else {
      await user.linkWithProvider(_provider(provider));
    }
  }

  static bool isCancellation(FirebaseAuthException error) => const {
        'sign-in-cancelled',
        'canceled',
        'cancelled-popup-request',
        'popup-closed-by-user',
        'web-context-cancelled',
      }.contains(error.code);

  /// Confirms ownership and revokes Apple authorization before account deletion.
  Future<void> prepareAccountDeletion(String password) async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-current-user');
    final providers = user.providerData.map((info) => info.providerId).toSet();
    if (providers.contains('apple.com')) {
      final provider = _provider(SocialAuthProvider.apple);
      final result = kIsWeb
          ? await user.reauthenticateWithPopup(provider)
          : await user.reauthenticateWithProvider(provider);
      final code = result.additionalUserInfo?.authorizationCode;
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS)) {
        if (code == null || code.isEmpty) {
          throw FirebaseAuthException(code: 'apple-revocation-failed');
        }
        await _auth.revokeTokenWithAuthorizationCode(code);
      }
    } else if (providers.contains('password')) {
      await reauthenticate(password);
    } else if (providers.contains('google.com')) {
      if (kIsWeb) {
        await user
            .reauthenticateWithPopup(_provider(SocialAuthProvider.google));
      } else {
        await user.reauthenticateWithCredential(await _googleCredential());
      }
    } else {
      throw FirebaseAuthException(code: 'no-current-user');
    }
  }

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

    // AuthProvider owns token installation and profile loading for both sign-in
    // and restored sessions, avoiding a duplicate Firebase token read here.
    return credential;
  }

  /// Creates a new account with [email] and [password], then sets [displayName].
  ///
  /// Throws a [FirebaseAuthException] on failure.
  Future<String> signUp(
    String email,
    String password,
    String displayName,
  ) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.updateDisplayName(displayName.trim());

    final idToken = await credential.user?.getIdToken(true);
    if (idToken == null) {
      throw FirebaseAuthException(code: 'missing-id-token');
    }
    apiLogger.d('Got fresh Firebase ID token after signup');
    ApiClient.setToken(idToken);
    return idToken;
  }

  /// Forces Firebase to refresh the current user's ID token for an API retry.
  Future<String> refreshIdToken() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'no-current-user');
    }
    final token = await user.getIdToken(true);
    if (token == null) {
      throw FirebaseAuthException(code: 'missing-id-token');
    }
    return token;
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    apiLogger.d('Signing out, clearing API token');
    ApiClient.setToken(null);
    await _auth.signOut();
    if (!kIsWeb && _googleInitialization != null) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Firebase sign-out remains authoritative if SDK cleanup fails.
      }
    }
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
    await reauthenticate(currentPassword);
    await _auth.currentUser!.updatePassword(newPassword);
  }

  /// Confirms the current email/password credential before a sensitive action.
  Future<void> reauthenticate(String currentPassword) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw FirebaseAuthException(code: 'no-current-user');
    }
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
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
      case 'account-exists-with-different-credential':
        return 'Sign in with your existing method, then connect this account in Settings.';
      case 'credential-already-in-use':
        return 'This Apple or Google account is connected to another Flixie account.';
      case 'provider-already-linked':
        return 'This sign-in method is already connected.';
      case 'operation-not-allowed':
      case 'google-sign-in-failed':
        return 'This sign-in option is unavailable right now. Please try another method.';
      case 'user-mismatch':
        return 'Choose the Apple or Google account connected to this Flixie account.';
      case 'popup-blocked':
        return 'Allow pop-ups for Flixie, then try again.';
      case 'apple-revocation-failed':
        return 'Unable to disconnect Apple. Please try deleting your account again.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Password must be at least 8 characters and include uppercase, lowercase, a number, and a special character.';
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
