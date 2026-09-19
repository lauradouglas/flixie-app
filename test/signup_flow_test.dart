import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart'
    show FirebaseAuthException, User;
import 'package:flutter_test/flutter_test.dart';

import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/auth/auth_service.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/models/user.dart' as model;
import 'package:flixie_app/models/profile_avatar.dart';

class _FakeFirebaseUser extends Fake implements User {}

class _SignupAuthService extends Fake implements AuthService {
  final _controller = StreamController<User?>.broadcast();
  int signupCalls = 0;
  int refreshCalls = 0;
  Object? signupError;
  bool hasUser = false;

  @override
  Stream<User?> get authStateChanges => _controller.stream;

  @override
  User? get currentUser => hasUser ? _FakeFirebaseUser() : null;

  @override
  Future<String> signUp(
      String email, String password, String displayName) async {
    signupCalls++;
    if (signupError case final error?) throw error;
    hasUser = true;
    ApiClient.setToken('fresh-signup-token');
    return 'fresh-signup-token';
  }

  @override
  Future<String> refreshIdToken() async {
    refreshCalls++;
    ApiClient.setToken('refreshed-token');
    return 'refreshed-token';
  }

  void close() => _controller.close();
}

model.User _createdUser({String username = 'Movie_User.99'}) => model.User(
      id: 'profile-1',
      externalId: 'firebase-1',
      firstName: 'Laura',
      lastName: 'Douglas',
      username: username,
      email: 'laura@example.com',
      bio: '',
      iconColorId: 1,
      completedSetup: false,
      darkMode: true,
    );

