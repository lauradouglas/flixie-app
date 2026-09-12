import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/watchlist_movie.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/watchlist/presentation/pages/watchlist_screen.dart';

Map<String, dynamic> item(int id) => {
      'movieId': '$id',
      'recommendPercent': 0,
      'friendCount': 0,
      'recommendedCount': 0,
      'friends': []
    };
http.Response response(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

class TestAuth extends ChangeNotifier implements AuthProvider {
  List<int> ids = [1];
  @override
  int activityVersion = 0;
  @override
  int friendDataVersion = 0;
  @override
  User get dbUser => User(
      id: 'viewer',
      username: 'Me',
      email: '',
      iconColorId: 0,
      completedSetup: true,
      darkMode: true,
      movieWatchlist: ids
          .map((id) => WatchlistMovie(
              id: '$id',
              userId: 'viewer',
              movieId: id,
              movie: WatchlistMovieDetails(id: id, title: 'Film $id')))
          .toList());
  @override
  Map<int, List<WatchProvider>> get cachedWatchProvidersByMovieId =>
      {for (final id in ids) id: []};
  @override
  Set<int> get cachedUserWatchProviderIds => {};
  @override
  Future<void> ensureWatchProviderCache({Iterable<int>? movieIds}) async {}
  @override
  Future<void> refreshUserData() async {
    notifyListeners();
  }

  void notifyOnly() => notifyListeners();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test('HTTP counts, batch bounds, deduplication and partial failures',
      () async {
    for (final size in [0, 1, 25, 26, 100, 251]) {
      var beforeCalls = 0;
      await http.runWithClient(() async {
        await Future.wait(List.generate(
            size, (i) => MovieService().getFriendRecommendation(i + 1)));
      },
          () => MockClient((request) async {
                beforeCalls++;
                return response(item(1));
              }));
      expect(beforeCalls, size);
      var calls = 0;
      await http.runWithClient(() async {
        final result = await MovieService()
            .getFriendRecommendations(List.generate(size, (i) => i + 1));
        expect(result.length, size);
      },
          () => MockClient((request) async {
                calls++;
                expect(request.url.path, '/movies/friend-recommendations');
                final ids =
                    (jsonDecode(request.body)['movieIds'] as List).cast<int>();
                expect(ids.length, lessThanOrEqualTo(25));
                return response({'items': ids.map(item).toList()});
              }));
      expect(calls, (size / 25).ceil());
      debugPrint('films=$size legacyHTTP=$beforeCalls batchHTTP=$calls');
    }
    var calls = 0;
    await http.runWithClient(() async {
      final result = await MovieService()
          .getFriendRecommendations([...List.generate(51, (i) => i + 1), 1]);
      expect(result.keys, containsAll([1, 25, 51]));
      expect(result.length, 26);
    },
        () => MockClient((request) async {
              calls++;
              if (calls == 2) return response({'message': 'Unavailable'}, 503);
              final ids =
                  (jsonDecode(request.body)['movieIds'] as List).cast<int>();
              return response({'items': ids.map(item).toList()});
            }));
    expect(calls, 3);
  });

  test(
      'obsolete loads stop before the next chunk and malformed items stay isolated',
      () async {
    var current = true;
    var calls = 0;
    await http.runWithClient(() async {
      final result = await MovieService().getFriendRecommendations(
          List.generate(51, (i) => i + 1),
          isCurrent: () => current);
      expect(calls, 1);
      expect(result.keys, [1]);
      expect(result[1]!.friends.single.profileBadges, ['FOUNDER']);
    },
        () => MockClient((request) async {
              calls++;
              current = false;
              return response({
                'items': [
                  {
                    ...item(1),
                    'friends': [
                      {
                        'userId': 'friend',
                        'username': 'Friend',
                        'recommends': true,
                        'profileBadges': ['FOUNDER']
                      }
                    ]
                  },
                  {'movieId': '2'},
                ]
              });
            }));
  });

  test('authorization failure stops the remaining batches', () async {
    var calls = 0;
    await http.runWithClient(() async {
      await expectLater(
          MovieService()
              .getFriendRecommendations(List.generate(51, (i) => i + 1)),
          throwsException);
    },
        () => MockClient((request) async {
              calls++;
              return response({'message': 'Forbidden'}, 403);
            }));
    expect(calls, 1);
  });

  testWidgets(
      'notification-only updates do not reload; lists, friends, activity and explicit refresh do',
      (tester) async {
    final auth = TestAuth();
    addTearDown(auth.dispose);
    var batches = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth, child: const MaterialApp(home: WatchlistScreen())));
      await tester.pumpAndSettle();
      expect(batches, 1);
      for (var i = 0; i < 10; i++) {
        auth.notifyOnly();
      }
      await tester.pumpAndSettle();
      expect(batches, 1);
      auth.ids = [1, 2];
      auth.notifyOnly();
      await tester.pumpAndSettle();
      expect(batches, 2);
      auth.ids = [2];
      auth.notifyOnly();
      await tester.pumpAndSettle();
      expect(batches, 3);
      auth.friendDataVersion++;
      auth.notifyOnly();
      await tester.pumpAndSettle();
      expect(batches, 4);
      auth.activityVersion++;
      auth.notifyOnly();
      await tester.pumpAndSettle();
      expect(batches, 5);
      await tester.tap(find.byTooltip('Refresh watchlist'));
      await tester.pumpAndSettle();
      expect(batches, 6);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(batches, 7);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path == '/movies/friend-recommendations') {
                batches++;
                final ids =
                    (jsonDecode(request.body)['movieIds'] as List).cast<int>();
                return response({'items': ids.map(item).toList()});
              }
              return response({'watchProviders': []});
            }));
  });
}
