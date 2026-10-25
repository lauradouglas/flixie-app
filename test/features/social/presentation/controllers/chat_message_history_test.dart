import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/conversation.dart';
import 'package:flixie_app/features/social/presentation/controllers/chat_message_history.dart';

ChatMessage message(int id, {Timestamp? at}) => ChatMessage(
    id: '$id'.padLeft(3, '0'),
    senderId: 'robin',
    text: 'Alien / The Odyssey $id',
    createdAt: at?.toDate() ?? DateTime(2026, 10, 21, 0, id),
    firestoreCreatedAt: at);
List<ChatMessage> page(int newest, int count) =>
    List.generate(count, (i) => message(newest - i));
Future<void> flush() => Future<void>.delayed(Duration.zero);
void main() {
  test(
      'history is requested only on demand, uses oldest cursor, deduplicates and stops at end',
      () async {
    final live = StreamController<List<ChatMessage>>();
    final cursors = <String>[];
    final history = ChatMessageHistory(
        live: live.stream,
        loadPage: (before) async {
          cursors.add(before.id);
          return cursors.length == 1 ? page(21, 20) : page(2, 2);
        });
    live.add(page(40, 20));
    await flush();
    expect(history.messages.length, 20);
    expect(cursors, isEmpty);
    await history.loadOlder();
    expect(cursors, ['021']);
    expect(history.messages.length, 39);
    await history.loadOlder();
    expect(cursors, ['021', '002']);
    expect(history.messages.length, 40);
    expect(history.hasOlder, isFalse);
    await history.loadOlder();
    expect(cursors.length, 2);
    history.dispose();
    await live.close();
  });
  test(
      'simultaneous requests share one page; failures retain messages and retry same cursor',
      () async {
    final live = StreamController<List<ChatMessage>>();
    var calls = 0;
    final gate = Completer<List<ChatMessage>>();
    final history = ChatMessageHistory(
        live: live.stream,
        loadPage: (before) {
          calls++;
          return gate.future;
        });
    live.add(page(40, 20));
    await flush();
    final loading = history.loadOlder();
    await history.loadOlder();
    expect(calls, 1);
    gate.completeError(StateError('offline'));
    await loading;
    expect(history.messages.length, 20);
    expect(history.olderError, isNotNull);
    expect(history.hasOlder, isTrue);
    history.dispose();
    await live.close();
  });
  test(
      'live arrivals preserve evicted boundary; history scroll holds arrivals until returning to bottom',
      () async {
    final live = StreamController<List<ChatMessage>>();
    final history = ChatMessageHistory(
        live: live.stream, loadPage: (before) async => page(20, 20));
    live.add(page(40, 20));
    await flush();
    live.add(page(41, 20));
    await flush();
    expect(history.messages.length, 21);
    expect(history.messages.last.id, '021');
    await history.loadOlder();
    history.holdLive = true;
    live.add(page(42, 20));
    await flush();
    expect(history.messages.first.id, '041');
    history.holdLive = false;
    await flush();
    expect(history.messages.first.id, '042');
    expect(history.messages.last.id, '001');
    history.dispose();
    await live.close();
  });
  test('timestamp ties retain nanoseconds and use deterministic ID ordering',
      () async {
    final live = StreamController<List<ChatMessage>>();
    final history =
        ChatMessageHistory(live: live.stream, loadPage: (_) async => []);
    live.add([
      message(3, at: Timestamp(100, 1)),
      message(1, at: Timestamp(100, 2)),
      message(2, at: Timestamp(100, 2))
    ]);
    await flush();
    expect(history.messages.map((m) => m.id), ['002', '001', '003']);
    history.dispose();
    await live.close();
  });
  test(
      'reconnect with no overlap resets boundary and ignores an outstanding old page',
      () async {
    final live = StreamController<List<ChatMessage>>();
    final gate = Completer<List<ChatMessage>>();
    final history =
        ChatMessageHistory(live: live.stream, loadPage: (_) => gate.future);
    live.add(page(40, 20));
    await flush();
    final old = history.loadOlder();
    live.add(page(90, 20));
    await flush();
    gate.complete(page(20, 20));
    await old;
    expect(history.messages.length, 20);
    expect(history.messages.last.id, '071');
    history.dispose();
    await live.close();
  });
  test(
      'deleted live messages disappear; dispose ignores pending pages and cancels subscription',
      () async {
    final live = StreamController<List<ChatMessage>>();
    final gate = Completer<List<ChatMessage>>();
    final history =
        ChatMessageHistory(live: live.stream, loadPage: (_) => gate.future);
    live.add(page(40, 20));
    await flush();
    live.add(page(40, 20).where((m) => m.id != '039').toList());
    await flush();
    expect(history.messages.any((m) => m.id == '039'), isFalse);
    final older = history.loadOlder();
    history.dispose();
    gate.complete(page(20, 20));
    await older;
    expect(live.hasListener, isFalse);
    await live.close();
  });
}
