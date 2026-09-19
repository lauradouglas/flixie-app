import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/auth/auth_service.dart';
import 'package:flixie_app/core/auth/auth_prefetch_coordinator.dart';
import 'package:flixie_app/core/auth/auth_prefetch_snapshot.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/movie_short.dart';

class Identity implements fb.User {
  Identity(this.uid);
  @override
  final String uid;
  @override
  String get email => '$uid@example.invalid';
  final calls = <bool>[];
  Future<String?> Function(bool)? token;
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) {
    calls.add(forceRefresh);
    return token?.call(forceRefresh) ?? Future.value('token-$uid');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class Auth extends AuthService {
  // Avoid constructing Firebase in a fixture.
  Auth._() : super(firebaseAuth: Firebase());
  final changes = StreamController<fb.User?>.broadcast(sync: true);
  fb.User? user;
  @override
  Stream<fb.User?> get authStateChanges => changes.stream;
  @override
  fb.User? get currentUser => user;
  void emit(fb.User? value) {
    user = value;
    changes.add(value);
  }

  @override
  Future<void> signOut() async => emit(null);
  @override
  Future<fb.UserCredential> signIn(String email, String password) async {
    emit(user);
    return Credential();
  }
}

class Firebase implements fb.FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class Credential implements fb.UserCredential {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class Prefetch implements AuthPrefetchCoordinator {
  int calls = 0;
  Future<AuthPrefetchSnapshot> Function(String)? load;
  @override
  Future<AuthPrefetchSnapshot> prefetch(String userId,
      {String region = 'GB',
      Iterable<int> watchlistMovieIds = const []}) async {
    calls++;
    if (load != null) return load!(userId);
    return const AuthPrefetchSnapshot();
  }

  @override
  Future<int?> fetchUnreadCount(String userId) async => 0;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

User profile(String id) => User(
    id: id,
    externalId: id,
    username: id,
    email: '$id@example.invalid',
    iconColorId: 0,
    completedSetup: true,
    darkMode: true);
void main() {
  testWidgets('idle logout schedules navigation without a user gesture',
      (tester) async {
    final auth = Auth._();
    final provider = AuthProvider(auth, MovieService(),
        prefetchAfterAuth: false,
        profileLoader: (_) async => profile('one'),
        termsStatusLoader: () async => true);
    addTearDown(() {
      provider.dispose();
      auth.changes.close();
    });
    auth.emit(Identity('one'));
    await tester.pumpAndSettle();
    expect(provider.status, AuthStatus.authenticated);
    expect(tester.binding.hasScheduledFrame, isFalse);

    final routedStatuses = <AuthStatus>[];
    provider.authStatusListenable.addListener(() {
      routedStatuses.add(provider.status);
    });
    await provider.signOut();
    expect(provider.status, AuthStatus.unauthenticated);
    expect(provider.dbUser, isNull);
    expect(provider.termsVerified, isFalse);
    expect(tester.binding.hasScheduledFrame, isTrue,
        reason: 'logout must request its own frame on an idle screen');
    await tester.pumpAndSettle();
    expect(routedStatuses, contains(AuthStatus.unauthenticated));
  });

  for (final accepted in [true, false]) {
    testWidgets('login resolves terms before routing: accepted=$accepted',
        (tester) async {
      final auth = Auth._();
      final terms = Completer<bool>();
      final provider = AuthProvider(auth, MovieService(),
          prefetchAfterAuth: false,
          profileLoader: (_) async => profile('one'),
          termsStatusLoader: () => terms.future);
      addTearDown(() {
        provider.dispose();
        auth.changes.close();
      });
      auth.emit(Identity('one'));
      await tester.pump();
      expect(provider.dbUser, isNotNull);
      expect(provider.status, AuthStatus.unknown);
      terms.complete(accepted);
      await tester.pump();
      expect(provider.status, AuthStatus.authenticated);
      expect(provider.termsVerified, accepted);
    });
  }

  testWidgets('sign-in/restoration share profile work and reuse a valid token',
      (tester) async {
    final auth = Auth._();
    final identity = Identity('one');
    auth.user = identity;
    var profiles = 0;
    final held = Completer<User?>();
    final prefetch = Prefetch();
    final provider = AuthProvider(auth, MovieService(),
        prefetchAfterAuth: false,
        prefetchCoordinator: prefetch, profileLoader: (_) {
      profiles++;
      return held.future;
    });
    addTearDown(() {
      provider.dispose();
      auth.changes.close();
    });
    final signingIn = provider.signIn('one@example.invalid', 'password');
    await tester.pump();
    expect(identity.calls, [false]);
    expect(profiles, 1);
    expect(provider.status, AuthStatus.unknown);
    held.complete(profile('one'));
    await tester.pump();
    await signingIn;
    expect(provider.status, AuthStatus.authenticated);
    auth.emit(identity);
    await tester.pump();
    expect(profiles, 1);
    expect(identity.calls, [false]);
  });
  testWidgets(
      'hung resume is bounded, keeps data, retries offline failure and recovers',
      (tester) async {
    final auth = Auth._();
    final identity = Identity('one');
    final prefetch = Prefetch();
    var failProfile = false;
    var profiles = 0;
    final provider = AuthProvider(auth, MovieService(),
        prefetchAfterAuth: false,
        prefetchCoordinator: prefetch, profileLoader: (_) async {
      profiles++;
      if (failProfile) throw StateError('offline');
      return profile('one');
    });
    addTearDown(() {
      provider.dispose();
      auth.changes.close();
    });
    auth.emit(identity);
    await tester.pump();
    final held = Completer<String?>();
    identity.token = (_) => held.future;
    provider.didChangeAppLifecycleState(AppLifecycleState.paused);
    provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
    final overlapping = provider.handleAppResumed();
    await tester.pump();
    expect(identity.calls.length, 2);
    await tester.pump(const Duration(seconds: 8));
    await overlapping;
    expect(provider.recoveryError, isNotNull);
    expect(provider.dbUser?.id, 'one');
    expect(provider.status, AuthStatus.authenticated);
    identity.token = (_) async => 'reconnected';
    failProfile = true;
    await provider.handleAppResumed();
    expect(provider.recoveryError, isNotNull);
    failProfile = false;
    await tester.pump(const Duration(seconds: 5));
    expect(provider.recoveryError, isNull);
    expect(ApiClient.getToken(), 'reconnected');
    final count = profiles;
    await provider.handleAppResumed();
    expect(profiles, count);
    held.complete('late-token');
    await tester.pump();
    expect(ApiClient.getToken(), 'reconnected');
    expect(prefetch.calls, 0, reason: 'resume does not restart broad prefetch');
    provider.didChangeAppLifecycleState(AppLifecycleState.paused);
  });
  testWidgets(
      'temporary startup failure remains recoverable and scheduled retry works',
      (tester) async {
    final auth = Auth._();
    final identity = Identity('one');
    var fail = true;
    final provider = AuthProvider(auth, MovieService(),
        prefetchAfterAuth: false, profileLoader: (_) async {
      if (fail) throw StateError('offline');
      return profile('one');
    });
    addTearDown(() {
      provider.dispose();
      auth.changes.close();
    });
    auth.emit(identity);
    await tester.pump();
    expect(provider.status, AuthStatus.unknown);
    expect(provider.recoveryError, isNotNull);
    fail = false;
    await tester.pump(const Duration(seconds: 5));
    expect(provider.status, AuthStatus.authenticated);
    expect(provider.recoveryError, isNull);
  });
  testWidgets(
      'account changes and logout invalidate pending token/profile loads',
      (tester) async {
    final auth = Auth._();
    final first = Identity('first');
    final second = Identity('second');
    final held = Completer<User?>();
    final provider = AuthProvider(auth, MovieService(),
        prefetchAfterAuth: false,
        profileLoader: (id) =>
            id == 'first' ? held.future : Future.value(profile(id)));
    addTearDown(() {
      provider.dispose();
      auth.changes.close();
    });
    auth.emit(first);
    await tester.pump();
    auth.emit(second);
    await tester.pump();
    expect(provider.dbUser?.id, 'second');
    held.complete(profile('first'));
    await tester.pump();
    expect(provider.dbUser?.id, 'second');
    final token = Completer<String?>();
    second.token = (_) => token.future;
    final resume = provider.handleAppResumed();
    await tester.pump();
    await provider.signOut();
    token.complete('obsolete');
    await tester.pump();
    await resume;
    expect(provider.status, AuthStatus.unauthenticated);
    expect(provider.dbUser, isNull);
    expect(ApiClient.getToken(), isNull);
  });

  testWidgets(
      'known invalid Firebase session signs out instead of retrying forever',
      (tester) async {
    final auth = Auth._();
    final identity = Identity('invalid');
    final provider = AuthProvider(auth, MovieService(),
        prefetchAfterAuth: false, profileLoader: (id) async => profile(id));
    auth.emit(identity);
    await tester.pump();
    identity.token =
        (_) async => throw fb.FirebaseAuthException(code: 'user-disabled');
    await provider.handleAppResumed();
    expect(provider.status, AuthStatus.unauthenticated);
    expect(ApiClient.getToken(), isNull);
    provider.dispose();
    await auth.changes.close();
    await tester.pump();
  });
  testWidgets(
      'restored-session token and profile phases match controlled baseline',
      (tester) async {
    // Original restored-session token/profile sequence, with a valid cached
    // token available. Times are virtual mock delays, not Flutter performance.
    final baselineIdentity = Identity('baseline');
    baselineIdentity.token = (force) =>
        Future.delayed(Duration(milliseconds: force ? 300 : 10), () => 'token');
    var beforeReady = false;
    final before = () async {
      await baselineIdentity
          .getIdToken(true)
          .timeout(const Duration(seconds: 8));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      beforeReady = true;
    }();
    final auth = Auth._();
    final identity = Identity('measured');
    identity.token = baselineIdentity.token;
    var profileCalls = 0;
    final provider = AuthProvider(auth, MovieService(),
        prefetchAfterAuth: false, profileLoader: (id) async {
      profileCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return profile(id);
    });
    auth.emit(identity);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    expect(profileCalls, 1);
    await tester.pump(const Duration(milliseconds: 200));
    expect(provider.status, AuthStatus.authenticated);
    expect(beforeReady, false);
    await tester.pump(const Duration(milliseconds: 90));
    await tester.pump(const Duration(milliseconds: 200));
    await before;
    expect(beforeReady, true);
    expect(identity.calls, [false]);
    expect(baselineIdentity.calls, [true]);
    provider.dispose();
    await auth.changes.close();
    await tester.pump();
  });
  testWidgets('late prefetch cannot restore another account’s data',
      (tester) async {
    final auth = Auth._();
    final old = Completer<AuthPrefetchSnapshot>();
    final prefetch = Prefetch()
      ..load = (id) => id == 'A'
          ? old.future
          : Future.value(const AuthPrefetchSnapshot(
              trending: [MovieShort(id: 2, name: 'B')]));
    final provider = AuthProvider(auth, MovieService(),
        prefetchCoordinator: prefetch,
        profileLoader: (id) async => profile(id));
    auth.emit(Identity('A'));
    await tester.pump();
    auth.emit(Identity('B'));
    await tester.pump();
    expect(provider.cachedTrending?.single.id, 2);
    old.complete(
        const AuthPrefetchSnapshot(trending: [MovieShort(id: 1, name: 'A')]));
    await tester.pump();
    expect(provider.cachedTrending?.single.id, 2);
    expect(provider.isPrefetching, false);
    provider.dispose();
    await auth.changes.close();
    await tester.pump();
  });
  testWidgets('missing initial auth event reaches a retry state',
      (tester) async {
    final auth = Auth._();
    final provider =
        AuthProvider(auth, MovieService(), prefetchAfterAuth: false);
    await tester.pump(const Duration(seconds: 8));
    expect(provider.status, AuthStatus.unknown);
    expect(provider.recoveryError, isNotNull);
    provider.dispose();
    await auth.changes.close();
    await tester.pump();
  });
}
