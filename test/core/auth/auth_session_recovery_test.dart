import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_session_recovery.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

class _Identity implements fb.User {
  _Identity(this.uid);
  @override
  final String uid;
  int tokens = 0;
  Future<String?> Function()? token;
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) {
    expect(forceRefresh, isFalse);
    tokens++;
    return token?.call() ?? Future.value('token-$uid');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

User _profile(String id) => User(
    id: id,
    externalId: id,
    username: id,
    email: '$id@example.invalid',
    iconColorId: 0,
    completedSetup: true,
    darkMode: true);

class _Fixture {
  _Fixture() {
    recovery = AuthSessionRecovery(
      user: () => identity,
      loadProfile: (id) {
        loads++;
        return load?.call(id) ?? Future.value(_profile(id));
      },
      applyProfile: (value) => profile = value,
      onExpired: () async {
        expired++;
        recovery.reset();
      },
      onChanged: () => changes++,
      canResume: () => true,
      onResumeSuccess: () => resumed++,
      onThrottledResume: () => throttled++,
      onRetry: () async {
        retries++;
        await retry?.call();
      },
    );
  }
  late final AuthSessionRecovery recovery;
  _Identity identity = _Identity('one');
  User? profile;
  Future<User?> Function(String)? load;
  Future<void> Function()? retry;
  int loads = 0,
      resumed = 0,
      throttled = 0,
      expired = 0,
      retries = 0,
      changes = 0;
}

void main() {
  tearDown(() => ApiClient.setToken(null));

  testWidgets('screen profile refresh and overlapping resumes share one read',
      (tester) async {
    final f = _Fixture();
    addTearDown(f.recovery.dispose);
    final held = Completer<User?>();
    f.load = (_) => held.future;
    final screen = f.recovery.refreshProfile();
    final resume = f.recovery.resume();
    final overlapping = f.recovery.resume(force: true);
    await tester.pump();
    expect(f.loads, 1);
    expect(f.identity.tokens, 1);
    held.complete(_profile('one'));
    await tester.pump();
    expect(await screen, isTrue);
    await Future.wait([resume, overlapping]);
    expect(f.resumed, 1);
    expect(f.profile?.id, 'one');
    await f.recovery.resume();
    expect(f.loads, 1);
    expect(f.throttled, 1);
    await f.recovery.resume(force: true);
    expect(f.loads, 2);
    expect(f.resumed, 2);
  });

  testWidgets('old resume completion cannot clear the next account flight',
      (tester) async {
    final f = _Fixture();
    addTearDown(f.recovery.dispose);
    final oldToken = Completer<String?>();
    f.identity.token = () => oldToken.future;
    final old = f.recovery.resume();
    await tester.pump();
    f.recovery.reset();
    f.identity = _Identity('two');
    final nextProfile = Completer<User?>();
    f.load = (_) => nextProfile.future;
    final next = f.recovery.resume();
    await tester.pump();
    oldToken.complete('obsolete');
    await tester.pump();
    await old;
    final overlap = f.recovery.resume(force: true);
    await tester.pump();
    expect(f.identity.tokens, 1);
    expect(f.loads, 1);
    expect(ApiClient.getToken(), 'token-two');
    nextProfile.complete(_profile('two'));
    await tester.pump();
    await Future.wait([next, overlap]);
    expect(f.profile?.id, 'two');
    expect(f.resumed, 1);
  });

  testWidgets(
      'old profile completion cannot apply or clear a new profile flight',
      (tester) async {
    final f = _Fixture();
    addTearDown(f.recovery.dispose);
    final oldProfile = Completer<User?>();
    final nextProfile = Completer<User?>();
    f.load = (id) => id == 'one' ? oldProfile.future : nextProfile.future;
    final old = f.recovery.refreshProfile();
    f.recovery.reset();
    f.identity = _Identity('two');
    final next = f.recovery.refreshProfile();
    oldProfile.complete(_profile('one'));
    await tester.pump();
    expect(await old, isFalse);
    final overlap = f.recovery.refreshProfile();
    expect(f.loads, 2);
    expect(f.profile, isNull);
    nextProfile.complete(_profile('two'));
    await tester.pump();
    expect(await next, isTrue);
    expect(await overlap, isTrue);
    expect(f.profile?.id, 'two');
  });

  testWidgets(
      'automatic retry stops after 5, 15, 30 seconds; manual retry resets',
      (tester) async {
    final f = _Fixture();
    addTearDown(f.recovery.dispose);
    f.retry = () async => f.recovery.scheduleRetry();
    f.recovery.scheduleRetry();
    f.recovery.scheduleRetry();
    for (final seconds in [5, 15, 30]) {
      final before = f.retries;
      await tester.pump(Duration(seconds: seconds - 1));
      expect(f.retries, before);
      await tester.pump(const Duration(seconds: 1));
      expect(f.retries, before + 1);
    }
    await tester.pump(const Duration(minutes: 1));
    expect(f.retries, 3);
    await f.recovery.retry();
    expect(f.retries, 4);
    await tester.pump(const Duration(seconds: 5));
    expect(f.retries, 5);
    f.recovery.dispose();
  });

  testWidgets('background, account reset and disposal cancel scheduled retry',
      (tester) async {
    final f = _Fixture();
    f.recovery.scheduleRetry();
    f.recovery.setForeground(false);
    f.recovery.scheduleRetry();
    await tester.pump(const Duration(seconds: 60));
    expect(f.retries, 0);
    f.recovery.setForeground(true);
    f.recovery.scheduleRetry();
    await tester.pump(const Duration(seconds: 5));
    expect(f.retries, 1);
    f.recovery.scheduleRetry();
    f.recovery.reset();
    await tester.pump(const Duration(seconds: 60));
    expect(f.retries, 1);
    f.recovery.scheduleRetry();
    f.recovery.dispose();
    await tester.pump(const Duration(seconds: 60));
    await f.recovery.retry();
    expect(f.retries, 1);
  });

  testWidgets(
      'profile timeout keeps saved content and late results cannot apply',
      (tester) async {
    final f = _Fixture()..profile = _profile('saved');
    addTearDown(f.recovery.dispose);
    final held = Completer<User?>();
    f.load = (_) => held.future;
    final refresh = f.recovery.refreshProfile();
    await tester.pump(const Duration(seconds: 10));
    expect(await refresh, isFalse);
    expect(f.profile?.id, 'saved');
    expect(f.recovery.error, contains('saved content'));
    held.complete(_profile('late'));
    await tester.pump();
    expect(f.profile?.id, 'saved');
    f.load = (_) async => _profile('recovered');
    expect(await f.recovery.refreshProfile(), isTrue);
    expect(f.recovery.error, isNull);
  });

  for (final code in [
    'user-disabled',
    'user-not-found',
    'user-token-expired',
    'invalid-user-token'
  ]) {
    testWidgets('expired profile $code ends recovery without retry',
        (tester) async {
      final f = _Fixture();
      addTearDown(f.recovery.dispose);
      f.load = (_) async => throw fb.FirebaseAuthException(code: code);
      await f.recovery.resume();
      await tester.pump(const Duration(seconds: 60));
      expect(f.expired, 1);
      expect(f.retries, 0);
      expect(f.resumed, 0);
    });
  }

  testWidgets('pending token cannot overwrite a newer API refresh',
      (tester) async {
    final f = _Fixture();
    addTearDown(f.recovery.dispose);
    final token = Completer<String?>();
    f.identity.token = () => token.future;
    final refresh = f.recovery.resume();
    ApiClient.setToken('newer-401-refresh');
    token.complete('old-sdk-token');
    await tester.pump();
    await refresh;
    expect(ApiClient.getToken(), 'newer-401-refresh');
    expect(f.resumed, 1);
  });

  testWidgets(
      'disposal rejects pending profile effects and bootstrap notification',
      (tester) async {
    final f = _Fixture();
    f.recovery.startBootstrap(() => true);
    final held = Completer<User?>();
    f.load = (_) => held.future;
    final refresh = f.recovery.refreshProfile();
    f.recovery.dispose();
    held.complete(_profile('late'));
    await tester.pump(const Duration(seconds: 10));
    expect(await refresh, isFalse);
    expect(f.profile, isNull);
    expect(f.changes, 0);
  });
}
