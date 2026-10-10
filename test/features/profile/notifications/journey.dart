import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/features/profile/presentation/pages/notification_screen.dart';
import '../../../support/api_fixture.dart';

class InboxAuth extends ChangeNotifier implements AuthProvider {
  String? id = 'inbox-viewer';
  List<FlixieNotification>? saved;
  @override
  int get unreadNotificationCount => saved?.where((n) => !n.isRead).length ?? 0;
  final cacheOwners = <String>[];
  @override
  User? get dbUser => id == null
      ? null
      : User(
          id: id!,
          username: 'OdysseyFan',
          email: '',
          iconColorId: 0,
          completedSetup: true,
          darkMode: true);
  @override
  List<FlixieNotification>? get cachedNotifications => saved;
  @override
  void updateCachedNotifications(List<FlixieNotification> value,
      {int? unreadCount}) {
    saved = List.of(value);
    cacheOwners.add(id!);
    notifyListeners();
  }

  void change(String? value) {
    id = value;
    saved = null;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

List<Map<String, dynamic>> inboxPayload(String user, {int count = 100}) => [
      for (var i = 0; i < count; i++)
        {
          'id': '$user-$i',
          'userId': user,
          'type': 'FRIEND_REQUEST',
          'action': i.isEven ? 'RECEIVED' : 'ACCEPTED',
          'read': false,
          'message': 'The Odyssey and Alien film club',
          'notificationReceived': '2026-10-09T12:00:00Z',
          'senderUser': {
            'id': 'fixture-friend-$i',
            'username': 'AlienFan$i',
            'profileBadges': ['FOUNDER']
          },
          'link': {
            'request': {
              'id': 'request-$i',
              'requesterId': 'fixture-friend-$i',
              'recipientId': user,
              'status': i.isEven ? 'PENDING' : 'ACCEPTED',
              'requester': {
                'id': 'fixture-friend-$i',
                'username': 'AlienFan$i',
                'profileBadges': ['FOUNDER']
              }
            }
          },
        }
    ];

Future<void> pollingJourney(WidgetTester tester,
    {bool before = false, Widget Function()? screen}) async {
  final auth = InboxAuth();
  var reads = 0;
  Completer<http.Response>? gate;
  useApiFixture(MockClient((request) async {
    if (request.url.path.startsWith('/notifications/user/')) {
      reads++;
      if (gate != null) return gate.future;
      return http.Response(jsonEncode(inboxPayload(auth.id!)), 200);
    }
    return http.Response('{}', 200);
  }));
  final router = GoRouter(routes: [
    GoRoute(
        path: '/',
        builder: (_, __) => screen?.call() ?? const NotificationScreen()),
    GoRoute(
        path: '/covered',
        builder: (_, __) => const Scaffold(body: Text('Movie detail'))),
  ]);
  addTearDown(auth.dispose);
  addTearDown(router.dispose);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
      value: auth, child: MaterialApp.router(routerConfig: router)));
  await tester.pumpAndSettle();
  expect(reads, 1);
  router.push('/covered');
  await tester.pumpAndSettle();
  final visibleReads = reads;
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(seconds: 61));
    await tester.pumpAndSettle();
  }
  final hiddenReads = reads - visibleReads;
  expect(hiddenReads, before ? 3 : 0);
  router.pop();
  await tester.pumpAndSettle();
  final returnReads = reads - visibleReads - hiddenReads;
  expect(returnReads, before ? 0 : 1);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  final previous = reads;
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(seconds: 61));
    await tester.pumpAndSettle();
  }
  final backgroundReads = reads - previous;
  expect(backgroundReads, before ? 3 : 0);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpAndSettle();
  gate = Completer<http.Response>();
  final start = reads;
  final publicationsBefore = auth.cacheOwners.length;
  final refresh =
      tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh;
  final first = refresh();
  final second = refresh();
  await tester.pump();
  final overlapReads = reads - start;
  expect(overlapReads, 1);
  gate.complete(http.Response(jsonEncode(inboxPayload(auth.id!)), 200));
  await Future.wait([first, second]);
  await tester.pumpAndSettle();
  final publications = auth.cacheOwners.length - publicationsBefore;
  expect(publications, before ? 2 : 1);
  debugPrint(
      'INBOX_BENCH before=$before items=100 hidden_3_minutes=$hiddenReads '
      'background_3_minutes=$backgroundReads return_reads=$returnReads overlap_reads=$overlapReads overlap_publications=$publications');
  await tester.pumpWidget(const SizedBox());
}
