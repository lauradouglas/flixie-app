import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/core/auth/auth_prefetch_coordinator.dart';
import 'package:flixie_app/core/storage/movie_cache_service.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/home/data/trending_service.dart';
import 'package:flixie_app/features/social/data/friend_service.dart';
import 'package:flixie_app/features/social/presentation/controllers/friend_actions_controller.dart';

void main() {
  testWidgets(
      'prefetch and Home share trending and the same friends feed request',
      (tester) async {
    MovieCacheService().clearCache();
    var trends = 0, feeds = 0;
    final trending = Completer<http.Response>(),
        friends = Completer<http.Response>();
    http.Response response(Object data) => http.Response(jsonEncode(data), 200,
        headers: {'content-type': 'application/json'});
    await http.runWithClient(() async {
      final prefetch = AuthPrefetchCoordinator(movieService: MovieService())
          .prefetch('overlap-fixture');
      final home = TrendingService.getTrendingMovies().then((_) =>
          FriendService.getFriendsActivityLists('overlap-fixture',
              days: 30, limit: 200));
      await tester.pump();
      expect(trends, 1);
      expect(feeds, 0);
      trending.complete(response([
        {'id': 1, 'title': 'Fixture'}
      ]));
      await tester.pump();
      expect(feeds, 1);
      friends.complete(response([]));
      await tester.pump();
      await Future.wait([prefetch, home]);
      expect(trends, 1);
      expect(feeds, 1);
    },
        () => MockClient((request) async {
              if (request.url.path.contains('/trending/')) {
                trends++;
                return await trending.future;
              }
              if (request.url.path.endsWith('/activity-lists')) {
                feeds++;
                return await friends.future;
              }
              if (request.url.path == '/friends/overlap-fixture') {
                return response({
                  'friendships': [],
                  'requestedFriends': [],
                  'pendingFriends': []
                });
              }
              return response([]);
            }));
  });
  testWidgets('original differing friends-feed limits produce two requests',
      (tester) async {
    var calls = 0;
    final held = Completer<http.Response>();
    await http.runWithClient(() async {
      final baseline = const FriendActionsController()
          .getFriendsActivityLists('baseline-overlap');
      final home = FriendService.getFriendsActivityLists('baseline-overlap',
          days: 30, limit: 200);
      await tester.pump();
      expect(calls, 2);
      held.complete(http.Response('[]', 200));
      await tester.pump();
      await Future.wait([baseline, home]);
    },
        () => MockClient((request) async {
              calls++;
              return await held.future;
            }));
  });
}
