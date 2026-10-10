import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/social/data/community_space_service.dart';
import 'package:flixie_app/features/social/presentation/controllers/community_discussion_controller.dart';

class ReadFixture extends CommunitySpaceService {
  final calls = <String>[];
  final pending = <String, List<Completer<Map<String, dynamic>>>>{};
  bool spoiler = false;
  @override
  Future<Map<String, dynamic>> get(int id, String path,
      [Map<String, String> query = const {}]) async {
    final key = '$path:${query['cursor'] ?? ''}';
    calls.add(key);
    final queued = pending[key];
    if (queued != null && queued.isNotEmpty) return queued.removeAt(0).future;
    if (path == '') return {'joined': true};
    if (path == '/discussions/thread') {
      return {'id': 'thread', 'spoiler': spoiler ? 'full' : 'none'};
    }
    return {
      'items': [
        {'id': 'one'}
      ],
      'nextCursor': 'page2'
    };
  }

  Completer<Map<String, dynamic>> hold(String key) {
    final result = Completer<Map<String, dynamic>>();
    pending.putIfAbsent(key, () => []).add(result);
    return result;
  }
}

CommunityDiscussionController owner(ReadFixture fixture,
        {bool? joined = true}) =>
    CommunityDiscussionController(
        communityId: 1,
        discussionId: 'thread',
        service: fixture,
        joined: joined);
Map<String, dynamic> page(String id, {String? next}) => {
      'items': [
        {'id': id}
      ],
      'nextCursor': next
    };
void main() {
  test('spoiler boundary prevents replies until explicitly revealed', () async {
    final f = ReadFixture()..spoiler = true;
    final c = owner(f);
    addTearDown(c.dispose);
    await c.load();
    expect(f.calls, ['/discussions/thread:']);
    await c.loadReplies();
    expect(f.calls.length, 1);
    c.reveal = true;
    await c.load();
    expect(c.replies.single['id'], 'one');
  });
  test(
      'membership response from superseded load cannot start another thread request',
      () async {
    final f = ReadFixture();
    final old = f.hold(':');
    final c = owner(f, joined: null);
    addTearDown(c.dispose);
    final first = c.load();
    await c.load();
    old.complete({'joined': false});
    await first;
    expect(f.calls.where((p) => p == '/discussions/thread:').length, 1);
    expect(c.member, true);
  });
  test(
      'overlapping first page reads coalesce while thread is already available',
      () async {
    final f = ReadFixture();
    final gate = f.hold('/discussions/thread/replies:');
    final c = owner(f);
    addTearDown(c.dispose);
    final loading = c.load();
    await Future<void>.delayed(Duration.zero);
    expect(c.thread, isNotNull);
    expect(c.loading, false);
    expect(c.loadingReplies, true);
    final duplicate = c.loadReplies();
    gate.complete(page('one'));
    await loading;
    await duplicate;
    expect(f.calls.where((p) => p == '/discussions/thread/replies:').length, 1);
  });
  test('forced post-write refresh supersedes an older first-page snapshot',
      () async {
    final f = ReadFixture();
    final gate = f.hold('/discussions/thread/replies:');
    final c = owner(f);
    addTearDown(c.dispose);
    final old = c.load();
    await Future<void>.delayed(Duration.zero);
    final fresh = f.hold('/discussions/thread/replies:');
    final refresh = c.loadReplies(force: true);
    fresh.complete(page('posted'));
    await refresh;
    gate.complete(page('old'));
    await old;
    expect(c.replies.single['id'], 'posted');
  });
  test('refresh supersedes old paging and removes duplicated IDs', () async {
    final f = ReadFixture();
    final c = owner(f);
    addTearDown(c.dispose);
    await c.load();
    final gate = f.hold('/discussions/thread/replies:page2');
    final more = c.loadReplies(more: true);
    await c.load();
    gate.complete({
      'items': [
        {'id': 'stale'}
      ],
      'nextCursor': null
    });
    await more;
    expect(c.replies.map((r) => r['id']), ['one']);
    final next = f.hold('/discussions/thread/replies:page2');
    final append = c.loadReplies(more: true);
    next.complete({
      'items': [
        {'id': 'one'},
        {'id': 'two'},
        {'id': 'two'}
      ],
      'nextCursor': null
    });
    await append;
    expect(c.replies.map((r) => r['id']), ['one', 'two']);
    expect(() => c.replies.clear(), throwsUnsupportedError);
  });
  test('failed paging retains content and retries the same cursor', () async {
    final f = ReadFixture();
    final c = owner(f);
    addTearDown(c.dispose);
    await c.load();
    final gate = f.hold('/discussions/thread/replies:page2');
    final more = c.loadReplies(more: true);
    gate.completeError(StateError('offline'));
    await more;
    expect(c.failedMore, true);
    expect(c.replyError, isNotNull);
    expect(c.replies.length, 1);
    await c.loadReplies(more: true);
    expect(f.calls.where((p) => p.endsWith(':page2')).length, 2);
  });
  test('disposal ignores pending membership and avoids further requests',
      () async {
    final f = ReadFixture();
    final gate = f.hold(':');
    final c = owner(f, joined: null);
    final pending = c.load();
    c.dispose();
    gate.complete({'joined': true});
    await pending;
    expect(f.calls, [':']);
  });
  test(
      'locally joined member stays joined across reload with initial visitor flag',
      () async {
    final f = ReadFixture();
    final c = owner(f, joined: false);
    addTearDown(c.dispose);
    await c.load();
    c.member = true;
    await c.load();
    expect(c.member, true);
  });
}