Map<String, Object?> _expectedBody() => <String, Object?>{
      'termsAccepted': true,
      'firstName': 'Laura',
      'lastName': 'Douglas',
      'username': 'Movie_User.99',
      'email': 'laura@example.com',
      'bio': '',
      'countryId': null,
      'languageId': null,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _SignupAuthService authService;

  setUp(() {
    authService = _SignupAuthService();
    ApiClient.setToken(null);
  });

  tearDown(() {
    authService.close();
    ApiClient.setToken(null);
  });

  Future<bool> signUp(AuthProvider provider) => provider.signUp(
        termsAccepted: true,
        email: 'laura@example.com',
        password: 'Password1!',
        firstName: 'Laura',
        lastName: 'Douglas',
        username: 'Movie_User.99',
      );

  test('account terms are verified remotely and accepted explicitly', () async {
    final provider = AuthProvider(authService, MovieService(),
        prefetchAfterAuth: false, profileCreator: (_) async => _createdUser());
    var accepted = false;
    await http.runWithClient(() async {
      expect(await provider.verifyTerms(), isFalse);
      expect(provider.termsVerified, isFalse);
      expect(await provider.verifyTerms(accept: true), isTrue);
      expect(provider.termsVerified, isTrue);
      expect(await provider.verifyTerms(), isTrue);
    },
        () => MockClient((request) async {
              expect(request.url.path, '/users/me/terms');
              if (request.method == 'POST') {
                expect(jsonDecode(request.body),
                    {'termsAccepted': true, 'version': '2026-09-16'});
                accepted = true;
              }
              return http.Response(
                  jsonEncode({'accepted': accepted, 'version': '2026-09-16'}),
                  200);
            }));
    provider.dispose();
  });

  test('failed terms save does not unlock the account', () async {
    final provider = AuthProvider(authService, MovieService(),
        prefetchAfterAuth: false, profileCreator: (_) async => _createdUser());
    await http.runWithClient(() async {
      await expectLater(
          provider.verifyTerms(accept: true), throwsA(isA<ApiException>()));
      expect(provider.termsVerified, isFalse);
    },
        () => MockClient(
            (_) async => http.Response('{"error":"unavailable"}', 503)));
    provider.dispose();
  });

  test('signup without agreement creates neither identity nor profile',
      () async {
    var profileCalls = 0;
    final provider = AuthProvider(authService, MovieService(),
        prefetchAfterAuth: false, profileCreator: (body) async {
      profileCalls++;
      return _createdUser();
    });
    expect(
        await provider.signUp(
            termsAccepted: false,
            email: 'test@example.com',
            password: 'Password1!',
            firstName: 'Test',
            lastName: 'User',
            username: 'tester'),
        isFalse);
    expect(
        await provider.beginAvatarSignUp(
            termsAccepted: false,
            email: 'test@example.com',
            password: 'Password1!',
            firstName: 'Test',
            lastName: 'User',
            username: 'tester'),
        isFalse);
    expect(authService.signupCalls, 0);
    expect(profileCalls, 0);
    provider.dispose();
  });

  test('successful signup creates Firebase then forwards token and safe body',
      () async {
    Map<String, dynamic>? receivedBody;
    String? receivedToken;
    final provider = AuthProvider(
      authService,
      MovieService(),
      prefetchAfterAuth: false,
      profileCreator: (body) async {
        receivedBody = Map<String, dynamic>.from(body);
        receivedToken = ApiClient.getToken();
        return _createdUser();
      },
    );

    expect(await signUp(provider), isTrue);
    expect(authService.signupCalls, 1);
    expect(receivedToken, 'fresh-signup-token');
    expect(receivedBody, _expectedBody());
    expect(provider.dbUser?.username, 'Movie_User.99');
    expect(provider.status, AuthStatus.authenticated);
    expect(provider.termsVerified, isTrue);
  });

  test('username availability path URL-encodes the username', () {
    expect(
      UserService.usernameAvailabilityPath('Movie User/99'),
      '/users/Movie%20User%2F99/exists',
    );
  });

  test('signup forwards a normalized referral code', () async {
    Map<String, dynamic>? receivedBody;
    final provider = AuthProvider(
      authService,
      MovieService(),
      prefetchAfterAuth: false,
      profileCreator: (body) async {
        receivedBody = Map<String, dynamic>.from(body);
        return _createdUser();
      },
    );

    final result = await provider.signUp(
      termsAccepted: true,
      email: 'laura@example.com',
      password: 'Password1!',
      firstName: 'Laura',
      lastName: 'Douglas',
      username: 'Movie_User.99',
      referralCode: ' flxabc123 ',
    );

    expect(result, isTrue);
    expect(receivedBody?['referralCode'], 'FLXABC123');
  });

  test('unavailable username surfaces backend validation code', () async {
    final provider = AuthProvider(
      authService,
      MovieService(),
      prefetchAfterAuth: false,
      profileCreator: (_) => throw const ApiException(
        statusCode: 400,
        message:
            'That username isn’t available. Please choose a different one.',
        code: 'USERNAME_NOT_AVAILABLE',
      ),
    );

    expect(await signUp(provider), isFalse);
    expect(provider.errorCode, 'USERNAME_NOT_AVAILABLE');
    expect(provider.errorMessage, contains('isn’t available'));
  });

  test('Firebase failure does not call backend profile creation', () async {
    authService.signupError =
        FirebaseAuthException(code: 'email-already-in-use');
    var backendCalls = 0;
    final provider = AuthProvider(
      authService,
      MovieService(),
      prefetchAfterAuth: false,
      profileCreator: (_) async {
        backendCalls++;
        return _createdUser();
      },
    );

    expect(await signUp(provider), isFalse);
    expect(backendCalls, 0);
    expect(provider.errorMessage, contains('already exists'));
  });

  test('backend failure keeps Firebase user for a profile-only retry',
      () async {
    var backendCalls = 0;
    final provider = AuthProvider(
      authService,
      MovieService(),
      prefetchAfterAuth: false,
      profileCreator: (_) async {
        backendCalls++;
        if (backendCalls == 1) {
          throw const ApiException(
            statusCode: 503,
            message: 'Temporarily unavailable',
          );
        }
        return _createdUser();
      },
    );

    expect(await signUp(provider), isFalse);
    expect(authService.signupCalls, 1);
    expect(authService.hasUser, isTrue);
    expect(provider.termsVerified, isFalse,
        reason: 'failed profile creation cannot confirm saved consent');

    expect(await signUp(provider), isTrue);
    expect(authService.signupCalls, 1,
        reason: 'retry must not create another Firebase account');
    expect(backendCalls, 2);
  });

  test('401 refreshes Firebase token and retries profile once', () async {
    var backendCalls = 0;
    final seenTokens = <String?>[];
    final provider = AuthProvider(
      authService,
      MovieService(),
      prefetchAfterAuth: false,
      profileCreator: (_) async {
        backendCalls++;
        seenTokens.add(ApiClient.getToken());
        if (backendCalls == 1) {
          throw const ApiException(statusCode: 401, message: 'Unauthorized');
        }
        return _createdUser();
      },
    );

    expect(await signUp(provider), isTrue);
    expect(authService.refreshCalls, 1);
    expect(seenTokens, ['fresh-signup-token', 'refreshed-token']);
  });

  test('duplicate concurrent submission is ignored', () async {
    final completer = Completer<model.User>();
    final provider = AuthProvider(
      authService,
      MovieService(),
      prefetchAfterAuth: false,
      profileCreator: (_) => completer.future,
    );

    final first = signUp(provider);
    await Future<void>.delayed(Duration.zero);
    final duplicate = await signUp(provider);
    expect(duplicate, isFalse);
    expect(authService.signupCalls, 1);

    completer.complete(_createdUser());
    expect(await first, isTrue);
  });

  test(
      'avatar signup creates profile before assigning avatar and retries assignment only',
      () async {
    final order = <String>[];
    var avatarCalls = 0;
    final provider = AuthProvider(
      authService,
      MovieService(),
      prefetchAfterAuth: false,
      profileCreator: (_) async {
        order.add('profile');
        return _createdUser();
      },
      avatarSelector: (id) async {
        order.add('avatar');
        avatarCalls++;
        if (avatarCalls == 1) throw Exception('temporary');
        return const ProfileAvatar(
          id: 1,
          key: 'spaniel',
          displayName: 'Spaniel',
          storagePath: 'avatars/spaniel.png',
        );
      },
    );

    expect(
      await provider.beginAvatarSignUp(
        termsAccepted: true,
        email: 'laura@example.com',
        password: 'Password1!',
        firstName: 'Laura',
        lastName: 'Douglas',
        username: 'Movie_User.99',
      ),
      isTrue,
    );
    expect(order, ['profile'],
        reason: 'the backend user must exist before avatar/setup screens');
    expect(provider.dbUser?.id, 'profile-1');
    final authenticatedConsent = <bool>[];
    provider.addListener(() {
      if (provider.status == AuthStatus.authenticated) {
        authenticatedConsent.add(provider.termsVerified);
      }
    });
    expect(await provider.completeAvatarSignUp(1), isFalse);
    expect(await provider.completeAvatarSignUp(1), isTrue);
    expect(order, ['profile', 'avatar', 'avatar']);
    expect(authService.signupCalls, 1);
    expect(provider.dbUser?.avatar?.id, 1);
    expect(provider.termsVerified, isTrue);
    expect(authenticatedConsent, isNotEmpty);
    expect(authenticatedConsent, everyElement(isTrue),
        reason: 'no authenticated notification may briefly route to terms');
  });

  test('avatar signup does not continue when backend rejects the user',
      () async {
    var avatarCalls = 0;
    final provider = AuthProvider(
      authService,
      MovieService(),
      prefetchAfterAuth: false,
      profileCreator: (_) => throw const ApiException(
        statusCode: 409,
        message: 'A user with this email already exists.',
        code: 'USER_ALREADY_EXISTS',
      ),
      avatarSelector: (_) async {
        avatarCalls++;
        return const ProfileAvatar(
          id: 1,
          key: 'spaniel',
          displayName: 'Spaniel',
          storagePath: 'avatars/spaniel.png',
        );
      },
    );

    expect(
      await provider.beginAvatarSignUp(
        termsAccepted: true,
        email: 'laura@example.com',
        password: 'Password1!',
        firstName: 'Laura',
        lastName: 'Douglas',
        username: 'Movie_User.99',
      ),
      isFalse,
    );
    expect(provider.dbUser, isNull);
    expect(provider.errorCode, 'USER_ALREADY_EXISTS');
    expect(avatarCalls, 0);
  });
}
