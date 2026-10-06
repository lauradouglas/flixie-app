import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'store_screenshot_fixture.dart';

/// Isolated, stateful API double. Unexpected requests fail the test, rather than
/// returning a permissive empty response that could hide a broken integration.
class WatchPlanFixture {
  WatchPlanFixture({String status = 'PENDING', bool scheduled = false}) {
    plan = {
      ...screenshotPlan,
      'id': 'patrol-plan',
      'requesterId': 'fixture-robin',
      'recipientId': 'store-viewer',
      'requester': {
        'id': 'fixture-robin',
        'username': 'Robin',
        'profileBadges': []
      },
      'recipient': screenshotPerson,
      'status': status,
      'hasCurrentUserAccepted': status != 'PENDING',
      'scheduledFor': scheduled ? '2099-10-08T12:00:00.000Z' : null,
      'scheduledDateOnly': scheduled,
      'scheduleStatus': scheduled ? 'AGREED' : 'UNSCHEDULED',
      'proposedDate': null,
      'movie': {'id': 348, 'title': 'Alien', 'runtime': 117},
      'selectedCandidateId': 'alien',
      'candidates': [
        {
          'id': 'alien',
          'movieId': 348,
          'movie': {'id': 348, 'title': 'Alien'},
          'addedByUserId': 'fixture-robin',
          'choices': []
        }
      ],
      'location': null,
    };
    client = MockClient(handle);
  }
  late Map<String, dynamic> plan;
  late final http.Client client;
  final calls = <String>[];
  final unexpected = <String>[];
  final writes = <Map<String, dynamic>>[];
  final diary = <String, Map<String, dynamic>>{};
  final searches = <Map<String, String>>[];
  String? failNextPath;
  bool failRatingSync = false;

