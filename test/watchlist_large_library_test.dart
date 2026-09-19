import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/auth/auth_service.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/watchlist_movie.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/core/auth/auth_prefetch_coordinator.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/movies/data/show_service.dart';
import 'package:flixie_app/models/watch_provider.dart';

http.Response jsonResponse(Object value, [int status = 200]) =>
    http.Response(jsonEncode(value), status,
        headers: {'content-type': 'application/json'});

class QuietAuthService extends Fake implements AuthService {
  @override
  Stream<firebase.User?> get authStateChanges => const Stream.empty();
  @override
  Future<String> refreshIdToken() async => 'fixture-token';
}

class SlowProviders extends MovieService {
  var active = 0;
  var maxActive = 0;
  final requested = <int>[];

  @override
  Future<List<WatchProvider>> getMovieWatchProviders(
      int id, String region) async {
    requested.add(id);
    active++;
    if (active > maxActive) maxActive = active;
    // Cross the previous ten-second whole-library cutoff on the first batch.
    if (id <= 5) await Future<void>.delayed(const Duration(seconds: 11));
    active--;
    if (id == 17) throw Exception('A single unavailable provider lookup');
    return [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('editing a 400-title list does not eagerly fetch all providers',
      () async {
    final auth = AuthProvider(QuietAuthService(), MovieService(),
        prefetchAfterAuth: false);
    addTearDown(auth.dispose);
    auth.updateCachedUser(const User(
        id: 'viewer',
        username: 'Viewer',
        email: '',
        iconColorId: 0,
        completedSetup: true,
        darkMode: true));
    var requests = 0;
    await http.runWithClient(() async {
      auth.updateUserList(
          movieWatchlist: List.generate(
              400,
              (i) => WatchlistMovie(
                  id: '$i',
                  userId: 'viewer',
                  movieId: i + 1,
                  movie: WatchlistMovieDetails(
                      id: i + 1, title: 'Film ${i + 1}'))));
      await Future<void>.delayed(Duration.zero);
      expect(auth.dbUser!.movieWatchlist!.length, 400);
      expect(requests, 0);
    },
        () => MockClient((request) async {
              requests++;
              return jsonResponse({'watchProviders': []});
            }));
  });

  test(
      '400 providers continue beyond ten seconds with bounded work and partial success',
      () async {
    final service = SlowProviders();
    final coordinator = AuthPrefetchCoordinator(movieService: service);
    final published = <int>{};
    await http.runWithClient(() async {
      final result = await coordinator.fetchWatchProviders(
          'viewer', List.generate(400, (i) => i + 1), region: 'GB',
          onProgress: (batch, subscriptions) {
        published.addAll(batch.keys);
        expect(subscriptions, isEmpty);
      });
      expect(service.requested, List.generate(400, (i) => i + 1));
      expect(service.maxActive, lessThanOrEqualTo(5));
      expect(result.providersByMovieId.length, 399);
      expect(published, containsAll([1, 5, 399, 400]));
      expect(published, isNot(contains(17)));
      expect(result.providersByMovieId[400], isEmpty);
    },
        () => MockClient((request) async {
              expect(request.url.path, '/users/viewer/watch-providers');
              return jsonResponse({'watchProviders': []});
            }));
  });

  for (final shows in [false, true]) {
    final kind = shows ? 'shows' : 'movies';
    final idsKey = shows ? 'showIds' : 'movieIds';
    test(
        '$kind publish early friends for 400 titles and retry a transient batch',
        () async {
      final nextBatch = Completer<void>();
      final firstPublished = Completer<void>();
      final ids = List.generate(400, (i) => i + 1);
      var calls = 0;
      var active = 0;
      var maxActive = 0;
      var retried = false;
      await http.runWithClient(() async {
        void onProgress(Map<int, dynamic> results) {
          if (results.containsKey(1) && !firstPublished.isCompleted) {
            firstPublished.complete();
          }
        }

        final future = shows
            ? ShowService.getFriendRecommendations(ids, onProgress: onProgress)
            : MovieService()
                .getFriendRecommendations(ids, onProgress: onProgress);
        await firstPublished.future;
        expect(calls, lessThanOrEqualTo(2));
        nextBatch.complete();
        final results = await future;
        expect(results.length, 400);
        expect(results[400]!.friends.single.username, 'Friend');
        expect(results[400]!.friends.single.profileBadges, ['FOUNDER']);
        expect(calls, 17); // 16 batches plus one transient retry.
        expect(maxActive, 1);
      },
          () => MockClient((request) async {
                expect(request.url.path, '/$kind/friend-recommendations');
                final batch =
                    (jsonDecode(request.body)[idsKey] as List).cast<int>();
                expect(batch.length, lessThanOrEqualTo(25));
                calls++;
                active++;
                if (active > maxActive) maxActive = active;
                if (batch.first == 26) await nextBatch.future;
                active--;
                if (batch.first == 26 && !retried) {
                  retried = true;
                  return jsonResponse({'message': 'Busy'}, 503);
                }
                return jsonResponse({
                  'items': [
                    for (final id in batch)
                      {
                        'movieId': '$id',
                        'recommendPercent': 100,
                        'friendCount': 1,
                        'recommendedCount': 1,
                        'friends': [
                          {
                            'userId': 'friend',
                            'username': 'Friend',
                            'watched': true,
                            'recommends': true,
                            'profileBadges': ['FOUNDER']
                          }
                        ]
                      }
                  ]
                });
              }));
    });
  }
}
