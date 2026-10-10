import 'dart:convert';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/presentation/pages/person_detail_screen.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import '../../test/support/watchlist_auth.dart';

Map<String, dynamic> personFixtureData(int id) => {
      'id': id,
      'name': 'Casey Fixture $id',
      'department': 'Acting',
      'biography': List.filled(10,
              'A fictional actor exploring Alien, The Odyssey and Spider-Man. ')
          .join(),
      'dateOfBirth': '1980-05-10',
      'placeOfBirth': 'Fixture Town',
    };
Map<String, dynamic> personFixtureCredit(int id, {bool tv = false}) => {
      'id': id,
      'title': tv
          ? 'Alien: Earth'
          : switch (id) {
              1 => 'Alien',
              2 => 'The Odyssey',
              3 => 'Obsession',
              4 => 'Spider-Man',
              _ => 'Fixture Film $id'
            },
      'type': tv ? 'tv' : 'movie',
      'characters': tv ? <String>[] : ['Captain $id'],
      'releaseDate': id == 2 ? '2027-07-01' : '2020-07-01',
      'voteAverage': id == 1 ? 9.0 : 7.0,
      'voteCount': 100,
      'popularity': 100.0 - id,
    };
Map<String, dynamic> personFixtureCredits({int count = 24}) => {
      'allCredits': [
        for (var i = 1; i <= count; i++) personFixtureCredit(i),
        personFixtureCredit(1, tv: true)
      ],
      'knownForCredits': [
        personFixtureCredit(1),
        personFixtureCredit(2),
        personFixtureCredit(1, tv: true)
      ],
      'crewCredits': [
        {
          ...personFixtureCredit(1),
          'department': 'Directing',
          'job': 'Director'
        },
        {
          ...personFixtureCredit(1),
          'department': 'Writing',
          'job': 'Screenplay'
        },
        {
          ...personFixtureCredit(1, tv: true),
          'department': 'Production',
          'job': 'Producer'
        },
      ],
    };
User personFixtureViewer(String id, {List<dynamic> favorites = const []}) =>
    User.fromJson({
      'id': id,
      'username': id,
      'email': '$id@example.invalid',
      'completedSetup': true,
      'favoritePeople': favorites,
      'watchedMovies': [
        {'id': 'watched', 'userId': id, 'movieId': 1}
      ],
      'movieWatchlist': [
        {'id': 'saved', 'userId': id, 'movieId': 2}
      ],
      'favoriteMovies': [
        {'id': 'favorite', 'userId': id, 'movieId': 1}
      ],
    });

class PersonFixtureAuth extends TestAuth {
  User _viewer = personFixtureViewer('person-viewer');
  @override
  User get dbUser => _viewer;
  void switchViewer(String id) {
    _viewer = personFixtureViewer(id);
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #updateUserList) {
      _viewer = _viewer.copyWith(
          favoritePeople:
              invocation.namedArguments[#favoritePeople] as List<dynamic>?);
      notifyListeners();
      return null;
    }
    return super.noSuchMethod(invocation);
  }
}

/// Strict fictional endpoints. Never reaches a real account or database.
class PersonDetailFixture {
  bool failDetail = false, failFavorite = false, photos = true;
  int count = 24;
  final calls = <String>[], unexpected = <String>[];
  Future<void>? writeGate;
  late final client = MockClient(handle);
  http.Response json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status,
          headers: {'content-type': 'application/json'});
  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    final key = '${request.method} $path';
    calls.add(key);
    final match = RegExp(r'^/people/(\d+)(.*)$').firstMatch(path);
    if (match == null) {
      unexpected.add(key);
      return json({'error': 'Unexpected fixture request'}, 500);
    }
    final id = int.parse(match[1]!);
    final suffix = match[2]!;
    if (request.method == 'GET' && suffix.isEmpty) {
      return failDetail
          ? json({'error': 'offline'}, 503)
          : json(personFixtureData(id));
    }
    if (request.method == 'GET' && suffix == '/credits') {
      return json(personFixtureCredits(count: count));
    }
    if (request.method == 'GET' && suffix == '/images') {
      return json(photos
          ? [
              for (var i = 0; i < 3; i++)
                {
                  'personId': id,
                  'imageUrl': 'http://127.0.0.1:1/fixture-photo-$i.png',
                  'aspectRatio': .67,
                }
            ]
          : []);
    }
    if (['POST', 'DELETE'].contains(request.method) &&
        RegExp(r'^/favorite/(person-viewer|person-other)$').hasMatch(suffix)) {
      await writeGate;
      return failFavorite
          ? json({'error': 'Fixture save failed'}, 500)
          : json({'saved': true});
    }
    unexpected.add(key);
    return json({'error': 'Unexpected fixture request'}, 500);
  }
}

GoRouter personFixtureRouter({String personId = '42'}) =>
    GoRouter(initialLocation: '/people/$personId', routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('Fixture Home'))),
      GoRoute(
          path: '/people/:id',
          builder: (_, state) =>
              PersonDetailScreen(personId: state.pathParameters['id']!)),
      for (final type in ['movies', 'shows'])
        GoRoute(
            path: '/$type/:id',
            builder: (_, state) => Scaffold(
                appBar: AppBar(),
                body: Text(
                    '$type ${state.pathParameters['id']} ${state.uri.queryParameters['source']}'))),
    ]);
Widget personFixtureApp(PersonFixtureAuth auth, GoRouter router,
        {TextScaler? textScaler}) =>
    ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp.router(
            theme: AppTheme.darkTheme,
            routerConfig: router,
            builder: (context, child) => textScaler == null
                ? child!
                : MediaQuery(
                    data:
                        MediaQuery.of(context).copyWith(textScaler: textScaler),
                    child: child!)));