  Map<String, dynamic> get state => {
        'request': plan,
        'needsWatchConfirmation': false,
        'hasCurrentUserLoggedWatch': diary.isNotEmpty,
      };
  http.Response json(Object? value, [int status = 200]) =>
      http.Response(jsonEncode(value), status,
          headers: {'content-type': 'application/json'});

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    final call = '${request.method} $path';
    calls.add(call);
    if (path == failNextPath) {
      failNextPath = null;
      return json({'message': 'Fixture temporarily unavailable'}, 503);
    }
    if (request.method == 'GET') {
      if (path == '/friends/store-viewer') {
        return json({
          'friendships': [
            {
              'id': 'fictional-friendship',
              'friend': {
                'id': 'fixture-robin',
                'username': 'Robin',
                'profileBadges': []
              },
            }
          ],
          'pendingFriends': [],
          'requestedFriends': [],
        });
      }
      if (path == '/search') {
        searches.add(request.url.queryParameters);
        return json({
          'page': 1,
          'totalPages': 1,
          'totalResults': 2,
          'results': [
            {'id': 348, 'title': 'Alien', 'mediaType': 'movie'},
            {'id': 1339713, 'title': 'Obsession', 'mediaType': 'movie'},
          ]
        });
      }
      if (path == '/watch-requests/patrol-plan/state') return json(state);
      if (path == '/requests/store-viewer/all') return json([plan]);
      if (path == '/groups/user/store-viewer') return json([]);
      if (path == '/movies/348/GB/watch/providers') return json([]);
      if (path == '/users/store-viewer/watch-providers' ||
          path == '/users/fixture-robin/watch-providers') {
        return json({'watchProviders': []});
      }
      if (path == '/groups/fixture-group/requests') return json([plan]);
      if (path == '/groups/fixture-group/members') {
        return json([
          for (final id in ['fixture-robin', 'store-viewer'])
            {
              'groupId': 'fixture-group',
              'memberId': id,
              'role': 'MEMBER',
              'inviteStatus': 'ACCEPTED',
              'user': {
                'id': id,
                'username': id == 'store-viewer' ? 'Casey' : 'Robin',
                'profileBadges': []
              }
            },
        ]);
      }
    }
    if (request.method == 'POST' &&
        path == '/watch-requests/patrol-plan/candidates') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      writes.add(body);
      final candidates = (plan['candidates'] as List)
          .map((candidate) => Map<String, dynamic>.from(candidate as Map))
          .toList();
      plan['candidates'] = candidates;
      if (body['movieId'] != 1339713 ||
          candidates.any((c) => c['movieId'] == body['movieId'])) {
        return json({'message': 'Invalid or duplicate fixture movie'}, 409);
      }
      candidates.add({
        'id': 'obsession',
        'movieId': 1339713,
        'movie': {'id': 1339713, 'title': 'Obsession'},
        'addedByUserId': body['userId'],
        'choices': [
          {'userId': body['userId']}
        ]
      });
      return json(plan);
    }
    if (request.method == 'PUT' &&
        (path == '/groups/request/patrol-plan/candidate-choices' ||
            path == '/watch-requests/patrol-plan/candidate-choices')) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      writes.add(body);
      for (final candidate in plan['candidates'] as List) {
        final choices = (candidate['choices'] as List)
            .map((choice) => Map<String, dynamic>.from(choice as Map))
            .toList()
          ..removeWhere((c) => c['userId'] == body['userId']);
        candidate['choices'] = choices;
        if ((body['candidateIds'] as List).contains(candidate['id'])) {
          choices.add({'userId': body['userId']});
        }
      }
      return json(plan);
    }
    if (request.method == 'POST' &&
        (path == '/groups/request/patrol-plan/select-candidate' ||
            path == '/watch-requests/patrol-plan/select-candidate')) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      writes.add(body);
      final movie = (plan['candidates'] as List)
          .singleWhere((c) => c['id'] == body['candidateId']);
      plan['selectedCandidateId'] = movie['id'];
      plan['movieId'] = movie['movieId'];
      plan['movie'] = movie['movie'];
      return json(plan);
    }
    if (request.method == 'POST' && path == '/requests') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      writes.add(body);
      plan = {...plan, ...body, 'status': 'PENDING'};
      return json({'request': plan});
    }
    if (request.method == 'PUT' &&
        path == '/groups/request/patrol-plan/response') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      writes.add(body);
      plan['memberStatuses'] = [
        {
          'memberId': 'store-viewer',
          'status': body['status'].toString().toUpperCase()
        }
      ];
      plan['hasCurrentUserAccepted'] = body['status'] == 'ACCEPTED';
      plan['status'] = 'ACCEPTED';
      return json(plan);
    }
    if (request.method == 'POST' && path == '/requests/update') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      writes.add(body);
      plan['status'] = body['status'];
      plan['hasCurrentUserAccepted'] = body['status'] == 'ACCEPTED';
      return json(plan);
    }
    if (request.method == 'POST' &&
        path == '/watch-requests/patrol-plan/schedule-proposals') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      writes.add(body);
      plan['scheduleProposals'] = [
        {
          'id': 'proposal',
          'proposerId': body['userId'],
          'status': 'PENDING',
          'proposedFor': body['proposedFor'],
          'dateOnly': body['dateOnly'],
          'location': body['location'],
        }
      ];
      return json(state);
    }
    if (request.method == 'PATCH' &&
        path ==
            '/watch-requests/patrol-plan/schedule-proposals/proposal/respond') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      writes.add(body);
      final proposal = (plan['scheduleProposals'] as List).single as Map;
      proposal['status'] = body['decision'].toString().toUpperCase();
      if (body['decision'] == 'accepted') {
        plan['scheduledFor'] = proposal['proposedFor'];
        plan['scheduledDateOnly'] = proposal['dateOnly'];
        plan['scheduleStatus'] = 'AGREED';
      }
      return json(state);
    }
    if (request.method == 'POST' &&
        path == '/watch-requests/patrol-plan/watch-confirmations') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      writes.add(body);
      if (body['watched'] == true) diary[body['userId'] as String] = body;
      plan['watchConfirmations'] = [
        {
          ...body,
          'id': 'fixture-entry',
          'reviewText': body['reviewText'],
        }
      ];
      plan['status'] = 'COMPLETED';
      return json(state);
    }
    if (request.method == 'POST' && path == '/movies/348/user/rating') {
      if (failRatingSync) return json({'message': 'Sync unavailable'}, 503);
      return json({'rating': diary.values.firstOrNull?['rating']});
    }
    unexpected.add(call);
    throw StateError('Unconfigured watch-plan API: $call');
  }

  void proposeByRobin({bool dateOnly = true}) {
    plan['scheduleProposals'] = [
      {
        'id': 'proposal',
        'proposerId': 'fixture-robin',
        'status': 'PENDING',
        'proposedFor': '2099-10-09T12:00:00.000Z',
        'dateOnly': dateOnly,
      }
    ];
  }
}
