import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/social/data/chat_unread_controller.dart';
import 'package:flixie_app/models/conversation.dart';

void main() {
  test(
      'one unread query replaces all chats; zero/removal and account changes update badges',
      () async {
    final sources = <String, StreamController<Map<String, int>>>{};
    var starts = 0;
    final controller = ChatUnreadController(unreadCounts: (user) {
      starts++;
      return (sources[user] = StreamController()).stream;
    });
    controller.syncUser('alice');
    controller.syncUser('alice');
    expect(starts, 1);
    sources['alice']!.add({'direct': 2, 'group': 4});
    await Future<void>.delayed(Duration.zero);
    expect(controller.total, 6);
    expect(controller.countFor('read-chat'), 0);
    sources['alice']!.add({'group': 4});
    await Future<void>.delayed(Duration.zero);
    expect(controller.total, 4);
    expect(controller.countFor('direct'), 0);
    sources['alice']!.add({'group': 0, 'incoming': 3});
    await Future<void>.delayed(Duration.zero);
    expect(controller.total, 3);
    controller.syncUser('bob');
    expect(controller.total, 0);
    expect(starts, 2);
    sources['alice']!.add({'private': 99});
    sources['bob']!.add({'bob-chat': 1});
    await Future<void>.delayed(Duration.zero);
    expect(controller.total, 1);
    expect(controller.countFor('private'), 0);
    controller.dispose();
    for (final source in sources.values) {
      await source.close();
    }
  });

  test(
      'missing rules/index falls back once to existing listeners and keeps counts live',
      () async {
    final query = StreamController<Map<String, int>>();
    final chats = StreamController<List<Conversation>>();
    final count = StreamController<int>();
    var fallback = 0;
    final controller = ChatUnreadController(
        unreadCounts: (_) => query.stream,
        conversations: (_) {
          fallback++;
          return chats.stream;
        },
        counts: (_, __) => count.stream);
    controller.syncUser('me');
    query.addError(FirebaseException(
        plugin: 'cloud_firestore', code: 'failed-precondition'));
    await Future<void>.delayed(Duration.zero);
    expect(fallback, 1);
    chats.add(const [
      Conversation(id: 'chat', type: 'dm', memberIds: ['me'])
    ]);
    await Future<void>.delayed(Duration.zero);
    count.add(5);
    await Future<void>.delayed(Duration.zero);
    expect(controller.total, 5);
    controller.syncUser(null);
    expect(controller.total, 0);
    controller.dispose();
    await query.close();
    await chats.close();
    await count.close();
  });

  test(
      'unread listeners wait for identity-ready conversations and do not repeat on list updates',
      () async {
    final conversations = StreamController<List<Conversation>>();
    final members = <String, StreamController<int>>{};
    final subscriptions = <String>[];
    final controller = ChatUnreadController(
        conversations: (_) => conversations.stream,
        counts: (id, _) {
          subscriptions.add(id);
          return (members[id] = StreamController<int>()).stream;
        });
    controller.syncUser('me');
    expect(subscriptions, isEmpty);
    conversations.addError(StateError('identity not ready'));
    await Future<void>.delayed(Duration.zero);
    expect(subscriptions, isEmpty);
    final chats = List.generate(
        12,
        (i) => Conversation(
            id: 'chat-$i', type: 'group', memberIds: const ['me']));
    conversations.add(chats);
    await Future<void>.delayed(Duration.zero);
    expect(subscriptions.length, 12);
    conversations.add(chats);
    await Future<void>.delayed(Duration.zero);
    expect(subscriptions.length, 12);
    members['chat-3']!.add(4);
    await Future<void>.delayed(Duration.zero);
    expect(controller.total, 4);
    controller.dispose();
    await conversations.close();
    for (final member in members.values) {
      await member.close();
    }
  });

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
