import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:flixie_app/core/auth/auth_service.dart';
import 'package:flixie_app/core/auth/firebase_environment.dart';
import 'package:flixie_app/core/auth/social_auth_provider.dart';
import 'package:flixie_app/features/authentication/presentation/pages/signup_screen.dart';
import 'package:flixie_app/features/guest/presentation/guest_access.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'support/signup_local_journey.dart';

/// Replaces only the external Apple/Google picker with an emulator credential.
/// The native Firebase SDK, AuthProvider, forms, router and local API stay real.
/// These tests do NOT prove a live Apple/Google consent or provider configuration.
class EmulatorSocialService extends AuthService {
  fb.FirebaseAuthException? failure;
  String encode(Map<String, Object> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  @override
  Future<fb.UserCredential> signInWithSocialProvider(
      SocialAuthProvider provider) {
    if (failure != null) throw failure!;
    final subject =
        'signup-${provider.name}-${DateTime.now().microsecondsSinceEpoch}';
    final token = '${encode({'alg': 'none', 'typ': 'JWT'})}.${encode({
          'sub': subject,
          'email': '$subject@example.invalid',
          'email_verified': true,
          'name': 'Social Fixture',
          'aud': FirebaseEnvironment.projectId,
          'iss': provider == SocialAuthProvider.google
              ? 'https://accounts.google.com'
              : 'https://appleid.apple.com',
          'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600
        })}.';
    final credential = provider == SocialAuthProvider.google
        ? fb.GoogleAuthProvider.credential(idToken: token)
        : fb.OAuthProvider('apple.com').credential(idToken: token);
    return FirebaseEnvironment.auth.signInWithCredential(credential);
  }
}

void main() {
  for (final provider in SocialAuthProvider.values) {
    patrolTest(
        'native Firebase emulator ${provider.label} credential completes profile, avatar and pending save',
        ($) async {
      final h = LocalSignupJourney($);
      await h.start(authServiceFactory: () => EmulatorSocialService());
      await h.open('/movies/348');
      await h.until(
          () => find.text('Watchlist').evaluate().isNotEmpty, 'guest title');
      await h.tap(find.text('Watchlist'));
      await h.chooseSignup();
      await h.tap(find.text('Continue with ${provider.label}'));
      await h.until(() => h.auth.needsSocialProfile,
          'native Firebase provider credential accepted');
      expect(GuestAccess.action, 'guest-watchlist');
      await h.fillSocialProfile();
      await h.until(
          () => find.text('Anything else for later?').evaluate().isNotEmpty,
          'pending save after social profile');
      expect(
          (await h.io(() => UserService.getUserById(h.auth.dbUser!.id)))
              .movieWatchlist!
              .where((m) => m.movieId == 348),
          hasLength(1));
      expect(
          FirebaseEnvironment.auth.currentUser!.providerData
              .any((p) => p.providerId == provider.id),
          true);
    }, timeout: const Timeout(Duration(minutes: 4)));
    for (final code in ['canceled', 'network-request-failed']) {
      patrolTest(
          '${provider.label} $code preserves signup intent and permits email recovery',
          ($) async {
        final h = LocalSignupJourney($);
        await h.start(
            authServiceFactory: () => EmulatorSocialService()
              ..failure = fb.FirebaseAuthException(
                  code: code, message: 'Isolated provider fixture'));
        await h.open('/movies/348');
        await h.until(
            () => find.text('Watchlist').evaluate().isNotEmpty, 'guest title');
        await h.tap(find.text('Watchlist'));
        await h.chooseSignup();
        await h.tap(find.text('Continue with ${provider.label}'));
        expect(find.byType(SignupScreen), findsOneWidget);
        expect(h.auth.dbUser, isNull);
        expect(GuestAccess.action, 'guest-watchlist');
        expect(GuestAccess.destination, '/guest-watchlist');
        await h.fillSignup();
        await h.until(
            () => find.text('Anything else for later?').evaluate().isNotEmpty,
            'email recovery retains original save');
      }, timeout: const Timeout(Duration(minutes: 4)));
    }
  }
}
