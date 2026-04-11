import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/group_watch_request.dart';
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

  // ---------------------------------------------------------------------------
  // WatchRequestStatus enum
  // ---------------------------------------------------------------------------

  group('WatchRequestStatus', () {
    test('fromString parses open', () {
      expect(WatchRequestStatus.fromString('open'), WatchRequestStatus.open);
    });

    test('fromString parses scheduled', () {
      expect(WatchRequestStatus.fromString('scheduled'),
          WatchRequestStatus.scheduled);
    });

    test('fromString parses completed', () {
      expect(WatchRequestStatus.fromString('completed'),
          WatchRequestStatus.completed);
    });

    test('fromString parses expired', () {
      expect(
          WatchRequestStatus.fromString('expired'), WatchRequestStatus.expired);
    });

    test('fromString parses cancelled', () {
      expect(WatchRequestStatus.fromString('cancelled'),
          WatchRequestStatus.cancelled);
    });

    test('fromString parses canceled (US spelling)', () {
      expect(WatchRequestStatus.fromString('canceled'),
          WatchRequestStatus.cancelled);
    });

    test('fromString returns open for unknown value', () {
      expect(WatchRequestStatus.fromString('unknown'), WatchRequestStatus.open);
    });

    test('fromString returns open for null', () {
      expect(WatchRequestStatus.fromString(null), WatchRequestStatus.open);
    });

    test('statusLabel for open is Open', () {
      expect(WatchRequestStatus.open.statusLabel, 'Open');
    });

    test('statusLabel for scheduled is Scheduled', () {
      expect(WatchRequestStatus.scheduled.statusLabel, 'Scheduled');
    });

    test('statusLabel for completed is Watched', () {
      expect(WatchRequestStatus.completed.statusLabel, 'Watched');
    });

    test('statusLabel for expired is Expired', () {
      expect(WatchRequestStatus.expired.statusLabel, 'Expired');
    });

    test('statusLabel for cancelled is Cancelled', () {
      expect(WatchRequestStatus.cancelled.statusLabel, 'Cancelled');
    });

    test('apiValue round-trips correctly', () {
      for (final s in WatchRequestStatus.values) {
        expect(WatchRequestStatus.fromString(s.apiValue), s);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // WatchRequestFilter enum
  // ---------------------------------------------------------------------------

  group('WatchRequestFilter', () {
    test('apiValue for active is active', () {
      expect(WatchRequestFilter.active.apiValue, 'active');
    });

    test('apiValue for needsResponse is needs_response', () {
      expect(WatchRequestFilter.needsResponse.apiValue, 'needs_response');
    });

    test('apiValue for completed is completed', () {
      expect(WatchRequestFilter.completed.apiValue, 'completed');
    });

    test('apiValue for byMe is by_me', () {
      expect(WatchRequestFilter.byMe.apiValue, 'by_me');
    });

    test('apiValue for all is all', () {
      expect(WatchRequestFilter.all.apiValue, 'all');
    });

    test('emptyMessage for active', () {
      expect(
          WatchRequestFilter.active.emptyMessage, 'No active watch requests');
    });

    test('emptyMessage for needsResponse', () {
      expect(WatchRequestFilter.needsResponse.emptyMessage,
          'No requests need your response');
    });

    test('emptyMessage for completed', () {
      expect(WatchRequestFilter.completed.emptyMessage,
          'No completed watches yet');
    });

    test('emptyMessage for byMe', () {
      expect(WatchRequestFilter.byMe.emptyMessage,
          "You haven't created any requests yet");
    });
  });

  // ---------------------------------------------------------------------------
  // WatchResponseDecision enum
  // ---------------------------------------------------------------------------

  group('WatchResponseDecision', () {
    test('fromString parses accepted', () {
      expect(WatchResponseDecision.fromString('accepted'),
          WatchResponseDecision.accepted);
    });

    test('fromString parses declined', () {
      expect(WatchResponseDecision.fromString('declined'),
          WatchResponseDecision.declined);
    });

    test('fromString parses maybe', () {
      expect(WatchResponseDecision.fromString('maybe'),
          WatchResponseDecision.maybe);
    });

    test('fromString returns maybe for unknown value', () {
      expect(WatchResponseDecision.fromString('unknown'),
          WatchResponseDecision.maybe);
    });

    test('apiValue for accepted is ACCEPTED', () {
      expect(WatchResponseDecision.accepted.apiValue, 'ACCEPTED');
    });

    test('apiValue for declined is DECLINED', () {
      expect(WatchResponseDecision.declined.apiValue, 'DECLINED');
    });

    test('apiValue for maybe is MAYBE', () {
      expect(WatchResponseDecision.maybe.apiValue, 'MAYBE');
    });
  });

  // ---------------------------------------------------------------------------
  // GroupWatchRequest helper getters
  // ---------------------------------------------------------------------------

  GroupWatchRequest makeRequest({
    WatchRequestStatus status = WatchRequestStatus.open,
    String? expiresAt,
  }) {
    return GroupWatchRequest(
      id: 'req-1',
      groupId: 'group-1',
      userId: 'user-1',
      status: status,
      expiresAt: expiresAt,
    );
  }

  group('GroupWatchRequest.isActive', () {
    test('open request is active', () {
      expect(makeRequest(status: WatchRequestStatus.open).isActive, isTrue);
    });

    test('scheduled request is active', () {
      expect(
          makeRequest(status: WatchRequestStatus.scheduled).isActive, isTrue);
    });

    test('completed request is not active', () {
      expect(
          makeRequest(status: WatchRequestStatus.completed).isActive, isFalse);
    });

    test('expired request is not active', () {
      expect(makeRequest(status: WatchRequestStatus.expired).isActive, isFalse);
    });

    test('cancelled request is not active', () {
      expect(
          makeRequest(status: WatchRequestStatus.cancelled).isActive, isFalse);
    });
  });

  group('GroupWatchRequest.isArchived', () {
    test('open request is not archived', () {
      expect(makeRequest(status: WatchRequestStatus.open).isArchived, isFalse);
    });

    test('completed request is archived', () {
      expect(
          makeRequest(status: WatchRequestStatus.completed).isArchived, isTrue);
    });

    test('expired request is archived', () {
      expect(
          makeRequest(status: WatchRequestStatus.expired).isArchived, isTrue);
    });

    test('cancelled request is archived', () {
      expect(
          makeRequest(status: WatchRequestStatus.cancelled).isArchived, isTrue);
    });
  });

  group('GroupWatchRequest.hasExpired', () {
    test('expired status returns true immediately', () {
      expect(
          makeRequest(status: WatchRequestStatus.expired).hasExpired, isTrue);
    });

    test('open with past expiresAt returns true', () {
      final pastDate =
          DateTime.now().subtract(const Duration(days: 1)).toIso8601String();
      expect(
          makeRequest(status: WatchRequestStatus.open, expiresAt: pastDate)
              .hasExpired,
          isTrue);
    });

    test('open with future expiresAt returns false', () {
      final futureDate =
          DateTime.now().add(const Duration(days: 7)).toIso8601String();
      expect(
          makeRequest(status: WatchRequestStatus.open, expiresAt: futureDate)
              .hasExpired,
          isFalse);
    });

    test('open without expiresAt returns false', () {
      expect(makeRequest(status: WatchRequestStatus.open).hasExpired, isFalse);
    });
  });

  group('GroupWatchRequest.canRespond', () {
    test('active open request can be responded to', () {
      expect(makeRequest(status: WatchRequestStatus.open).canRespond, isTrue);
    });

    test('expired-status request cannot be responded to', () {
      expect(
          makeRequest(status: WatchRequestStatus.expired).canRespond, isFalse);
    });

    test('completed request cannot be responded to', () {
      expect(makeRequest(status: WatchRequestStatus.completed).canRespond,
          isFalse);
    });
  });

  group('GroupWatchRequest.fromJson', () {
    test('parses status field from JSON', () {
      final json = {
        'id': 'r1',
        'groupId': 'g1',
        'userId': 'u1',
        'status': 'scheduled',
      };
      final req = GroupWatchRequest.fromJson(json);
      expect(req.status, WatchRequestStatus.scheduled);
    });

    test('defaults to open when status is missing', () {
      final json = {
        'id': 'r1',
        'groupId': 'g1',
        'userId': 'u1',
      };
      final req = GroupWatchRequest.fromJson(json);
      expect(req.status, WatchRequestStatus.open);
    });

    test('parses currentUserResponse from JSON', () {
      final json = {
        'id': 'r1',
        'groupId': 'g1',
        'userId': 'u1',
        'currentUserResponse': 'ACCEPTED',
      };
      final req = GroupWatchRequest.fromJson(json);
      expect(req.currentUserResponse, WatchResponseDecision.accepted);
    });

    test('currentUserResponse is null when absent', () {
      final json = {
        'id': 'r1',
        'groupId': 'g1',
        'userId': 'u1',
      };
      final req = GroupWatchRequest.fromJson(json);
      expect(req.currentUserResponse, isNull);
    });

    test('derives acceptedCount from responses array when not provided', () {
      final json = {
        'id': 'r1',
        'groupId': 'g1',
        'userId': 'u1',
        'responses': [
          {'memberId': 'm1', 'status': 'ACCEPTED'},
          {'memberId': 'm2', 'status': 'DECLINED'},
          {'memberId': 'm3', 'status': 'ACCEPTED'},
        ],
      };
      final req = GroupWatchRequest.fromJson(json);
      expect(req.acceptedCount, 2);
      expect(req.declinedCount, 1);
    });

    test('prefers API-provided counts over derived counts', () {
      final json = {
        'id': 'r1',
        'groupId': 'g1',
        'userId': 'u1',
        'acceptedCount': 5,
        'declinedCount': 2,
        'maybeCount': 1,
        'responses': [
          {'memberId': 'm1', 'status': 'ACCEPTED'},
        ],
      };
      final req = GroupWatchRequest.fromJson(json);
      expect(req.acceptedCount, 5);
      expect(req.declinedCount, 2);
      expect(req.maybeCount, 1);
    });

    test('maps conversationId as groupId', () {
      final json = {
        'id': 'r1',
        'conversationId': 'conv-1',
        'userId': 'u1',
      };
      final req = GroupWatchRequest.fromJson(json);
      expect(req.groupId, 'conv-1');
    });

    test('maps createdById as userId', () {
      final json = {
        'id': 'r1',
        'groupId': 'g1',
        'createdById': 'creator-1',
      };
      final req = GroupWatchRequest.fromJson(json);
      expect(req.userId, 'creator-1');
    });
  });
}
