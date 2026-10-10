import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/social/presentation/controllers/group_chat_session.dart';
import 'fixture.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);
void main() {
  test('repeated auth notifications join the same initialization', () async {
    final data = ChatFixture()..gate = Completer<void>();
    final session = GroupChatSession(service: data);
    addTearDown(session.dispose);
    for (var i = 0; i < 10; i++) {
      session.bind('club', 'viewer');
    }
    expect(data.groupReads, 1);
    data.gate!.complete();
    await flush();
    expect(data.creates, 1);
    expect(data.requestReads, 1);
    expect(session.conversationId, 'club-viewer');
    final stream = session.messages;
    session.bind('club', 'viewer');
    expect(identical(stream, session.messages), isTrue);
  });
  test(
      'account change discards old initialization before conversation creation',
      () async {
    final gate = Completer<void>();
    final data = ChatFixture()..gate = gate;
    final session = GroupChatSession(service: data);
    addTearDown(session.dispose);
    session.bind('club', 'old');
    data.gate = null;
    session.bind('club', 'new');
    await flush();
    gate.complete();
    await flush();
    expect(data.creates, 1);
    expect(session.conversationId, 'club-new');
  });
  test('switching group invalidates operation ownership and clears state',
      () async {
    final session = GroupChatSession(service: ChatFixture());
    addTearDown(session.dispose);
    session.bind('club', 'viewer');
    await flush();
    final generation = session.generation;
    session.bind('other', 'viewer');
    expect(session.owns(generation), isFalse);
    expect(session.messages, isNull);
    expect(session.members, isEmpty);
    await flush();
    expect(session.conversationId, 'other-viewer');
    session.bind('other', null);
    expect(session.conversationId, isNull);
    expect(session.requests, isEmpty);
  });
  test('failure is retryable without overlapping retries', () async {
    final data = ChatFixture()..fail = true;
    final session = GroupChatSession(service: data);
    addTearDown(session.dispose);
    session.bind('club', 'viewer');
    await flush();
    expect(session.error, isNotNull);
    data.fail = false;
    session.retry();
    session.retry();
    await flush();
    expect(data.groupReads, 2);
    expect(session.error, isNull);
    expect(session.conversationId, 'club-viewer');
  });
  test('dispose drops pending initialization without notifications or writes',
      () async {
    final data = ChatFixture()..gate = Completer<void>();
    final session = GroupChatSession(service: data);
    session.bind('club', 'viewer');
    session.dispose();
    data.gate!.complete();
    await flush();
    expect(data.creates, 0);
    expect(session.messages, isNull);
  });
}
