import 'package:flixie_app/features/social/data/request_service.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/models/watch_request.dart';
import 'package:flixie_app/features/movies/data/movie_watch_plan_choice.dart';
import 'package:flixie_app/features/home/presentation/models/home_watch_plan_state.dart';
import '../../support/api_fixture.dart';

void main() {
  test('plan comments and spoiler reviews use independent fields', () async {
    Map? body;
    useApiFixture(MockClient((request) async {
      if (request.method == 'POST') body = jsonDecode(request.body) as Map;
      return http.Response(
          jsonEncode({
            'request': {
              'id': 'plan',
              'requesterId': 'viewer',
              'recipientId': 'sophie',
              'movieId': 348,
              'message': '',
              'status': 'ACCEPTED',
              'type': 'MOVIE_WATCH_REQUEST'
            }
          }),
          200);
    }));
    await RequestService.confirmWatchRequest(
        watchRequestId: 'plan',
        userId: 'viewer',
        watched: true,
        rating: 8,
        recommended: true,
        reviewText: 'A spoiler-aware review',
        watchComment: 'Late cinema trip with Sophie',
        publishReview: true,
        containsSpoilers: true);
    expect(body!['watchComment'], 'Late cinema trip with Sophie');
    expect(body!['reviewText'], 'A spoiler-aware review');
    expect(body!['containsSpoilers'], isTrue);
    final confirmation = WatchConfirmation.fromJson({
      'id': 'response',
      'userId': 'viewer',
      'watched': true,
      'watchEntry': {
        'notes': 'Late cinema trip with Sophie',
        'reviews': [
          {'body': 'A spoiler-aware review', 'containsSpoilers': true}
        ]
      }
    });
    expect(confirmation.watchComment, 'Late cinema trip with Sophie');
    expect(confirmation.reviewBody, 'A spoiler-aware review');
    expect(confirmation.reviewContainsSpoilers, isTrue);
  });

  test(
      'new and edited logs carry companion, unknown date and spoiler review in a single write',
      () async {
    final calls = <http.Request>[];
    useApiFixture(MockClient((r) async {
      calls.add(r);
      return http.Response(
          jsonEncode({
            'id': 'watch',
            'userId': 'viewer',
            'movieId': 348,
            'removed': false,
            'watchedAt': null,
            'rating': 8,
            'watchPlanConfirmations': [
              {
                'request': {
                  'id': 'plan',
                  'requesterId': 'viewer',
                  'recipientId': 'sophie',
                  'recipient': {
                    'id': 'sophie',
                    'username': 'Sophie',
                    'profileBadges': [
                      {'badge': 'EARLY_ADOPTER'}
                    ]
                  }
                }
              }
            ],
            'reviews': [
              {'body': 'A review', 'containsSpoilers': true}
            ]
          }),
          200,
          headers: {'content-type': 'application/json'});
    }));
    const draft = '5ffceafb-b744-405a-b640-ad9c98083fb2';
    final saved = await UserService.logMovieWatch(
        'viewer',
        const LogMovieWatchRequest(
            movieId: 348,
            draftId: draft,
            companionId: 'sophie',
            reviewBody: 'A review',
            containsSpoilers: true,
            rating: 8,
            recommended: true));
    expect(calls.single.url.path, '/watch-requests/log-watch');
    final body = jsonDecode(calls.single.body) as Map;
    expect(body['watchedAt'], isNull);
    expect(body.containsKey('watchedAt'), isTrue);
    expect(body['companionId'], 'sophie');
    expect(body['containsSpoilers'], isTrue);
    expect(saved.companion!.profileBadges, contains('EARLY_ADOPTER'));
    expect(saved.reviewContainsSpoilers, isTrue);
    final copied = MovieWatchEntry.fromJson(saved.toJson());
    expect(copied.companion!.profileBadges, contains('EARLY_ADOPTER'));
    expect(copied.planId, 'plan');
    await UserService.updateMovieWatch(
        'viewer',
        'watch',
        const UpdateMovieWatchRequest(
            movieId: 348,
            draftId: draft,
            rating: 8,
            recommended: true,
            reviewBody: 'Updated'));
    expect(calls, hasLength(2));
    expect(jsonDecode(calls.last.body)['watchEntryId'], 'watch');
  });
  test(
      'undated lightweight plans can be linked without agreement and Home distinguishes each person',
      () {
    WatchRequest plan(List<WatchConfirmation> confirmations) => WatchRequest(
        id: 'p',
        requesterId: 'viewer',
        recipientId: 'sophie',
        movieId: 348,
        status: 'ACCEPTED',
        type: 'MOVIE_WATCH_REQUEST',
        lightweight: true,
        watchConfirmations: confirmations);
    expect(MovieWatchPlanChoice.canLinkDirect(plan([]), 'viewer', 348), isTrue);
    expect(selectHomeWatchPlanState([plan([])], 'viewer')!.type,
        HomeWatchPlanStateType.planning);
    expect(
        selectHomeWatchPlanState([
          plan([
            const WatchConfirmation(id: 'c', userId: 'viewer', watched: true)
          ])
        ], 'viewer')!
            .type,
        HomeWatchPlanStateType.waitingForLogs);
    expect(
        selectHomeWatchPlanState([
          plan([
            const WatchConfirmation(id: 'c', userId: 'sophie', watched: true)
          ])
        ], 'viewer')!
            .type,
        HomeWatchPlanStateType.logAfterOther);
  });
}
