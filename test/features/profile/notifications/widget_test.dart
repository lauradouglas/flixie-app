import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/features/profile/presentation/pages/notification_screen.dart';
import 'package:flixie_app/features/profile/presentation/widgets/notification_inbox_card.dart';
import '../../../support/api_fixture.dart';
import 'journey.dart';

class InboxAnalytics extends ChangeNotifier implements AnalyticsController {
  int connections = 0;
  @override
  Future<void> friendConnected({String source = 'unknown'}) async {
    connections++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Widget host(InboxAuth auth, {InboxAnalytics? analytics, double scale = 1}) =>
    MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          if (analytics != null)
            ChangeNotifierProvider<AnalyticsController>.value(value: analytics)
        ],
        child: MaterialApp(
            theme: AppTheme.darkTheme,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: const NotificationScreen()));

void main() {
  testWidgets('older notifications load on demand and mark-all-read is global',
      pagingJourney);
  setUpAll(() async {
    await (FontLoader('Manrope')
          ..addFont(
              rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  testWidgets(
      'account change ignores pending read and clears old visible cards',
      (tester) async {
    final old = Completer<http.Response>();
    final auth = InboxAuth();
    addTearDown(auth.dispose);
    useApiFixture(MockClient((request) async {
      final user = request.url.pathSegments.last;
      if (user == 'inbox-viewer') return old.future;
      return http.Response(jsonEncode(inboxPayload(user, count: 1)), 200);
    }));
    await tester.pumpWidget(host(auth));
    await tester.pump();
    auth.change('new-viewer');
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<NotificationInboxCard>(find.byType(NotificationInboxCard))
            .notification
            .userId,
        'new-viewer');
    old.complete(
        http.Response(jsonEncode(inboxPayload('inbox-viewer', count: 1)), 200));
    await tester.pumpAndSettle();
    expect(auth.cacheOwners, everyElement('new-viewer'));
    auth.change(null);
    await tester.pumpAndSettle();
    expect(find.byType(NotificationInboxCard), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('late invitation response cannot update the next account',
      (tester) async {
    final response = Completer<http.Response>();
    final auth = InboxAuth();
    final analytics = InboxAnalytics();
    addTearDown(auth.dispose);
    addTearDown(analytics.dispose);
    var secondaryWrites = 0;
    useApiFixture(MockClient((request) async {
      if (request.url.path == '/requests/update') return response.future;
      if (request.url.path == '/notifications/update') {
        secondaryWrites++;
        return http.Response('{}', 200);
      }
      if (request.url.path.startsWith('/notifications/user/')) {
        return http.Response(
            jsonEncode(inboxPayload(request.url.pathSegments.last, count: 1)),
            200);
      }
      return http.Response('{}', 200);
    }));
    await tester.pumpWidget(host(auth, analytics: analytics));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept'));
    await tester.pump();
    auth.change('new-viewer');
    await tester.pumpAndSettle();
    response.complete(http.Response('{}', 200));
    await tester.pumpAndSettle();
    expect(secondaryWrites, 0);
    expect(analytics.connections, 0);
    expect(find.text('Request accepted successfully.'), findsNothing);
    expect(find.text('Accept'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'failed swipe restores the card and retry removes it', dismissJourney);
  testWidgets(
      'inbox and options fit phones, landscape and tablet with large text',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = InboxAuth();
    addTearDown(auth.dispose);
    useApiFixture(MockClient((_) async =>
        http.Response(jsonEncode(inboxPayload(auth.id!, count: 2)), 200)));
    for (final size in [
      const Size(320, 640),
      const Size(430, 932),
      const Size(844, 390),
      const Size(1024, 1366)
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(host(auth, scale: 2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final card = tester.widget<NotificationInboxCard>(
          find.byType(NotificationInboxCard).first);
      card.onOptions();
      await tester.pumpAndSettle();
      expect(find.text('Notification options'), findsOneWidget);
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.text('Notification options'))).pop();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    }
  });
}

Future<void> dismissJourney(WidgetTester tester) async {
  final auth = InboxAuth();
  addTearDown(auth.dispose);
  var deletes = 0;
  var deleted = false;
  useApiFixture(MockClient((request) async {
    if (request.method == 'DELETE') {
      deletes++;
      deleted = deletes > 1;
      return http.Response('{}', deleted ? 200 : 503);
    }
    return http.Response(
        jsonEncode(deleted ? [] : inboxPayload(auth.id!, count: 1)), 200);
  }));
  await tester.pumpWidget(host(auth));
  await tester.pumpAndSettle();
  await tester.drag(find.byType(Dismissible), const Offset(-700, 0));
  await tester.pumpAndSettle();
  expect(deletes, 1);
  expect(find.byType(NotificationInboxCard), findsOneWidget);
  expect(find.text('Failed to dismiss notification.'), findsOneWidget);
  ScaffoldMessenger.of(tester.element(find.byType(NotificationScreen)))
      .hideCurrentSnackBar();
  await tester.pumpAndSettle();
  await tester.drag(find.byType(Dismissible), const Offset(-700, 0));
  await tester.pumpAndSettle();
  expect(deletes, 2);
  expect(find.byType(NotificationInboxCard), findsNothing);
  expect(auth.saved, isEmpty);
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
}

Future<void> pagingJourney(WidgetTester tester) async {
  final auth = InboxAuth();
  addTearDown(auth.dispose);
  var reads = 0, allRead = 0;
  useApiFixture(MockClient((request) async {
    if (request.url.path == '/notifications/read-all') {
      allRead++;
      return http.Response('{}', 200);
    }
    reads++;
    expect(request.url.queryParameters['page'], 'true');
    final older = request.url.queryParameters['cursor'] != null;
    final items = inboxPayload('inbox-viewer', count: 2);
    return http.Response(
        jsonEncode({
          'items': [items[older ? 1 : 0]],
          'nextCursor': older ? null : 'older-cursor',
          'unreadCount': 100,
        }),
        200);
  }));
  await tester.pumpWidget(host(auth));
  await tester.pumpAndSettle();
  expect(reads, 1);
  expect(find.byType(NotificationInboxCard), findsOneWidget);
  await tester.tap(find.text('Load older notifications'));
  await tester.pumpAndSettle();
  expect(reads, 2);
  expect(find.byType(NotificationInboxCard), findsNWidgets(2));
  expect(find.text('Load older notifications'), findsNothing);
  await tester.tap(find.text('Mark all read'));
  await tester.pumpAndSettle();
  expect(allRead, 1);
  expect(auth.saved!.every((n) => n.isRead), isTrue);
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
}
