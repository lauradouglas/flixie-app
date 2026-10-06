import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/auth/auth_service.dart';
import 'package:flixie_app/core/auth/social_auth_provider.dart';
import 'package:flixie_app/features/authentication/presentation/pages/social_auth_buttons.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/models/profile_avatar.dart';
import 'package:flixie_app/models/user.dart' as model;

class Identity extends Fake implements fb.User {
  Identity(this.providers);
  final List<String> providers;
  @override
  String get uid => 'fixture-social-user';
  @override
  String get email => 'alien-fan@example.invalid';
  @override
  String get displayName => 'Alien Fan';
  @override
  List<fb.UserInfo> get providerData =>
      providers.map((id) => Info(id)).toList();
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async =>
      'fixture-token';
}

class Info extends Fake implements fb.UserInfo {
  Info(this.providerId);
  @override
  final String providerId;
}

class Credential extends Fake implements fb.UserCredential {}

class SocialService extends Fake implements AuthService {
  final changes = StreamController<fb.User?>.broadcast(sync: true);
  Identity? user;
  Object? failure;
  int signIns = 0;
  int links = 0;
  @override
  Stream<fb.User?> get authStateChanges => changes.stream;
  @override
  fb.User? get currentUser => user;
  @override
  Future<String> refreshIdToken() async => 'fixture-token';
  @override
  Future<fb.UserCredential> signInWithSocialProvider(
      SocialAuthProvider provider) async {
    signIns++;
    if (failure != null) throw failure!;
    user = Identity([provider.id]);
    changes.add(user);
    return Credential();
  }

  @override
  Future<void> linkSocialProvider(SocialAuthProvider provider) async {
    links++;
    if (failure != null) throw failure!;
    user!.providers.add(provider.id);
  }

  @override
  Future<void> signOut() async {
    user = null;
    changes.add(null);
  }
}

