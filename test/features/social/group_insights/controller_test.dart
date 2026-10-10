import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/social/presentation/controllers/group_insights_controller.dart';
import 'package:flixie_app/models/group_insights.dart';

GroupInsightsResponse result(String name) => GroupInsightsResponse(
    mostWatchedThisMonth: [GroupInsightMovie(title: name)]);

class Reads {
  final calls = <String>[];
  final pending = <Completer<GroupInsightsResponse>>[];
  Future<GroupInsightsResponse> load(String group,
      {String? timeWindow, int? limit}) {
    calls.add('$group/$timeWindow');
    final reply = Completer<GroupInsightsResponse>();
    pending.add(reply);
    return reply.future;
  }
}

void main() {
  test('initial month load and overlapping refresh share one read', () async {
    final reads = Reads();
    final c = GroupInsightsController(load: reads.load);
    addTearDown(c.dispose);
    final first = c.bind('group', viewerId: 'viewer');
    final overlapping = c.refresh();
    expect(identical(first, overlapping), isTrue);
    expect(reads.calls, ['group/month']);
    reads.pending[0].complete(result('Alien'));
    await first;
    expect(c.loading, isFalse);
    expect(c.insights.mostWatchedThisMonth.single.title, 'Alien');
    final next = c.refresh();
    expect(reads.calls, ['group/month', 'group/month']);
    reads.pending[1].complete(result('The Odyssey'));
    await next;
    expect(c.insights.mostWatchedThisMonth.single.title, 'The Odyssey');
  });

  test(
      'period change rejects previous response and same period does not reload',
      () async {
    final reads = Reads();
    final c = GroupInsightsController(load: reads.load);
    addTearDown(c.dispose);
    final first = c.bind('group');
    final all = c.setAllTime(true);
    expect(reads.calls, ['group/month', 'group/all']);
    reads.pending[1].complete(result('All time'));
    await all;
    reads.pending[0].complete(result('Old month'));
    await first;
    await c.setAllTime(true);
    expect(reads.calls, hasLength(2));
    expect(c.insights.mostWatchedThisMonth.single.title, 'All time');
  });

  test('group change rejects stale failure and retains chosen period',
      () async {
    final reads = Reads();
    final c = GroupInsightsController(load: reads.load);
    addTearDown(c.dispose);
    final first = c.bind('old');
    reads.pending[0].complete(result('Old'));
    await first;
    final all = c.setAllTime(true);
    final next = c.bind('new');
    reads.pending[2].complete(result('New'));
    await next;
    reads.pending[1].completeError(StateError('old group denied'));
    await all;
    expect(c.error, isNull);
    expect(c.insights.mostWatchedThisMonth.single.title, 'New');
    expect(reads.calls.last, 'new/all');
  });

  test('account change clears content, resets period and rejects old data',
      () async {
    final reads = Reads();
    final c = GroupInsightsController(load: reads.load);
    addTearDown(c.dispose);
    final first = c.bind('group', viewerId: 'one');
    reads.pending[0].complete(result('Private'));
    await first;
    final old = c.setAllTime(true);
    final next = c.bind('group', viewerId: 'two');
    expect(c.insights.isCompletelyEmpty, isTrue);
    expect(c.allTime, isFalse);
    reads.pending[1].complete(result('Old private'));
    await old;
    expect(c.loading, isTrue);
    reads.pending[2].complete(result('New'));
    await next;
    expect(c.insights.mostWatchedThisMonth.single.title, 'New');
  });

  test('signout clears data and stops reads and late publication', () async {
    final reads = Reads();
    final c = GroupInsightsController(load: reads.load);
    addTearDown(c.dispose);
    final pending = c.bind('group', viewerId: 'viewer');
    await c.bind('group', enabled: false);
    reads.pending[0].complete(result('Private'));
    await pending;
    await c.refresh();
    expect(c.loading, isFalse);
    expect(c.insights.isCompletelyEmpty, isTrue);
    expect(reads.calls, hasLength(1));
  });

  test('failed load remains retryable', () async {
    final reads = Reads();
    final c = GroupInsightsController(load: reads.load);
    addTearDown(c.dispose);
    final first = c.bind('group');
    reads.pending[0].completeError(StateError('offline'));
    await first;
    expect(c.error, isNotNull);
    final retry = c.refresh();
    reads.pending[1].complete(result('Recovered'));
    await retry;
    expect(c.error, isNull);
    expect(c.insights.mostWatchedThisMonth.single.title, 'Recovered');
  });

  test('synchronously thrown reader failure also remains retryable', () async {
    var calls = 0;
    final c = GroupInsightsController(load: (_, {timeWindow, limit}) {
      if (++calls == 1) throw StateError('offline');
      return Future.value(result('Recovered'));
    });
    addTearDown(c.dispose);
    await c.bind('group');
    await c.refresh();
    expect(calls, 2);
    expect(c.error, isNull);
  });

  test('disposal ignores pending completion and further commands', () async {
    final reads = Reads();
    final c = GroupInsightsController(load: reads.load);
    var notifications = 0;
    c.addListener(() => notifications++);
    final first = c.bind('group');
    c.dispose();
    final count = notifications;
    reads.pending[0].complete(result('Late'));
    await first;
    await c.refresh();
    await c.setAllTime(true);
    await c.bind('new');
    expect(notifications, count);
    expect(c.insights.isCompletelyEmpty, isTrue);
    expect(reads.calls, hasLength(1));
  });

  test('unrelated account notification does not fetch or clear content',
      () async {
    var calls = 0;
    final c = GroupInsightsController(load: (_, {timeWindow, limit}) async {
      calls++;
      return result('Alien');
    });
    addTearDown(c.dispose);
    await c.bind('group', viewerId: 'viewer');
    await c.bind('group', viewerId: 'viewer');
    expect(calls, 1);
    expect(c.insights.isCompletelyEmpty, isFalse);
  });

  test('empty group does not perform an invalid API request', () async {
    final reads = Reads();
    final c = GroupInsightsController(load: reads.load);
    addTearDown(c.dispose);
    await c.bind('');
    expect(reads.calls, isEmpty);
    expect(c.loading, isFalse);
  });
}
