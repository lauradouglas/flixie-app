import 'dart:convert' show jsonDecode;
import 'package:http/http.dart' as http;
import 'watch_plan_fixture.dart';

/// Four-member UI fixture. SQL/notification behavior is tested independently by
/// the backend's guarded test-group-watch-plans-e2e.ts runner.
class GroupWatchPlanFixture extends WatchPlanFixture {
  GroupWatchPlanFixture(
      {bool creator = false, bool multiple = false, bool invited = false})
      : super(status: 'ACCEPTED') {
    final owner = creator ? viewer : robin;
    plan.addAll({
      'groupId': 'fixture-group',
      'userId': owner,
      'requesterId': owner,
      'status': invited ? 'OPEN' : 'ACCEPTED',
      'hasCurrentUserAccepted': !invited,
      'currentUserResponse': invited ? 'pending' : 'accepted',
      'movieId': 348,
      'movie': {'id': 348, 'title': 'Alien'},
      'selectedCandidateId': multiple ? null : 'alien',
      'memberStatuses': [
        for (final id in members)
          {
            'memberId': id,
            'status': invited && id == viewer ? 'PENDING' : 'ACCEPTED'
          }
      ],
      'scheduleProposals': <Map<String, dynamic>>[],
      'candidates': [
        option('alien', 348, 'Alien', owner),
        if (multiple) option('odyssey', 1368337, 'The Odyssey', owner)
      ],
    });
  }
  static const viewer = 'store-viewer',
      robin = 'fixture-robin',
      ellis = 'fixture-ellis',
      blair = 'fixture-blair';
  static const members = [viewer, robin, ellis, blair];
  List<dynamic> get options => plan['candidates'] as List;
  List<dynamic> get statuses => plan['memberStatuses'] as List;
  List<dynamic> get proposals => plan['scheduleProposals'] as List;
  Map<String, dynamic> option(
          String id, int movieId, String title, String adder) =>
      {
        'id': id,
        'movieId': movieId,
        'movie': {'id': movieId, 'title': title},
        'addedByUserId': adder,
        'choices': <Map<String, dynamic>>[
          {'userId': adder}
        ]
      };
  void schedule({bool dateOnly = false}) {
    plan.addAll({
      'status': 'SCHEDULED',
      'scheduledFor': '2099-07-10T18:30:00.000Z',
      'scheduledDateOnly': dateOnly
    });
    if (dateOnly) plan['scheduledFor'] = '2099-07-10T12:00:00.000Z';
  }

  void proposal(
      {bool dateOnly = false,
      bool allOthersAccepted = true,
      bool allAccepted = false}) {
    proposals.add({
      'id': 'proposal',
      'proposerId': robin,
      'status': 'PENDING',
      'proposedFor':
          dateOnly ? '2099-07-11T12:00:00.000Z' : '2099-07-11T19:15:00.000Z',
      'dateOnly': dateOnly,
      'responses': [
        for (final id in members)
          {
            'userId': id,
            'status': allAccepted || (allOthersAccepted && id != viewer)
                ? 'ACCEPTED'
                : 'PENDING'
          }
      ]
    });
  }

  void decline(String userId) {
    for (final status in statuses) {
      if (status['memberId'] == userId) status['status'] = 'DECLINED';
    }
    for (final candidate in options) {
      (candidate['choices'] as List)
          .removeWhere((choice) => choice['userId'] == userId);
    }
    for (final proposal in proposals) {
      (proposal['responses'] as List)
          .removeWhere((response) => response['userId'] == userId);
    }
    if (userId == viewer) {
      plan['currentUserResponse'] = 'declined';
      plan['hasCurrentUserAccepted'] = false;
    }
  }

