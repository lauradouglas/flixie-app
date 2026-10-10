import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/features/profile/data/notification_service.dart';
import 'package:flixie_app/features/profile/presentation/controllers/notification_inbox_controller.dart';

FlixieNotification item(String id, {String user = 'viewer'}) =>
    FlixieNotification(
        id: id,
        userId: user,
        type: 'FRIEND_REQUEST',
        action: 'RECEIVED',
        message: 'Alien');
void main() {
  test(
      'legacy server uses individual read writes instead of an unavailable bulk endpoint',
      () async {
    var bulk = 0, writes = 0;
    final inbox = NotificationInboxController(
        fetchPage: (user, {cursor}) async => NotificationPage([item('first')],
            unreadCount: 1, supportsBulkRead: false),
        writeAllRead: () async {
          bulk++;
        },
        writeRead: (_, __) async {
          writes++;
        },
        onCache: (_, __) {});
    addTearDown(inbox.dispose);
    inbox.bind('viewer', null);
    await inbox.refresh();
    expect(await inbox.markAllRead(), true);
    expect(bulk, 0);
    expect(writes, 1);
    expect(inbox.unreadCount, 0);
  });

  test('silent refresh retains the displayed page depth and refreshes once',
      () async {
    var reads = 0;
    final inbox = NotificationInboxController(
        fetchPage: (user, {cursor}) async {
          reads++;
          return cursor == null
              ? NotificationPage([item('first')],
                  nextCursor: 'older', unreadCount: 2)
              : NotificationPage([item('last')], unreadCount: 2);
        },
        onCache: (_, __) {});
    addTearDown(inbox.dispose);
    inbox.bind('viewer', null);
    await inbox.refresh();
    await inbox.loadMore();
    await inbox.refresh(silent: true);
    expect(inbox.notifications.length, 2);
    expect(reads, 4);
  });

  test(
      'older pages retain cards, deduplicate IDs and keep the global unread count',
      () async {
    final cursors = <String?>[];
    final inbox = NotificationInboxController(
        fetchPage: (user, {cursor}) async {
          cursors.add(cursor);
          return cursor == null
              ? NotificationPage([item('first')],
                  nextCursor: 'older', unreadCount: 90)
              : NotificationPage([item('first'), item('last')],
                  unreadCount: 90);
        },
        onCache: (_, __) {});
    addTearDown(inbox.dispose);
    inbox.bind('viewer', null);
    await inbox.refresh();
    expect(inbox.hasMore, true);
    expect(inbox.unreadCount, 90);
    await inbox.loadMore();
    expect(inbox.notifications.map((n) => n.id), ['first', 'last']);
    expect(inbox.hasMore, false);
    expect(cursors, [null, 'older']);
    expect(inbox.unreadCount, 90);
  });
  test('page failure preserves current cards and cursor; retry succeeds',
      () async {
    var fail = true;
    final inbox = NotificationInboxController(
        fetchPage: (user, {cursor}) async {
          if (cursor != null && fail) throw StateError('offline');
          return cursor == null
              ? NotificationPage([item('first')],
                  nextCursor: 'older', unreadCount: 2)
              : NotificationPage([item('last')], unreadCount: 2);
        },
        onCache: (_, __) {});
    addTearDown(inbox.dispose);
    inbox.bind('viewer', null);
    await inbox.refresh();
    await inbox.loadMore();
    expect(inbox.notifications.single.id, 'first');
    expect(inbox.pageError, isNotNull);
    expect(inbox.hasMore, true);
    fail = false;
    await inbox.loadMore();
    expect(inbox.notifications.length, 2);
    expect(inbox.pageError, isNull);
  });
  test('old-account page cannot overwrite new-account state', () async {
    final pending = Completer<NotificationPage>();
    final inbox = NotificationInboxController(
        fetchPage: (user, {cursor}) async => cursor != null
            ? await pending.future
            : NotificationPage([item(user, user: user)],
                nextCursor: 'older', unreadCount: 1),
        onCache: (_, __) {});
    addTearDown(inbox.dispose);
    inbox.bind('old', null);
    await inbox.refresh();
    final load = inbox.loadMore();
    inbox.bind('new', null);
    await inbox.refresh();
    pending.complete(
        NotificationPage([item('late', user: 'old')], unreadCount: 77));
    await load;
    expect(inbox.notifications.single.userId, 'new');
    expect(inbox.unreadCount, 1);
  });
  test('mark all read uses one account-wide operation including unloaded cards',
      () async {
    var writes = 0;
    final inbox = NotificationInboxController(
        fetchPage: (user, {cursor}) async => NotificationPage([item('first')],
            nextCursor: 'older', unreadCount: 500),
        writeAllRead: () async {
          writes++;
        },
        onCache: (_, __) {});
    addTearDown(inbox.dispose);
    inbox.bind('viewer', null);
    await inbox.refresh();
    expect(await inbox.markAllRead(), true);
    expect(writes, 1);
    expect(inbox.unreadCount, 0);
    expect(inbox.notifications.single.isRead, true);
    expect(inbox.hasMore, true);
  });
}
