import 'package:flixie_app/core/navigation/current_route.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/core/auth/push_notification_service.dart';
import 'package:flixie_app/core/auth/notification_deep_link.dart';
import 'package:flixie_app/core/widgets/flixie_back_button.dart';

// Every notification destination family, including legacy and newer payloads.
const navigationCases = <String, Map<String, dynamic>>{
  'friend invitation': {'type': 'FRIEND_REQUEST', 'friendId': 'robin'},
  'friend acceptance': {
    'type': 'FRIEND_REQUEST_ACCEPTED',
    'route': '/friends/robin'
  },
  'referral joined': {'type': 'REFERRAL_JOINED', 'friendId': 'robin'},
  'group invitation': {'type': 'GROUP_INVITE'},
  'direct message': {'type': 'DIRECT_MESSAGE', 'senderId': 'robin'},
  'group message': {'type': 'GROUP_MESSAGE', 'groupId': 'group'},
  'movie plan': {'type': 'MOVIE_WATCH_REQUEST', 'watchPlanId': 'plan'},
  'show plan': {'type': 'SHOW_WATCH_REQUEST', 'watchPlanId': 'plan'},
  'group plan': {
    'type': 'GROUP_REQUEST',
    'watchPlanId': 'plan',
    'groupId': 'group'
  },
  'shared list': {'type': 'LIST_SHARED', 'listId': 'list'},
  'community reply': {
    'type': 'COMMUNITY_REPLY',
    'communityRoute': '/genre-communities/18/discussions/discussion?reply=reply'
  },
  'community reaction': {
    'type': 'COMMUNITY_REACTION',
    'communityRoute': '/community/posts/robin/movie-review/review'
  },
  'community list': {
    'type': 'LIST_SHARED',
    'category': 'COMMUNITY',
    'communityRoute': '/community/posts/robin/movie-list-added/list'
  },
  'community people': {
    'type': 'COMMUNITY_REPLY',
    'communityRoute': '/community/people'
  },
  'legacy movie activity': {
    'type': 'COMMUNITY_REACTION',
    'route': '/movies/101'
  },
  'legacy show activity': {'type': 'COMMUNITY_REACTION', 'route': '/shows/202'},
  'person recommendation': {'route': '/people/303'},
  'friend activity': {'route': '/friends/activity/robin/movie-review/review'},
  'unknown notification': {'type': 'UNKNOWN'},
};

void main() {
  for (final entry in navigationCases.entries) {
    for (final coldStart in [false, true]) {
      testWidgets(
          '${entry.key}: ${coldStart ? 'launch offers Home' : 'warm push restores page and draft'}',
          (tester) async {
        final key = GlobalKey<NavigatorState>();
        final draft = TextEditingController();
        addTearDown(draft.dispose);
        final path = notificationDeepLinkPath(entry.value);
        final router =
            GoRouter(navigatorKey: key, initialLocation: '/origin', routes: [
          GoRoute(
              path: '/',
              builder: (_, __) =>
                  const Scaffold(body: Text('Home destination'))),
          GoRoute(
              path: '/origin',
              builder: (_, __) => Scaffold(body: TextField(controller: draft))),
          GoRoute(
              path: Uri.parse(path).path,
              builder: (_, __) => Scaffold(
                  appBar: AppBar(leading: const FlixieBackButton()),
                  body: Text('Destination: $path'))),
        ]);
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.enterText(find.byType(TextField), 'Unfinished review');
        await expectLater(
            PushNotificationService.initialize(
                userId: 'fixture-${entry.key}-$coldStart',
                databaseUserId: 'viewer',
                navigatorKey: key),
            throwsA(isA<FirebaseException>()));
        PushNotificationService.attachRouter(router);
        if (!coldStart) {
          showDialog<void>(
              context: key.currentContext!,
              builder: (_) =>
                  const AlertDialog(content: Text('Unfinished sheet')));
          await tester.pumpAndSettle();
        }
        PushNotificationService.handleNotificationTap(entry.value,
            coldStart: coldStart);
        PushNotificationService.handleNotificationTap(entry.value,
            coldStart: coldStart);
        await tester.pumpAndSettle();
        expect(currentRouterUri(router).toString(), path);
        expect(find.text('Destination: $path'), findsOneWidget);
        expect(find.text('Unfinished sheet'), findsNothing);
        expect(router.canPop(), !coldStart);
        if (coldStart) {
          expect(find.byTooltip('Home'), findsOneWidget);
          await tester.tap(find.byTooltip('Home'));
          await tester.pumpAndSettle();
          expect(find.text('Home destination'), findsOneWidget);
        } else {
          showDialog<void>(
              context: key.currentContext!,
              builder: (_) =>
                  const AlertDialog(content: Text('Unfinished sheet')));
          await tester.pumpAndSettle();
          // A callback closes a modal over the same destination without adding a page.
          PushNotificationService.handleNotificationTap(entry.value);
          await tester.pumpAndSettle();
          expect(find.text('Unfinished sheet'), findsNothing);
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(find.byType(TextField), findsOneWidget);
          expect(draft.text, 'Unfinished review');
          expect(currentRouterUri(router).path, '/origin');
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
