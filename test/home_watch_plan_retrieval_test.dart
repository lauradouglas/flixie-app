import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/features/social/data/request_service.dart';

Map<String, dynamic> plan(String id) => {
      'id': id,
      'type': 'MOVIE_WATCH_REQUEST',
      'requesterId': 'laura',
      'recipientId': 'jamie',
      'status': 'ACCEPTED',
      'candidates': [],
      'watchConfirmations': [],
      'scheduleProposals': [],
    };

void main() {
  test('complete Home lists need one HTTP request regardless of plan count',
      () async {
    final paths = <String>[];
    final result = await http.runWithClient(
      () => RequestService.getWatchRequests('laura', includeHomeState: true),
      () => MockClient((request) async {
        paths.add(request.url.path);
        return http.Response(
            jsonEncode(List.generate(20, (i) => plan('$i'))), 200);
      }),
    );
    expect(result, hasLength(20));
    expect(paths, ['/requests/laura/all']);
  });

  test('list retains a new proposal even when the previous schedule is past',
      () async {
    final result = await http.runWithClient(
      () => RequestService.getWatchRequests('laura', includeHomeState: true),
      () => MockClient((request) async => http.Response(
          jsonEncode([
            {
              ...plan('rescheduled'),
              'scheduledFor': '2026-01-01T20:00:00Z',
              'scheduleStatus': 'PROPOSED',
              'scheduleProposals': [
                {
                  'id': 'new-time',
                  'proposerId': 'jamie',
                  'proposedFor': '2027-01-01T20:00:00Z',
                  'status': 'PENDING',
                }
              ],
            }
          ]),
          200)),
    );
    expect(result.single.latestPendingProposal?.id, 'new-time');
    expect(result.single.canRespondToProposal('laura'), isTrue);
  });

  test('older servers hydrate only plans missing Home fields', () async {
    final paths = <String>[];
    final result = await http.runWithClient(
      () => RequestService.getWatchRequests('laura', includeHomeState: true),
      () => MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path == '/requests/laura/all') {
          final legacy = plan('legacy')..remove('scheduleProposals');
          return http.Response(jsonEncode([plan('complete'), legacy]), 200);
        }
        return http.Response(
            jsonEncode({
              'request': {...plan('legacy'), 'location': 'Updated location'},
              'needsWatchConfirmation': false,
              'hasCurrentUserLoggedWatch': false,
            }),
            200);
      }),
    );
    expect(paths, ['/requests/laura/all', '/watch-requests/legacy/state']);
    expect(result.last.location, 'Updated location');
  });

  test('failed list request remains an error instead of an empty plan list',
      () async {
    await expectLater(
      http.runWithClient(
        () => RequestService.getWatchRequests('laura', includeHomeState: true),
        () => MockClient(
            (_) async => http.Response('{"error":"Unavailable"}', 503)),
      ),
      throwsException,
    );
  });
}
