import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/conversation.dart';
import 'package:flixie_app/features/social/presentation/widgets/paged_chat_builder.dart';

ChatMessage msg(int i) => ChatMessage(
    id: '$i',
    senderId: 'robin',
    text: 'Alien message $i',
    createdAt: DateTime(2026, 10, 21, 0, i));
void main() {
  testWidgets(
      'scrolling up fetches older history, retry preserves bubbles, rebuilds retain subscription',
      (tester) async {
    final live = StreamController<List<ChatMessage>>();
    addTearDown(live.close);
    var calls = 0;
    var fail = true;
    var subscriptions = 0;
    Future<void> mount(String account) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: PagedChatBuilder(
                  source: (account, 'chat'),
                  createStream: () {
                    subscriptions++;
                    return live.stream;
                  },
                  loadPage: (before) async {
                    calls++;
                    expect(before.id, '21');
                    if (fail) throw StateError('offline');
                    return [msg(20), msg(19)];
                  },
                  builder: (context, history, scroll) {
                    if (history.loading) return const Text('Loading');
                    final messages = history.messages;
                    return ListView.builder(
                        controller: scroll,
                        reverse: true,
                        itemCount: messages.length + 1,
                        itemBuilder: (_, i) => i == messages.length
                            ? ChatHistoryFooter(history: history)
                            : SizedBox(
                                height: 80, child: Text(messages[i].text)));
                  }))));
      await tester.pump();
    }

    await mount('me');
    live.add(List.generate(20, (i) => msg(40 - i)));
    await tester.pumpAndSettle();
    expect(calls, 0);
    await mount('me');
    expect(subscriptions, 1);
    final list = find.byType(ListView);
    await tester.drag(list, const Offset(0, 2500));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Could not load older messages · Retry'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Could not load older messages · Retry'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    await tester.drag(list, const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(find.text('Alien message 19'), findsOneWidget);
    expect(find.text('Load older messages'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(live.hasListener, isFalse);
  });
}
