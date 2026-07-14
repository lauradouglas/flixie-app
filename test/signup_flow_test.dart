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
        email: 'laura@example.com',
        password: 'Password1!',
        firstName: 'Laura',
        lastName: 'Douglas',
        username: 'Movie_User.99',
      );

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
  });

  test('username availability path URL-encodes the username', () {
    expect(
      UserService.usernameAvailabilityPath('Movie User/99'),
      '/users/Movie%20User%2F99/exists',
    );
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
}
