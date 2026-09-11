import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/models/group_watch_request.dart';

void main() {
  test('creator can log a scheduled watch without an RSVP row', () {
    const plan = GroupWatchRequest(id: 'plan', groupId: 'group', userId: 'creator',
      status: WatchRequestStatus.scheduled);
    expect(plan.canCompleteFor('creator'), isTrue);
    expect(plan.canCompleteFor('uninvited'), isFalse);
  });

  test('creator cannot log again after logging or missing the watch', () {
    for (final missed in [false, true]) {
      final plan = GroupWatchRequest(id: 'plan', groupId: 'group', userId: 'creator',
        status: WatchRequestStatus.scheduled, memberStatuses: [
          GroupRequestMemberStatus(memberId: 'creator', status: 'ACCEPTED',
            watchedAt: missed ? null : '2026-09-11T10:00:00Z',
            missedAt: missed ? '2026-09-11T10:00:00Z' : null),
        ]);
      expect(plan.canCompleteFor('creator'), isFalse);
    }
  });

  test('database group plans resolve a conversation before logging a watch',
      () async {
    final requests = <http.Request>[];
    final plan = GroupWatchRequest.fromJson({
      'id': 'pg-plan',
      'groupId': 'pg-group',
      'requesterId': 'laura',
    });
    await http.runWithClient(
      () => GroupService.logGroupWatchPlan(plan, 'laura',
          rating: 8,
          recommended: true,
          reviewText: 'Great',
          watchedAt: '2026-09-11T10:00:00Z'),
      () => MockClient((request) async {
        requests.add(request);
        return http.Response(
            jsonEncode(request.method == 'POST'
                ? {'id': 'chat-conversation', 'pgGroupId': 'pg-group'}
                : {'id': 'chat-plan', 'conversationId': 'chat-conversation'}),
            200);
      }),
    );
    expect(requests.map((r) => r.url.path), [
      '/conversations/group',
      '/conversations/chat-conversation/watch-requests/pg-plan/complete',
    ]);
    expect(jsonDecode(requests.first.body)['pgGroupId'], 'pg-group');
    expect(jsonDecode(requests.last.body), {
      'userId': 'laura',
      'watched': true,
      'rating': 8,
      'recommended': true,
      'reviewText': 'Great',
      'watchedAt': '2026-09-11T10:00:00Z',
    });
  });

  test(
      'conversation plans use their explicit conversation without another lookup',
      () async {
    final paths = <String>[];
    final plan = GroupWatchRequest.fromJson({
      'id': 'chat-plan',
      'pgGroupRequestId': 'pg-plan',
      'conversationId': 'chat-conversation',
      'groupId': 'pg-group',
    });
    expect(plan.conversationId, 'chat-conversation');
    await http.runWithClient(
      () => GroupService.logGroupWatchPlan(plan, 'laura'),
      () => MockClient((request) async {
        paths.add(request.url.path);
        return http.Response('{"id":"chat-plan"}', 200);
      }),
    );
    expect(paths,
        ['/conversations/chat-conversation/watch-requests/chat-plan/complete']);
  });

  test(
      'failed conversation resolution cannot submit a completion with the group ID',
      () async {
    final paths = <String>[];
    const plan =
        GroupWatchRequest(id: 'pg-plan', groupId: 'pg-group', userId: 'laura');
    await expectLater(
        http.runWithClient(
          () => GroupService.logGroupWatchPlan(plan, 'laura'),
          () => MockClient((request) async {
            paths.add(request.url.path);
            return http.Response('{"error":"Forbidden"}', 403);
          }),
        ),
        throwsException);
    expect(paths, ['/conversations/group']);
  });
  test('missing a screening sends watched false without diary details',
      () async {
    Map<String, dynamic>? body;
    const plan = GroupWatchRequest(
        id: 'plan', groupId: 'group', conversationId: 'chat', userId: 'laura');
    await http.runWithClient(
      () => GroupService.logGroupWatchPlan(plan, 'laura', watched: false),
      () => MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{"id":"plan"}', 200);
      }),
    );
    expect(body, {'userId': 'laura', 'watched': false});
  });
  test('missed group responses persist separately from watched responses', () {
    final plan = GroupWatchRequest.fromJson({
      'id': 'plan',
      'status': 'SCHEDULED',
      'responses': [
        {
          'responderId': 'laura',
          'status': 'ACCEPTED',
          'missedAt': '2026-09-11T12:00:00Z'
        },
      ],
    });
    expect(plan.hasMissedFor('laura'), isTrue);
    expect(plan.hasLoggedFor('laura'), isFalse);
    expect(plan.canCompleteFor('laura'), isFalse);
  });
}
