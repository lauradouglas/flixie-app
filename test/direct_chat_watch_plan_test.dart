import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/features/social/presentation/widgets/watch_request_chat_card.dart';
import 'package:flixie_app/models/conversation.dart';
import 'support/api_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/social/data/request_service.dart';
import 'package:flixie_app/models/group_watch_request.dart';

void main() {
  testWidgets('I am in sends ACCEPTED and refreshes the direct plan card',
      (tester) async {
    var status = 'PENDING';
    var replies = 0;
    useApiFixture(MockClient((request) async {
      if (request.url.path == '/requests/update') {
        final body = jsonDecode(request.body) as Map;
        expect(body['id'], 'friend-plan');
        expect(body['status'], 'ACCEPTED');
        expect(body['acceptProposedTime'], isTrue);
        status = body['status'] as String;
        replies++;
        return http.Response('{}', 200);
      }
      expect(request.url.path, '/watch-requests/friend-plan/state');
      return http.Response(
          jsonEncode({
            'request': {
              'id': 'friend-plan',
              'requesterId': 'creator',
              'status': status,
              'movie': {'title': 'Alien'},
              'participants': [
                {
                  'user': {'id': 'friend', 'username': 'Robin'},
                  'status': status
                },
              ],
            }
          }),
          200);
    }));
    var plan = await RequestService.getChatWatchPlan('friend-plan', 'friend');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
      child: StatefulBuilder(
          builder: (context, setState) => WatchRequestChatCard(
            isResponding: false,
                msg: ChatMessage(
                    id: 'fixture-message',
                    senderId: 'creator',
                    text: '',
                    createdAt: DateTime(2026, 10, 5)),
                cachedRequest: plan,
                currentUserId: 'friend',
                onTap: () {},
                onAccept: () async {
                  await RequestService.respondToDirectWatchPlan(
                      plan.id, WatchResponseDecision.accepted);
                  final updated =
                      await RequestService.getChatWatchPlan(plan.id, 'friend');
                  setState(() => plan = updated);
                },
              )),
    ))));
    await tester.pumpAndSettle();
    expect(find.text("I'm in"), findsOneWidget);
    await tester.tap(find.text("I'm in"));
    await tester.pumpAndSettle();
    expect(replies, 1);
    expect(plan.currentUserResponse, WatchResponseDecision.accepted);
    expect(find.text("I'm in"), findsNothing);
    expect(find.text('Your reply needed'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final decision in [
    WatchResponseDecision.declined,
    WatchResponseDecision.maybe
  ]) {
    test('direct chat sends uppercase ${decision.apiValue}', () async {
      useApiFixture(MockClient((request) async {
        expect(jsonDecode(request.body)['status'], decision.apiValue);
        return http.Response('{}', 200);
      }));
      await RequestService.respondToDirectWatchPlan('friend-plan', decision);
    });
  }

  test('direct plan state supplies chat status, participants and badge data',
      () {
    final plan = RequestService.chatPlanFromState({
      'request': {
        'id': 'friend-plan',
        'requesterId': 'creator',
        'status': 'accepted',
        'movie': {'title': 'Spider-Man', 'posterPath': '/poster.jpg'},
        'participants': [
          {
            'user': {
              'id': 'friend',
              'username': 'Jamie',
              'profileBadges': ['founder']
            },
            'response': 'accepted'
          },
        ],
        'scheduleProposals': [
          {
            'id': 'time',
            'proposerId': 'creator',
            'status': 'PENDING',
            'proposedFor': '2026-10-01T19:00:00Z'
          },
        ],
      },
    }, 'friend');
    expect(plan.id, 'friend-plan');
    expect(plan.status, WatchRequestStatus.accepted);
    expect(plan.movieTitle, 'Spider-Man');
    expect(plan.currentUserResponse, WatchResponseDecision.accepted);
    expect(plan.memberStatuses.single.profileBadges, ['founder']);
    expect(plan.activeScheduleProposal?.id, 'time');
  });
}
