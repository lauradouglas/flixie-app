import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/social/data/chat_unread_controller.dart';
import 'package:flixie_app/features/social/presentation/widgets/conversations_hub.dart';
import 'package:flixie_app/models/conversation.dart';

void main() {
  testWidgets(
      'marks direct and group chats, preserves failures for retry and receives new unread counts',
      (tester) async {
    final chats = StreamController<List<Conversation>>();
    final counts = <String, StreamController<int>>{};
    final calls = <String>[];
    var failGroup = true;
    final controller = ChatUnreadController(
      conversations: (_) => chats.stream,
      counts: (id, _) => (counts[id] = StreamController<int>()).stream,
      markRead: (id, user) async {
        expect(user, 'me');
        calls.add(id);
        if (id == 'group' && failGroup) throw StateError('offline');
        counts[id]!.add(0);
      },
    );
    controller.syncUser('me');
    chats.add(const [
      Conversation(id: 'direct', type: 'direct', memberIds: ['me']),
      Conversation(id: 'group', type: 'group', memberIds: ['me']),
      Conversation(id: 'read', type: 'direct', memberIds: ['me']),
    ]);
    await tester.pump();
    counts['direct']!.add(2);
    counts['group']!.add(1);
    await tester.pump();
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: MarkAllChatsReadButton()))));
    await tester.tap(find.byTooltip('Message options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark all as read'));
    await tester.pumpAndSettle();
    expect(calls, ['direct', 'group']);
    expect(controller.total, 1);
    expect(find.textContaining('Some chats could not'), findsOneWidget);
    failGroup = false;
    await tester.tap(find.byTooltip('Message options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark all as read'));
    await tester.pumpAndSettle();
    expect(calls, ['direct', 'group', 'group']);
    expect(controller.total, 0);
    expect(find.text('Mark all as read'), findsNothing);
    counts['direct']!.add(1);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Message options'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      controller.dispose();
      await chats.close();
      for (final stream in counts.values) {
        await stream.close();
      }
    });
  });

  test('deduplicates taps and stops on account change', () async {
    final chats = StreamController<List<Conversation>>();
    final counts = <String, StreamController<int>>{};
    final pending = Completer<void>();
    final calls = <String>[];
    final controller = ChatUnreadController(
      conversations: (_) => chats.stream,
      counts: (id, _) => (counts[id] = StreamController<int>()).stream,
      markRead: (id, user) {
        calls.add('$user/$id');
        return pending.future;
      },
    );
    controller.syncUser('me');
    chats.add(const [
      Conversation(id: 'a', type: 'direct', memberIds: ['me']),
      Conversation(id: 'b', type: 'group', memberIds: ['me'])
    ]);
    await Future<void>.delayed(Duration.zero);
    counts['a']!.add(1);
    counts['b']!.add(2);
    await Future<void>.delayed(Duration.zero);
    final operation = controller.markAllRead();
    await controller.markAllRead();
    expect(calls, ['me/a']);
    controller.syncUser(null);
    pending.complete();
    await operation;
    expect(calls, ['me/a']);
    expect(controller.total, 0);
    expect(controller.markingAllRead, false);
    controller.dispose();
    await chats.close();
    for (final stream in counts.values) {
      await stream.close();
    }
  });
}
