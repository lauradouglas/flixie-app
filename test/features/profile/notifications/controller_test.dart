import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/features/profile/presentation/controllers/notification_inbox_controller.dart';

FlixieNotification item(String id, {String user = 'viewer', String? plan}) =>
    FlixieNotification(
        id: id,
        userId: user,
        type: plan == null ? 'FRIEND_REQUEST' : 'MOVIE_WATCH_REQUEST',
        action: 'RECEIVED',
        message: 'The Odyssey',
        relatedId: plan);
Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  test('overlapping loads share one read and one cache publication', () async {
    final gate = Completer<List<FlixieNotification>>();
    var reads = 0, caches = 0;
    final inbox = NotificationInboxController(
        fetch: (_) {
          reads++;
          return gate.future;
        },
        onCache: (_, __) => caches++);
    addTearDown(inbox.dispose);
    inbox.bind('viewer', []);
    final a = inbox.refresh();
    final b = inbox.refresh();
    expect(identical(a, b), isTrue);
    expect(reads, 1);
    gate.complete([item('odyssey')]);
    await a;
    await b;
    expect(caches, 1);
    expect(inbox.notifications.single.id, 'odyssey');
  });
  test('old account results never enter a new account cache or view', () async {
    final old = Completer<List<FlixieNotification>>();
    final caches = <String>[];
    final inbox = NotificationInboxController(
        fetch: (user) async =>
            user == 'old' ? await old.future : [item('new-item', user: user)],
        onCache: (user, _) => caches.add(user));
    addTearDown(inbox.dispose);
    inbox.bind('old', []);
    final first = inbox.refresh();
    inbox.bind('new', []);
    await inbox.refresh();
    old.complete([item('old-item', user: 'old')]);
    await first;
    expect(inbox.notifications.single.id, 'new-item');
    expect(caches, ['new']);
    inbox.bind(null, null);
    expect(inbox.notifications, isEmpty);
    expect(inbox.loading, isFalse);
  });
  test('failed dismissal restores every matching plan notification', () async {
    final items = [item('one', plan: 'plan'), item('two', plan: 'plan')];
    final remove = Completer<void>();
    final inbox = NotificationInboxController(
        fetch: (_) async => items,
        remove: (_) => remove.future,
        onCache: (_, __) {});
    addTearDown(inbox.dispose);
    inbox.bind('viewer', items);
    final result = inbox.dismiss(items.first);
    expect(inbox.notifications, isEmpty);
    remove.completeError(StateError('offline'));
    expect(await result, isFalse);
    expect(inbox.notifications.map((n) => n.id), containsAll(['one', 'two']));
  });
  test('pending old read cannot resurrect a successfully dismissed item',
      () async {
    final stale = Completer<List<FlixieNotification>>();
    var reads = 0;
    final inbox = NotificationInboxController(
        fetch: (_) {
          reads++;
          return reads == 1 ? stale.future : Future.value([]);
        },
        remove: (_) async {},
        onCache: (_, __) {});
    addTearDown(inbox.dispose);
    inbox.bind('viewer', [item('one')]);
    final read = inbox.refresh();
    final removed = inbox.dismiss(item('one'));
    await flush();
    expect(inbox.notifications, isEmpty);
    stale.complete([item('one')]);
    await read;
    expect(await removed, isTrue);
    expect(reads, 2);
    expect(inbox.notifications, isEmpty);
  });
  test('mark-read success survives an older refresh response', () async {
    final stale = Completer<List<FlixieNotification>>();
    final inbox = NotificationInboxController(
        fetch: (_) => stale.future,
        writeRead: (_, __) async {},
        onCache: (_, __) {});
    addTearDown(inbox.dispose);
    inbox.bind('viewer', [item('one')]);
    final read = inbox.refresh();
    expect(await inbox.setRead(item('one'), true), isTrue);
    stale.complete([item('one')]);
    await read;
    expect(inbox.notifications.single.isRead, isTrue);
  });
  test('mark all read stops issuing writes after account change', () async {
    final gate = Completer<void>();
    final writes = <String>[];
    final inbox = NotificationInboxController(
        writeRead: (id, _) {
          writes.add(id);
          return gate.future;
        },
        onCache: (_, __) {});
    addTearDown(inbox.dispose);
    inbox.bind('viewer', [item('one'), item('two')]);
    final pending = inbox.markAllRead();
    inbox.bind('other', [item('new', user: 'other')]);
    gate.complete();
    await pending;
    expect(writes, ['one']);
    expect(inbox.notifications.single.isRead, isFalse);
  });
  test('failed read shows retry; disposing ignores pending results', () async {
    var fail = true;
    final gate = Completer<List<FlixieNotification>>();
    var caches = 0;
    final inbox = NotificationInboxController(
        fetch: (_) {
          if (fail) throw StateError('offline');
          return gate.future;
        },
        onCache: (_, __) => caches++);
    inbox.bind('viewer', null);
    await inbox.refresh();
    expect(inbox.error, isNotNull);
    fail = false;
    final read = inbox.refresh(showSpinner: true);
    expect(inbox.loading, isTrue);
    inbox.dispose();
    gate.complete([item('one')]);
    await read;
    expect(caches, 0);
  });
  test('saved invitation stays hidden if a stale server snapshot repeats it',
      () async {
    final inbox = NotificationInboxController(
        fetch: (_) async => [item('one')], onCache: (_, __) {});
    addTearDown(inbox.dispose);
    inbox.bind('viewer', [item('one')]);
    expect(inbox.beginResponse('one'), isTrue);
    expect(inbox.beginResponse('one'), isFalse);
    final token = inbox.generation;
    inbox.responseSaved('one', token);
    await inbox.refresh();
    expect(inbox.notifications, isEmpty);
    inbox.endResponse('one', token);
    expect(inbox.processingIds, isEmpty);
  });
}