  @override
  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    if (!path.startsWith('/groups/') && path != '/search') {
      return super.handle(request);
    }
    calls.add('${request.method} $path');
    if (path == failNextPath) {
      failNextPath = null;
      return json({'message': 'Fixture temporarily unavailable'}, 503);
    }
    if (request.method == 'GET') {
      if (path == '/search') {
        return json({
          'page': 1,
          'totalPages': 1,
          'totalResults': 2,
          'results': [
            {'id': 348, 'title': 'Alien', 'mediaType': 'movie'},
            {'id': 1339713, 'title': 'Obsession', 'mediaType': 'movie'}
          ]
        });
      }
      if (path == '/groups/user/$viewer') {
        return json([
          {
            'id': 'fixture-group',
            'name': 'Four Film Friends',
            'ownerId': robin,
            'abbreviation': 'FFF'
          }
        ]);
      }
      if (path == '/groups/fixture-group/requests') return json([plan]);
      if (path == '/groups/fixture-group/members') {
        return json([
          for (final id in members)
            {
              'id': id,
              'groupId': 'fixture-group',
              'memberId': id,
              'role': id == plan['userId'] ? 'OWNER' : 'MEMBER',
              'inviteStatus': 'ACCEPTED',
              'user': {
                'id': id,
                'username': {
                  viewer: 'Casey',
                  robin: 'Robin',
                  ellis: 'Ellis',
                  blair: 'Blair'
                }[id],
                'profileBadges': []
              }
            }
        ]);
      }
    }
    final body = request.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(request.body) as Map<String, dynamic>;
    if (path == '/groups/fixture-group/send-request' &&
        request.method == 'POST') {
      writes.add(body);
      plan.addAll({
        'proposedDate': body['proposedDate'],
        'proposedDateOnly': body['proposedDateOnly'],
        'status': 'OPEN'
      });
      return json({});
    }
    if (path == '/groups/request/patrol-plan/response' &&
        request.method == 'PUT') {
      writes.add(body);
      if (body['status'] == 'DECLINED') {
        decline(body['memberId'] as String);
      } else {
        for (final s in statuses) {
          if (s['memberId'] == body['memberId']) s['status'] = body['status'];
        }
        plan['hasCurrentUserAccepted'] = true;
        plan['currentUserResponse'] = 'accepted';
      }
      return json(plan);
    }
    if (path == '/groups/request/patrol-plan/candidates' &&
        request.method == 'POST') {
      writes.add(body);
      options.add(
          option('obsession', 1339713, 'Obsession', body['userId'] as String));
      return json(plan);
    }
    if (path == '/groups/request/patrol-plan/candidate-choices' &&
        request.method == 'PUT') {
      writes.add(body);
      for (final candidate in options) {
        final choices = (candidate['choices'] as List)
            .map((c) => Map<String, dynamic>.from(c as Map))
            .toList()
          ..removeWhere((c) => c['userId'] == body['userId']);
        if ((body['candidateIds'] as List).contains(candidate['id'])) {
          choices.add({'userId': body['userId']});
        }
        candidate['choices'] = choices;
      }
      return json(plan);
    }
    if (path == '/groups/request/patrol-plan/select-candidate' &&
        request.method == 'POST') {
      writes.add(body);
      final choice = options.singleWhere((c) => c['id'] == body['candidateId']);
      plan.addAll({
        'selectedCandidateId': choice['id'],
        'movieId': choice['movieId'],
        'movie': choice['movie']
      });
      return json(plan);
    }
    if (path == '/groups/request/patrol-plan/reopen-candidate-selection' &&
        request.method == 'POST') {
      writes.add(body);
      plan['selectedCandidateId'] = null;
      return json(plan);
    }
    if (path == '/groups/request/patrol-plan/schedule-proposals' &&
        request.method == 'POST') {
      writes.add(body);
      proposals.clear();
      proposals.add({
        'id': 'proposal',
        'proposerId': body['userId'],
        'proposedFor': body['proposedFor'],
        'dateOnly': body['dateOnly'],
        'status': 'PENDING',
        'responses': [
          for (final s in statuses.where((s) => s['status'] != 'DECLINED'))
            {
              'userId': s['memberId'],
              'status': s['memberId'] == body['userId'] &&
                      plan['scheduledFor'] == null
                  ? 'ACCEPTED'
                  : 'PENDING'
            }
        ]
      });
      return json(plan);
    }
    if (path.endsWith('/schedule-proposals/proposal/respond') &&
        request.method == 'POST') {
      writes.add(body);
      final proposal = proposals.last;
      for (final response in proposal['responses'] as List) {
        if (response['userId'] == body['userId']) {
          response['status'] = (body['decision'] as String).toUpperCase();
        }
      }
      if (body['decision'] == 'declined') {
        proposal['status'] = 'DECLINED';
      } else if (plan['scheduledFor'] == null &&
          (proposal['responses'] as List)
              .every((r) => r['status'] == 'ACCEPTED')) {
        proposal['status'] = 'ACCEPTED';
        plan.addAll({
          'status': 'SCHEDULED',
          'scheduledFor': proposal['proposedFor'],
          'scheduledDateOnly': proposal['dateOnly']
        });
      }
      return json(plan);
    }
    if (path.endsWith('/schedule-proposals/proposal/finalize') &&
        request.method == 'POST') {
      writes.add(body);
      final proposal = proposals.last;
      proposal['status'] =
          body['decision'] == 'accept_new' ? 'ACCEPTED' : 'CANCELLED';
      if (body['decision'] == 'accept_new') {
        plan.addAll({
          'status': 'SCHEDULED',
          'scheduledFor': proposal['proposedFor'],
          'scheduledDateOnly': proposal['dateOnly']
        });
      }
      return json(plan);
    }
    unexpected.add('${request.method} $path');
    return json({'message': 'Unexpected fixture request'}, 404);
  }
}
