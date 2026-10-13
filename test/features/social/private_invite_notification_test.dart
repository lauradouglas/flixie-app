import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/notification_destination.dart';
import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/features/profile/presentation/widgets/notification_inbox_card.dart';
import 'package:flixie_app/features/social/presentation/pages/private_communities_screen.dart';
import 'private_communities_test.dart' show PrivateFixture;

void main() {
  testWidgets(
      'invite notification opens preview and explicit join enters community',
      (t) async {
    final fixture = PrivateFixture()..canCreate = false;
    final notification = FlixieNotification.fromJson({
      'id': 'private-invite:personal',
      'userId': 'fixture',
      'type': 'COMMUNITY_INVITE',
      'action': 'RECEIVED',
      'read': true,
      'closed': false,
      'message': 'Robin invited you to join Movie night club.',
      'data': {
        'invitationId': 'personal',
        'communityId': '-1000',
        'communityName': 'Movie night club'
      }
    });
    expect(notificationNeedsResponse(notification), isTrue);
    expect(notificationBelongsInInbox(notification), isTrue);
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (c, s) => Scaffold(
              body: TextButton(
                  onPressed: () =>
                      c.push(notificationDestination(notification)),
                  child: Text(notificationHeadline(notification))))),
      GoRoute(
          path: '/private-communities',
          builder: (c, s) => PrivateCommunitiesScreen(
              service: fixture,
              inviteKey: s.uri.queryParameters['invitation'])),
      GoRoute(
          path: '/genre-communities/:id',
          builder: (c, s) => const Scaffold(body: Text('Inside community')))
    ]);
    addTearDown(router.dispose);
    await t.pumpWidget(
        MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router));
    await t.tap(find.text(notificationHeadline(notification)));
    await t.pumpAndSettle();
    expect(fixture.accepted, 0);
    expect(find.text('Join community'), findsOneWidget);
    await t.tap(find.text('Join community'));
    await t.pumpAndSettle();
    expect(fixture.accepted, 1);
    expect(find.text('Inside community'), findsOneWidget);
  });
  test('accepted invite opens the joined community', () {
    final n = FlixieNotification.fromJson({
      'userId': 'fixture',
      'type': 'COMMUNITY_INVITE',
      'action': 'ACCEPTED',
      'closed': true,
      'message': '',
      'data': {'communityId': '-1000', 'communityName': 'Movie night club'}
    });
    expect(notificationDestination(n), '/genre-communities/-1000');
    expect(notificationNeedsResponse(n), isFalse);
    expect(notificationHeadline(n), 'You joined Movie night club');
  });
}
