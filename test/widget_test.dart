import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/providers/auth_provider.dart';
import 'package:flixie_app/services/auth_service.dart';
import 'package:flixie_app/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Minimal stubs so tests run without a real Firebase project
// ---------------------------------------------------------------------------

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'test-uid';
  @override
  String? get displayName => 'Test User';
  @override
  String? get email => 'test@example.com';
  @override
  String? get photoURL => null;
}

class _FakeAuthService extends Fake implements AuthService {
  final _controller = StreamController<User?>.broadcast();

  @override
  Stream<User?> get authStateChanges => _controller.stream;

  @override
  User? get currentUser => null;

  void emitUser(User? user) => _controller.add(user);

  @override
  Future<User?> getUserProfile() async => null;

  void close() => _controller.close();
}

void main() {
  group('FlixieColors', () {
    test('primary color has correct value', () {
      expect(FlixieColors.primary, const Color(0xFF947AF1));
    });

    test('secondary color has correct value', () {
      expect(FlixieColors.secondary, const Color(0xFF08A391));
    });

    test('background color has correct value', () {
      expect(FlixieColors.background, const Color(0xFF172B4D));
    });

    test('danger color has correct value', () {
      expect(FlixieColors.danger, const Color(0xFFE57373));
    });

    test('warning color has correct value', () {
      expect(FlixieColors.warning, const Color(0xFFFFD166));
    });
  });

  group('AppTheme', () {
    test('darkTheme is not null', () {
      expect(AppTheme.darkTheme, isNotNull);
    });

    test('darkTheme uses dark brightness', () {
      expect(AppTheme.darkTheme.brightness, Brightness.dark);
    });

    test('darkTheme primary color matches FlixieColors.primary', () {
      expect(
        AppTheme.darkTheme.colorScheme.primary,
        FlixieColors.primary,
      );
    });

    test('darkTheme scaffold background matches FlixieColors.background', () {
      expect(
        AppTheme.darkTheme.scaffoldBackgroundColor,
        FlixieColors.background,
      );
    });
  });

  group('AuthProvider', () {
    late _FakeAuthService fakeAuth;
    late AuthProvider authProvider;

    setUp(() {
      fakeAuth = _FakeAuthService();
      authProvider = AuthProvider(fakeAuth);
    });

    tearDown(() => fakeAuth.close());

    test('initial status is unknown', () {
      expect(authProvider.status, AuthStatus.unknown);
    });

    test('status becomes authenticated when user emitted', () async {
      fakeAuth.emitUser(_FakeUser());
      await Future<void>.delayed(Duration.zero);
      expect(authProvider.status, AuthStatus.authenticated);
      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.user?.email, 'test@example.com');
    });

    test('status becomes unauthenticated when null emitted', () async {
      fakeAuth.emitUser(_FakeUser());
      await Future<void>.delayed(Duration.zero);
      fakeAuth.emitUser(null);
      await Future<void>.delayed(Duration.zero);
      expect(authProvider.status, AuthStatus.unauthenticated);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.user, isNull);
    });
  });

  group('AuthService.messageFromAuthException', () {
    FirebaseAuthException makeException(String code) =>
        FirebaseAuthException(code: code);

    test('user-not-found returns correct message', () {
      expect(
        AuthService.messageFromAuthException(makeException('user-not-found')),
        'No account found for that email.',
      );
    });

    test('wrong-password returns correct message', () {
      expect(
        AuthService.messageFromAuthException(makeException('wrong-password')),
        'Incorrect password.',
      );
    });

    test('email-already-in-use returns correct message', () {
      expect(
        AuthService.messageFromAuthException(
            makeException('email-already-in-use')),
        'An account already exists for that email.',
      );
    });

    test('weak-password returns correct message', () {
      expect(
        AuthService.messageFromAuthException(makeException('weak-password')),
        'Password must be at least 6 characters.',
      );
    });

    test('unknown code returns message field', () {
      expect(
        AuthService.messageFromAuthException(
          FirebaseAuthException(code: 'other', message: 'Some error'),
        ),
        'Some error',
      );
    });
  });
}

