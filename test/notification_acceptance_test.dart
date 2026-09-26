import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/features/profile/presentation/pages/notification_screen.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  List<FlixieNotification>? saved;
  @override
  User get dbUser => const User(
      id: 'me',
      username: 'Me',
      email: '',
      iconColorId: 0,
      completedSetup: true,
      darkMode: true);
  @override
  List<FlixieNotification>? get cachedNotifications => saved;
  @override
  void updateCachedNotifications(List<FlixieNotification> value) {
    saved = List.of(value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Analytics extends ChangeNotifier implements AnalyticsController {
  @override
  Future<void> friendConnected({String source = 'unknown'}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  for (final failure in ['inbox', 'friends', 'request']) {
    testWidgets('accept friendship with $failure failure', (tester) async {
      var mutations = 0;
      final auth = _Auth();
      ApiClient.useClientForTesting(MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/notifications/user/me')) {
          return http.Response(
              jsonEncode([
                {
                  'id': 'n',
                  'userId': 'me',
                  'type': 'FRIEND_REQUEST',
                  'action': 'RECEIVED',
                  'message': '',
                  'link': {
                    'request': {
                      'id': 'r',
                      'requesterId': 'friend',
                      'recipientId': 'me',
                      'status': 'PENDING',
                      'requester': {'id': 'friend', 'username': 'Friend'}
                    }
                  },
                }
              ]),
              200);
        }
        if (path.endsWith('/requests/update')) {
          mutations++;
          return http.Response('{}', failure == 'request' ? 400 : 200);
        }
        if (path.endsWith('/notifications/update')) {
          return http.Response(
              jsonEncode({
                'id': 'n',
                'userId': 'me',
                'type': 'FRIEND_REQUEST',
                'message': ''
              }),
              failure == 'inbox' ? 400 : 200);
        }
        if (path.endsWith('/friends/me')) return http.Response('{}', 400);
        return http.Response('{}', 200);
      }));
      addTearDown(() => ApiClient.useClientForTesting(null));
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<AnalyticsController>(
                create: (_) => _Analytics()),
          ],
          child: MaterialApp(
              theme: AppTheme.darkTheme, home: const NotificationScreen())));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      expect(mutations, 1);
      if (failure == 'request') {
        expect(
            find.text('Failed to accept. Please try again.'), findsOneWidget);
        expect(find.text('Accept'), findsOneWidget);
      } else {
        expect(find.text('Request accepted successfully.'), findsOneWidget);
        expect(find.text('Failed to accept. Please try again.'), findsNothing);
        expect(find.text('Accept'), findsNothing);
        expect(auth.saved, isEmpty);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