model.User profile() => model.User(
      id: 'fixture-db-user',
      externalId: 'fixture-social-user',
      username: 'alien_fan',
      email: 'alien-fan@example.invalid',
      iconColorId: 1,
      completedSetup: false,
      darkMode: true,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SocialService service;
  late AuthProvider auth;
  model.User? savedProfile;
  Map<String, dynamic>? submitted;
  Object? profileError;
  int creates = 0;

  void setup() {
    service = SocialService();
    savedProfile = null;
    submitted = null;
    profileError = null;
    creates = 0;
    auth = AuthProvider(
      service,
      MovieService(),
      prefetchAfterAuth: false,
      profileLoader: (_) async {
        if (profileError != null) throw profileError!;
        return savedProfile;
      },
      termsStatusLoader: () async => true,
      profileCreator: (body) async {
        creates++;
        submitted = body;
        return savedProfile = profile();
      },
      avatarSelector: (id) async => ProfileAvatar(
          id: id,
          key: 'alien',
          displayName: 'Alien',
          storagePath: 'fixture.png'),
    );
    addTearDown(() async {
      auth.dispose();
      await service.changes.close();
      ApiClient.setToken(null);
    });
  }

  for (final provider in SocialAuthProvider.values) {
    testWidgets(
        '${provider.label} new user completes profile without a password',
        (tester) async {
      setup();
      expect(await auth.signInWithSocialProvider(provider), isTrue);
      await tester.pump();
      expect(auth.needsSocialProfile, isTrue);
      expect(auth.status, AuthStatus.unauthenticated);
      expect(
          await auth.beginAvatarSignUp(
              termsAccepted: true,
              email: 'untrusted@example.invalid',
              password: '',
              firstName: 'Alien Fan',
              lastName: '',
              username: 'alien_fan'),
          isTrue);
      expect(submitted!['email'], 'alien-fan@example.invalid');
      expect(submitted!['termsAccepted'], isTrue);
      expect(creates, 1);
      service.changes.add(service.user);
      await tester.pump();
      expect(auth.needsSocialProfile, isTrue);
      expect(await auth.completeAvatarSignUp(1), isTrue);
      await tester.pump();
      expect(auth.needsSocialProfile, isFalse);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.dbUser!.avatar!.id, 1);
    });

    testWidgets('${provider.label} existing user retains their Flixie profile',
        (tester) async {
      setup();
      savedProfile = profile();
      expect(await auth.signInWithSocialProvider(provider), isTrue);
      await tester.pump();
      expect(auth.dbUser!.id, 'fixture-db-user');
      expect(auth.needsSocialProfile, isFalse);
      expect(creates, 0);
    });
  }

  testWidgets('a profile outage does not create a replacement account',
      (tester) async {
    setup();
    profileError = const ApiException(statusCode: 503, message: 'Offline');
    expect(await auth.signInWithSocialProvider(SocialAuthProvider.google),
        isFalse);
    await tester.pump();
    expect(auth.needsSocialProfile, isFalse);
    expect(auth.recoveryError, isNotNull);
    expect(creates, 0);
    await auth.signOut();
    await tester.pump();
  });

  testWidgets('restored social identity with 404 resumes signup',
      (tester) async {
    setup();
    profileError = const ApiException(statusCode: 404, message: 'Missing');
    service.user = Identity(['apple.com']);
    service.changes.add(service.user);
    await tester.pump();
    expect(auth.needsSocialProfile, isTrue);
    expect(auth.recoveryError, isNull);
  });

  testWidgets('cancelling native sign-in is quiet and restores controls',
      (tester) async {
    setup();
    service.failure = fb.FirebaseAuthException(code: 'sign-in-cancelled');
    expect(await auth.signInWithSocialProvider(SocialAuthProvider.google),
        isFalse);
    expect(auth.errorMessage, isNull);
    expect(auth.isLoading, isFalse);
    await auth.signOut();
    await tester.pump();
  });

  testWidgets('connecting a provider preserves the UID and profile',
      (tester) async {
    setup();
    savedProfile = profile();
    await auth.signInWithSocialProvider(SocialAuthProvider.apple);
    service.user!.providers
      ..clear()
      ..add('password');
    expect(await auth.connectSocialProvider(SocialAuthProvider.google), isTrue);
    await tester.pump();
    expect(auth.firebaseUser!.uid, 'fixture-social-user');
    expect(auth.dbUser!.id, 'fixture-db-user');
    expect(auth.isProviderConnected(SocialAuthProvider.google), isTrue);
    expect(service.signIns, 1);
    expect(service.links, 1);
  });

  testWidgets(
      'email conflict while linking keeps the current account and explains the failed connection',
      (tester) async {
    setup();
    savedProfile = profile();
    await auth.signInWithSocialProvider(SocialAuthProvider.google);
    service.user!.providers
      ..clear()
      ..add('password');
    service.failure = fb.FirebaseAuthException(code: 'email-already-in-use');
    expect(await auth.connectSocialProvider(SocialAuthProvider.apple), isFalse);
    expect(auth.errorCode, 'email-already-in-use');
    expect(auth.errorMessage, contains('could not connect Apple'));
    expect(auth.dbUser!.id, 'fixture-db-user');
    expect(auth.firebaseUser!.uid, 'fixture-social-user');
    expect(auth.isProviderConnected(SocialAuthProvider.apple), isFalse);
    expect(service.signIns, 1);
    await tester.pump();
  });

  testWidgets('credential conflict never switches the current account',
      (tester) async {
    setup();
    savedProfile = profile();
    await auth.signInWithSocialProvider(SocialAuthProvider.apple);
    service.user!.providers
      ..clear()
      ..add('password');
    service.failure =
        fb.FirebaseAuthException(code: 'credential-already-in-use');
    expect(
        await auth.connectSocialProvider(SocialAuthProvider.google), isFalse);
    expect(auth.dbUser!.id, 'fixture-db-user');
    expect(auth.errorMessage, contains('another Flixie account'));
    expect(auth.isProviderConnected(SocialAuthProvider.google), isFalse);
    await tester.pump();
  });

  for (final connected in SocialAuthProvider.values) {
    testWidgets(
        '${connected.label} connection blocks linking the other provider',
        (tester) async {
      setup();
      savedProfile = profile();
      await auth.signInWithSocialProvider(connected);
      final other = SocialAuthProvider.values.firstWhere((p) => p != connected);
      expect(await auth.connectSocialProvider(other), isFalse);
      expect(service.links, 0);
      expect(auth.isProviderConnected(connected), isTrue);
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: const MaterialApp(
              home: Scaffold(body: SocialAuthButtons(connect: true)))));
      final button = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Connect with ${other.label}'));
      expect(button.onPressed, isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  testWidgets('new social user cannot bypass consent and can abandon signup',
      (tester) async {
    setup();
    await auth.signInWithSocialProvider(SocialAuthProvider.google);
    expect(
        await auth.beginAvatarSignUp(
            termsAccepted: false,
            email: '',
            password: '',
            firstName: 'Alien Fan',
            lastName: '',
            username: 'alien_fan'),
        isFalse);
    expect(creates, 0);
    await auth.signOut();
    await tester.pump();
    expect(auth.needsSocialProfile, isFalse);
    expect(auth.firebaseUser, isNull);
  });

  testWidgets('settings connect button becomes a connected state after tapping',
      (tester) async {
    setup();
    savedProfile = profile();
    await auth.signInWithSocialProvider(SocialAuthProvider.apple);
    service.user!.providers
      ..clear()
      ..add('password');
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: const MaterialApp(
          home: Scaffold(body: SocialAuthButtons(connect: true))),
    ));
    await tester.tap(find.text('Connect with Google'));
    await tester.pumpAndSettle();
    expect(find.text('Google connected'), findsOneWidget);
    expect(find.text('Connect with Google'), findsNothing);
    expect(service.links, 1);
    expect(tester.takeException(), isNull);
  });
}
