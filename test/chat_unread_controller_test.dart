import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/social/data/chat_unread_controller.dart';
import 'package:flixie_app/models/conversation.dart';

void main() {
  test('aggregates counts, clears read/removed chats, and isolates accounts',
      () async {
    final conversations = <String, StreamController<List<Conversation>>>{};
    final counts = <String, StreamController<int>>{};
    final controller = ChatUnreadController(
      conversations: (user) =>
          (conversations[user] = StreamController()).stream,
      counts: (chat, user) =>
          (counts['$user/$chat'] = StreamController()).stream,
    );
    Future<void> flush() => Future<void>.delayed(Duration.zero);
    const a = Conversation(id: 'a', type: 'direct', memberIds: ['me']);
    const b = Conversation(id: 'b', type: 'group', memberIds: ['me']);
    controller.syncUser('me');
    conversations['me']!.add([a, b]);
    await flush();
    counts['me/a']!.add(2);
    counts['me/b']!.add(5);
    await flush();
    expect(controller.total, 7);
    counts['me/a']!.add(0);
    await flush();
    expect(controller.total, 5);
    conversations['me']!.add([a]);
    await flush();
    expect(controller.total, 0);
    counts['me/a']!.add(3);
    await flush();
    controller.syncUser('other');
    expect(controller.total, 0);
    counts['me/a']!.add(9);
    await flush();
    expect(controller.total, 0);
    controller.syncUser(null);
    expect(controller.total, 0);
    controller.dispose();
    for (final stream in conversations.values) {
      await stream.close();
    }
    for (final stream in counts.values) {
      await stream.close();
    }
  });
}
