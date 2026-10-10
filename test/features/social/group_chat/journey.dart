import 'dart:async';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/features/social/presentation/widgets/chat_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/safety/safety_service.dart';
import 'package:flixie_app/features/social/presentation/widgets/chat_bubble.dart';
import '../../../support/api_fixture.dart';
import 'fixture.dart';

Future<void> rebuildJourney(WidgetTester tester,
    Widget Function(ChatFixture data, bool active) buildChat,
    {bool before = false}) async {
  SafetyService.reset();
  useApiFixture(MockClient((_) async => http.Response('[]', 200)));
  final data = ChatFixture();
  final auth = ChatFixtureAuth();
  addTearDown(auth.dispose);
  addTearDown(data.close);
  Future<void> mount(bool active) async {
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(home: Scaffold(body: buildChat(data, active)))));
    await tester.pumpAndSettle();
  }

  final watch = Stopwatch()..start();
  await mount(true);
  watch.stop();
  expect(find.byType(ChatBubble), findsWidgets);
  final initial = data.subscriptions;
  for (var i = 0; i < 10; i++) {
    await mount(i.isEven);
  }
  expect(data.groupReads, 1);
  expect(data.subscriptions - initial, before ? 10 : 0);
  debugPrint('GROUP_CHAT_BENCH before=$before messages=50 '
      'opening_widget_ms=${watch.elapsedMicroseconds / 1000} '
      'initial_subscriptions=$initial rebuild_subscriptions=${data.subscriptions - initial} '
      'cancellations=${data.cancellations}');
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  expect(data.cancellations, data.subscriptions);
}

Future<void> sendJourney(WidgetTester tester) async {
  SafetyService.reset();
  var sends = 0;
  useApiFixture(MockClient((request) async {
    if (request.url.path.endsWith('/messages')) {
      sends++;
      expect(request.body, contains('The Odyssey tonight?'));
      return http.Response('{}', sends == 1 ? 503 : 200);
    }
    return http.Response('[]', 200);
  }));
  final auth = ChatFixtureAuth();
  final data = ChatFixture();
  final analytics = ChatAnalytics();
  addTearDown(auth.dispose);
  addTearDown(data.close);
  addTearDown(analytics.dispose);
  await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<AnalyticsController>.value(value: analytics),
      ],
      child: MaterialApp(
          home: Scaffold(body: GroupChatTab(groupId: 'club', service: data)))));
  await tester.pumpAndSettle();
  for (var i = 0; i < 2; i++) {
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'The Odyssey tonight?');
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'The Odyssey tonight?');
    await tester.tap(find.byIcon(Icons.send_rounded));
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(sends, i + 1);
    if (i == 0) {
      expect(find.text('Failed to send message'), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.byType(GroupChatTab)))
          .hideCurrentSnackBar();
      await tester.pumpAndSettle();
    }
  }
  expect(analytics.sent, 1);
  expect(data.subscriptions, 1);
  data.channels.last.addError(StateError('connection interrupted'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Could not load messages · Retry'));
  await tester.pumpAndSettle();
  expect(data.subscriptions, 2);
  expect(find.byType(ChatBubble), findsWidgets);
  await tester.pumpWidget(const SizedBox());
}

class ChatAnalytics extends ChangeNotifier implements AnalyticsController {
  int sent = 0;
  @override
  Future<void> groupMessageSent(
      {required String groupType, String source = 'group'}) async {
    sent++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> loadingJourney(
    WidgetTester tester, Widget Function(ChatFixture) buildChat,
    {bool before = false}) async {
  SafetyService.reset();
  useApiFixture(MockClient((_) async => http.Response('[]', 200)));
  final data = ChatFixture()..gate = Completer<void>();
  final auth = ChatFixtureAuth();
  addTearDown(data.close);
  addTearDown(auth.dispose);
  await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
      value: auth, child: MaterialApp(home: Scaffold(body: buildChat(data)))));
  for (var i = 0; i < 10; i++) {
    auth.ping();
  }
  expect(data.groupReads, before ? 11 : 1);
  data.gate!.complete();
  await tester.pumpAndSettle();
  expect(data.creates, before ? 11 : 1);
  debugPrint('GROUP_CHAT_LOADING_BENCH before=$before auth_notifications=10 '
      'group_reads=${data.groupReads} member_reads=${data.memberReads} '
      'conversation_calls=${data.creates} request_reads=${data.requestReads}');
  await tester.pumpWidget(const SizedBox());
}
