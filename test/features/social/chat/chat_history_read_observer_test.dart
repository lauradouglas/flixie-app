import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/social/data/chat_unread_controller.dart';
import 'package:flixie_app/features/social/presentation/widgets/chat_read_observer.dart';
import 'package:flixie_app/models/conversation.dart';
import '../../../support/api_fixture.dart';
import '../group_chat/fixture.dart';

void main() {
  testWidgets(
      'incoming messages stay unread while browsing history, then acknowledge at latest',
      (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final chats = StreamController<List<Conversation>>();
    final counts = StreamController<int>();
    final auth = ChatFixtureAuth();
    var atLatest = false;
    var acknowledgements = 0;
    final unread = ChatUnreadController(
        conversations: (_) => chats.stream, counts: (_, __) => counts.stream);
    useApiFixture(MockClient((request) async {
      expect(request.method, 'PATCH');
      expect(request.url.path, '/conversations/chat/read');
      acknowledgements++;
      counts.add(0);
      return http.Response('{}', 200);
    }));
    unread.syncUser('viewer');
    chats.add(const [
      Conversation(id: 'chat', type: 'dm', memberIds: ['viewer'])
    ]);
    await tester.pump();
    counts.add(3);
    await tester.pump();
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<ChatUnreadController>.value(value: unread),
        ],
        child: MaterialApp(
            home: Scaffold(
                body: ChatReadObserver(
                    conversationId: 'chat',
                    canMarkRead: () => atLatest,
                    child: const Text('History'))))));
    await tester.pump(const Duration(seconds: 2));
    expect(acknowledgements, 0);
    expect(unread.total, 3);
    expect(
        tester
            .element(find.byType(ChatReadObserver))
            .read<ChatUnreadController?>(),
        same(unread));
    atLatest = true;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(acknowledgements, 1);
    expect(unread.total, 0);
    await tester.pumpWidget(const SizedBox());
    unread.dispose();
    auth.dispose();
    addTearDown(chats.close);
    addTearDown(counts.close);
  });
}
