import 'support/watchlist_auth.dart';
export 'support/watchlist_auth.dart' show TestAuth;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
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
              if ((jsonDecode(request.body)['movieIds'] as List).first == 26) {
                return response({'message': 'Unavailable'}, 503);
              }
              final ids =
                  (jsonDecode(request.body)['movieIds'] as List).cast<int>();
              return response({'items': ids.map(item).toList()});
            }));
    expect(calls, 4);
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

  testWidgets('400 cards load one page, show friends early, then load on scroll',
      (tester) async {
    final auth = TestAuth()..ids = List.generate(400, (i) => i + 1);
    addTearDown(auth.dispose);
    final gate = Completer<void>();
    auth.providerGate = gate.future;
    final batches = <List<int>>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth, child: const MaterialApp(home: WatchlistScreen())));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(batches.length, 1);
      expect(batches.single.length, 20);
      expect(auth.providerRequests.single.length, 20);
      final firstId = batches.first.first;
      final cards = tester.widgetList<WatchlistMovieRow>(find.byType(WatchlistMovieRow));
      final first = cards.firstWhere((row) => row.watchlistItem.movieId == firstId);
      expect(first.recommendations.single.username, 'Friend');
      expect(first.isLoadingFriends, isFalse);
      gate.complete();
      await tester.pumpAndSettle();
      expect(batches.length, 1);
      await tester.scrollUntilVisible(find.text('Film 21'), 500,
          scrollable: find.descendant(of: find.byKey(const ValueKey('watchlist-cards')),
              matching: find.byType(Scrollable)).first,
          maxScrolls: 60);
      await tester.pumpAndSettle();
      expect(batches.length, greaterThan(1));
      expect(batches.expand((batch) => batch).toSet().length, lessThanOrEqualTo(60));
      expect(auth.providerRequests.every((batch) => batch.length <= 20), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => MockClient((request) async {
      if (request.url.path == '/movies/friend-recommendations') {
        final ids = (jsonDecode(request.body)['movieIds'] as List).cast<int>();
        batches.add(ids);
        return response({'items': [for (final id in ids) {
          ...item(id), 'friends': [{'userId': 'friend', 'username': 'Friend',
            'watched': true, 'recommends': true}]
        }]});
      }
      return response({'watchProviders': []});
    }));
  });

  testWidgets('search reaches offscreen titles and friends filter checks the entire library',
      (tester) async {
    final auth = TestAuth()..ids = List.generate(400, (i) => i + 1);
    addTearDown(auth.dispose);
    final requested = <int>{};
    await http.runWithClient(() async {
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth, child: const MaterialApp(home: WatchlistScreen())));
      await tester.pumpAndSettle();
      expect(requested.length, 20);
      await tester.enterText(find.byType(TextField).first, 'Film 400');
      await tester.pumpAndSettle();
      expect(requested, contains(400));
      expect(requested.length, 21);
      expect(find.descendant(of: find.byType(WatchlistMovieRow),
          matching: find.text('Film 400')), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More watchlist filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Friends watched'));
      await tester.pumpAndSettle();
      expect(requested.length, 400);
      Navigator.of(tester.element(find.text('Friends watched'))).pop();
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(WatchlistMovieRow),
          matching: find.text('Film 400')), findsOneWidget);
      expect(find.text('Film 1'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => MockClient((request) async {
      if (request.url.path == '/movies/friend-recommendations') {
        final ids = (jsonDecode(request.body)['movieIds'] as List).cast<int>();
        requested.addAll(ids);
        expect(ids.length, lessThanOrEqualTo(20));
        return response({'items': [for (final id in ids) {
          ...item(id), 'friends': id == 400
              ? [{'userId': 'friend', 'username': 'Friend', 'watched': true,
                  'recommends': true}] : []
        }]});
      }
      return response({'watchProviders': []});
    }));
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
      await tester.tap(find.byTooltip('More watchlist filters'));
      await tester.pumpAndSettle();
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
