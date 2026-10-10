import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/watchlist/data/watchlist_data_service.dart';
import 'package:flixie_app/features/watchlist/presentation/controllers/watchlist_controller.dart';
import 'package:flixie_app/features/watchlist/presentation/watchlist_action_flow.dart';
import 'package:flixie_app/models/favorite_movie.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/watched_movie.dart';
import 'package:flixie_app/models/watchlist_movie.dart';
import '../../support/watchlist_auth.dart';

class ShowAuth extends TestAuth {
  List<dynamic> savedShows = [
    {
      'showId': 124958,
      'show': {
        'id': 124958,
        'name': 'Alien: Earth',
        'posterPath': '/fixture.jpg',
        'firstAirDate': '2025-08-12',
        'numberOfSeasons': 1,
        'episodeRuntime': 60,
        'genres': ['Science Fiction']
      }
    },
  ];

  @override
  User get dbUser =>
      super.dbUser.copyWith(movieWatchlist: [], showWatchlist: savedShows);

  @override
  void updateUserList(
      {List<WatchedMovie>? watchedMovies,
      List<dynamic>? watchedShows,
      List<WatchlistMovie>? movieWatchlist,
      List<dynamic>? showWatchlist,
      List<FavoriteMovie>? favoriteMovies,
      List<dynamic>? favoriteShows,
      List<dynamic>? favoritePeople}) {
    savedShows = showWatchlist ?? savedShows;
    notifyListeners();
  }
}

class ShowData extends WatchlistDataService {
  bool fail = false;
  final calls = <(String, int)>[];

  @override
  Future<dynamic> removeShowFromWatchlist(String userId, int showId) async {
    calls.add((userId, showId));
    if (fail) throw Exception('Fixture unavailable');
    return null;
  }
}

void main() {
  for (final failsFirst in [false, true]) {
    testWidgets(
        failsFirst
            ? 'failed show removal retains the title and Retry persists removal'
            : 'show removal updates saved state and the visible library',
        (tester) async {
      final auth = ShowAuth();
      final data = ShowData()..fail = failsFirst;
      final controller = WatchlistController(
          auth: auth, service: data, scheduleAfterFrame: (_) {})
        ..loadWatchlist();
      addTearDown(() {
        controller.dispose();
        auth.dispose();
      });
      final show = controller.allShowWatchlist.single;
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
            home: Scaffold(
                body: Builder(
          builder: (context) => ListenableBuilder(
              listenable: controller,
              builder: (_, __) => Column(
                    children: [
                      for (final entry in controller.allShowWatchlist)
                        Text(entry.title),
                      TextButton(
                          onPressed: () => WatchlistActionFlow(
                                  context: context,
                                  watchlist: controller,
                                  service: data)
                              .removeShow(show),
                          child: const Text('Remove show')),
                    ],
                  )),
        ))),
      ));
      await tester.tap(find.text('Remove show'));
      await tester.pumpAndSettle();
      if (failsFirst) {
        expect(controller.allShowWatchlist.single.title, 'Alien: Earth');
        expect(auth.savedShows, hasLength(1));
        expect(
            find.text('Couldn’t remove show from watchlist'), findsOneWidget);
        data.fail = false;
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
      }
      expect(auth.savedShows, isEmpty);
      expect(controller.allShowWatchlist, isEmpty);
      expect(find.text('Alien: Earth'), findsNothing);
      expect(find.text('Alien: Earth removed from watchlist'), findsOneWidget);
      expect(data.calls, List.filled(failsFirst ? 2 : 1, ('viewer', 124958)));
    });
  }
}
