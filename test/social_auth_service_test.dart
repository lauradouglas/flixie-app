import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/auth/auth_service.dart';
import 'package:flixie_app/core/auth/social_auth_provider.dart';

class _Info extends Fake implements fb.UserInfo {
  _Info(this.providerId);
  @override
  final String providerId;
}

class _Additional extends Fake implements fb.AdditionalUserInfo {
  @override
  String get authorizationCode => 'fixture-authorization-code';
}

class _Credential extends Fake implements fb.UserCredential {
  @override
  fb.AdditionalUserInfo get additionalUserInfo => _Additional();
}

class _User extends Fake implements fb.User {
  _User(this.providers);
  final List<String> providers;
  int links = 0;
  int confirmations = 0;
  @override
  String get email => 'odyssey-fan@example.invalid';
  @override
  List<fb.UserInfo> get providerData => providers.map(_Info.new).toList();
  @override
  Future<fb.UserCredential> linkWithProvider(fb.AuthProvider provider) async {
    expect(provider.providerId, 'apple.com');
    links++;
    return _Credential();
  }

  @override
  Future<fb.UserCredential> reauthenticateWithProvider(
      fb.AuthProvider provider) async {
    expect(provider.providerId, 'apple.com');
    confirmations++;
    return _Credential();
  }

  @override
  Future<fb.UserCredential> reauthenticateWithCredential(
      fb.AuthCredential credential) async {
    expect(credential.providerId, 'password');
    confirmations++;
    return _Credential();
  }
}

class _Firebase extends Fake implements fb.FirebaseAuth {
  _Firebase(this.user);
  final _User user;
  int signIns = 0;
  String? revokedCode;
  @override
  fb.User get currentUser => user;
  @override
  Future<fb.UserCredential> signInWithProvider(fb.AuthProvider provider) async {
    expect(provider.providerId, 'apple.com');
    signIns++;
    return _Credential();
  }

  @override
  Future<void> revokeTokenWithAuthorizationCode(String code) async {
    revokedCode = code;
  }
}

void main() {
  test(
      'backend null profile is an explicit missing profile, not a parsing failure',
      () async {
    await http.runWithClient(() async {
      await expectLater(
          UserService.getUserByExternalId('fixture-social-user'),
          throwsA(isA<ApiException>()
              .having((error) => error.statusCode, 'status', 404)));
    }, () => MockClient((_) async => http.Response('null', 200)));
  });

  test('Apple login uses native sign-in, linking uses only the current user',
      () async {
    final firebase = _Firebase(_User(['password']));
    final service = AuthService(firebaseAuth: firebase);
    await service.signInWithSocialProvider(SocialAuthProvider.apple);
    await service.linkSocialProvider(SocialAuthProvider.apple);
    expect(firebase.signIns, 1);
    expect(firebase.user.links, 1);
  });

  test(
      'Apple deletion reauthenticates and revokes the authorization code on iOS',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final firebase = _Firebase(_User(['apple.com', 'password']));
    await AuthService(firebaseAuth: firebase).prepareAccountDeletion('');
    expect(firebase.user.confirmations, 1);
    expect(firebase.revokedCode, 'fixture-authorization-code');
  });

  test('password account deletion retains password reauthentication', () async {
    final firebase = _Firebase(_User(['password']));
    await AuthService(firebaseAuth: firebase)
        .prepareAccountDeletion('fixture-password');
    expect(firebase.user.confirmations, 1);
    expect(firebase.revokedCode, isNull);
  });
}
