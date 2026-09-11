import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/features/social/data/watch_request_cache.dart';
import 'package:flixie_app/features/home/presentation/models/home_group_watch_plan.dart';
import 'package:flixie_app/features/home/presentation/models/home_watch_plan_state.dart';
import 'package:flixie_app/features/home/presentation/models/home_watch_plan_visibility.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/group_watch_request.dart';
import 'package:flixie_app/models/watch_request.dart';

http.Response response(Object data, [int status = 200]) =>
    http.Response(jsonEncode(data), status,
        headers: {'content-type': 'application/json'});
Map<String, dynamic> fixture() => jsonDecode(
        File('test/fixtures/home_group_watch_plans.json').readAsStringSync())
    as Map<String, dynamic>;
List<WatchRequest> adapt(List<dynamic> groups) => groups.expand((raw) {
      final group = Group(id: raw['id'], name: raw['name'], ownerId: '');
      return (raw['watchRequests'] as List).map(
          (p) => asHomeGroupWatchPlan(group, GroupWatchRequest.fromJson(p)));
    }).toList();

void main() {
  test(
      'full and compact payloads produce identical Home cards, states, ordering and reminder IDs',
      () {
    final data = fixture();
    final now = DateTime.utc(2026, 9, 11, 12);
    final full = adapt(data['full']);
    final compact = adapt(data['compact']);
    expect(compact.map((p) => p.id), full.map((p) => p.id));
    for (final closed in [
      <String>{},
      {'g0-p17', 'g0-p1', 'g1-p3'}
    ]) {
      final before = watchPlansForHome(full,
          userId: 'viewer', closedPlanIds: closed, at: now);
      final after = watchPlansForHome(compact,
          userId: 'viewer', closedPlanIds: closed, at: now);
      expect(after.map((p) => p.id), before.map((p) => p.id));
      List<Object?> states(List<WatchRequest> plans) =>
          homeWatchPlanStates(plans, 'viewer', now: now)
              .map((s) => [
                    s.plan.id,
                    s.type,
                    s.priority,
                    s.eyebrow,
                    s.title,
                    s.supportingText,
                    s.actionLabel,
                    s.route,
                    s.requiresAttention
                  ])
              .toList();
      expect(states(after), states(before));
      expect(after.any((p) => closed.contains(p.id)), false);
    }
    final oldCompleted = compact.firstWhere((p) => p.id == 'g0-p17');
    expect(oldCompleted.isCompleted, true);
    expect(
        watchPlansForHome([oldCompleted],
            userId: 'viewer', closedPlanIds: {}, at: now),
        hasLength(1));
    expect(homeWatchPlanStates([oldCompleted], 'viewer', now: now).single.type,
        HomeWatchPlanStateType.recap);
    for (var i = 0; i < full.length; i++) {
      expect(compact[i].latestPendingProposal?.id,
          full[i].latestPendingProposal?.id);
      expect(compact[i].scheduledFor, full[i].scheduledFor);
      expect(compact[i].watchPlanTitle, full[i].watchPlanTitle);
      expect(compact[i].candidates.map((c) => c.posterPath),
          full[i].candidates.map((c) => c.posterPath));
      expect(compact[i].watchConfirmations.map((c) => [c.userId, c.watched]),
          full[i].watchConfirmations.map((c) => [c.userId, c.watched]));
    }
    final mirror = GroupWatchRequest.fromJson({
      'id': 'mirror',
      'pgGroupRequestId': 'canonical',
      'requesterId': 'creator'
    });
    expect(
        asHomeGroupWatchPlan(
                const Group(id: 'g', name: 'Group', ownerId: ''), mirror)
            .id,
        'canonical');
  });

  test('HTTP and actual parsed-model counts scale with plans, not history',
      () async {
    final data = fixture();
    int models(GroupWatchRequest p) =>
        1 +
        p.messages.length +
        p.memberStatuses.length +
        p.candidates.length +
        p.scheduleProposals.length +
        p.scheduleProposals.fold<int>(0, (n, s) => n + s.responses.length);
    for (final scale in [
      [0, 0, 0],
      [1, 1, 0],
      [5, 10, 10],
      [20, 20, 100]
    ]) {
      final count = scale[0], plans = scale[1], history = scale[2];
      final originals = (data['full'][0]['watchRequests'] as List)
          .take(plans)
          .map((raw) => {
                ...raw as Map,
                'messages': List.generate(
                    history, (_) => (raw['messages'] as List).first),
                'scheduleProposals': [
                  ...(raw['scheduleProposals'] as List)
                      .where((p) => p['status'] == 'PENDING'),
                  ...List.generate(
                      history,
                      (_) => (raw['scheduleProposals'] as List)
                          .firstWhere((p) => p['status'] != 'PENDING')),
                ],
              })
          .toList();
      final groups = List.generate(
          count,
          (i) => {
                ...data['compact'][0],
                'id': 'g$i',
                'watchRequests': (data['compact'][0]['watchRequests'] as List)
                    .take(plans)
                    .toList()
              });
      var beforeRequests = 0,
          beforeModels = 0,
          afterRequests = 0,
          afterModels = 0;
      await http.runWithClient(() async {
        final oldGroups = await GroupService.getUserGroups('viewer');
        final requests = await Future.wait(
            oldGroups.map((g) => GroupService.getGroupWatchRequests(g.id!)));
        beforeModels =
            requests.expand((p) => p).fold<int>(0, (n, p) => n + models(p));
      },
          () => MockClient((request) async {
                beforeRequests++;
                if (request.url.path == '/groups/user/viewer') {
                  return response(List.generate(
                      count,
                      (i) => {
                            'id': 'g$i',
                            'name': 'Group $i',
                            'ownerId': 'creator'
                          }));
                }
                return response(originals);
              }));
      await http.runWithClient(() async {
        final entries = await GroupService.getHomeGroupWatchPlans();
        expect(entries.length, count * plans);
        afterModels = entries.fold<int>(0, (n, e) => n + models(e.request));
      },
          () => MockClient((request) async {
                afterRequests++;
                expect(request.url.path, '/groups/home/watch-plans');
                return response({'groups': groups});
              }));
      expect(beforeRequests, count + 1);
      expect(afterRequests, 1);
      expect(afterModels, lessThanOrEqualTo(beforeModels));
      debugPrint(
          'groups=$count plans=$plans history=$history HTTP=$beforeRequests->$afterRequests parsedModels=$beforeModels->$afterModels');
    }
  });

  test(
      'preload coalesces with Home, never seeds detail, and failures retain the last successful snapshot',
      () async {
    final data = fixture();
    final cache = WatchRequestCache();
    addTearDown(cache.dispose);
    final paths = <String>[];
    var fail = false;
    await http.runWithClient(() async {
      cache.syncUser('viewer');
      await cache.refreshHome();
      expect(paths, ['/groups/home/watch-plans']);
      expect(cache.home, hasLength(56));
      expect(cache.forGroup('g0'), isEmpty);
      final detail = await cache.refreshGroup('g0');
      expect(detail.first.messages, isNotEmpty);
      expect(paths.last, '/groups/g0/requests');
      fail = true;
      await expectLater(cache.refreshHome(), throwsException);
      expect(cache.home, hasLength(56));
      fail = false;
      await cache.refreshHome();
      expect(paths.where((p) => p == '/groups/home/watch-plans').length, 3);
    },
        () => MockClient((request) async {
              paths.add(request.url.path);
              if (fail) return response({'error': 'Unavailable'}, 503);
              if (request.url.path == '/groups/g0/requests') {
                return response(data['full'][0]['watchRequests']);
              }
              return response({'groups': data['compact']});
            }));
  });

  test(
      'membership changes remove groups, and an old account response cannot restore plans',
      () async {
    final data = fixture();
    final cache = WatchRequestCache();
    addTearDown(cache.dispose);
    final pending = <Completer<http.Response>>[];
    await http.runWithClient(() async {
      cache.syncUser('old');
      final old = cache.refreshHome();
      await Future<void>.delayed(Duration.zero);
      cache.syncUser('new');
      final fresh = cache.refreshHome();
      await Future<void>.delayed(Duration.zero);
      expect(pending.length, 2);
      pending[1].complete(response({'groups': []}));
      await fresh;
      pending[0].complete(response({'groups': data['compact']}));
      await old;
      expect(cache.home, isEmpty);
      final next = cache.refreshHome();
      await Future<void>.delayed(Duration.zero);
      pending[2].complete(response({
        'groups': [data['compact'][0]]
      }));
      await next;
      expect(cache.home.map((e) => e.group.id).toSet(), {'g0'});
      final denied = cache.refreshHome();
      await Future<void>.delayed(Duration.zero);
      pending[3].complete(response({'error': 'Forbidden'}, 403));
      await expectLater(denied, throwsException);
      expect(cache.home, isEmpty);
    },
        () => MockClient((request) {
              final completion = Completer<http.Response>();
              pending.add(completion);
              return completion.future;
            }));
  });
}
