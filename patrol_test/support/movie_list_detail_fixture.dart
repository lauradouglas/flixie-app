import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/features/movies/presentation/pages/movie_list_detail_screen.dart';
import 'package:flixie_app/models/user.dart';
import '../../test/support/watchlist_auth.dart';
import 'runtime_database_fixture.dart';

class ListDetailAuth extends TestAuth {
  String? viewer = 'list-owner';
  @override
  User get dbUser => User.fromJson(listPerson(viewer ?? 'signed-out'));
  void switchViewer(String id) {
    viewer = id;
    notifyListeners();
  }
}

Map<String, dynamic> listPerson(String id) => {
      'id': id,
      'username': id,
      'email': '',
      'completedSetup': true,
      'profileBadges': ['EARLY_ADOPTER']
    };
Map<String, dynamic> listEntry(int id, String title,
        {bool show = false, String contributor = 'list-owner'}) =>
    {
      'id': '${show ? 'show' : 'movie'}-$id',
      'listId': 'fixture-list',
      'movieId': show ? null : id,
      'showId': show ? id : null,
      'createdAt': '2026-10-01T00:00:00Z',
      'addedBy': listPerson(contributor),
      if (!show)
        'movie': {
          'id': id,
          'title': title,
          'releaseDate': '2026-07-01',
          'voteAverage': 8.5
        },
      if (show)
        'show': {
          'id': id,
          'name': title,
          'firstAirDate': '2026-07-01',
          'voteAverage': 8.0
        }
    };

/// Strict fictional API for actions; database runtime transport remains read-only.
class MovieListDetailFixture {
  final calls = <String>[];
  final writes = <String>[];
  final unexpected = <String>[];
  bool owner = true;
  bool canEdit = true;
  bool failWrite = false;
  final entries = [
    listEntry(1, 'Alien'),
    listEntry(2, 'The Odyssey', contributor: 'list-friend'),
    listEntry(1, 'Alien: Earth', show: true, contributor: 'list-friend')
  ];
  final members = ['list-owner', 'list-friend'];
  Map<String, dynamic> get membership => {
        'id': 'fixture-list',
        'name': 'Fixture collection',
        'ownerId': 'list-owner',
        'scope': 'FRIENDS',
        'visibility': 'FRIENDS',
        'isOwner': owner,
        'canEdit': canEdit,
        'canManageMembers': owner,
        'canLeave': !owner,
        'whoCanAddItems': 'everyone',
        'members': members.map(listPerson).toList()
      };
  late final client = MockClient(handle);
  http.Response json(Object data, [int status = 200]) =>
      http.Response(jsonEncode(data), status,
          headers: {'content-type': 'application/json'});
  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    final call = '${request.method} $path';
    calls.add(call);
    if (request.method != 'GET') {
      writes.add(call);
      if (failWrite) return json({'message': 'Try again'}, 500);
      if (path.contains('/members/')) {
        members.remove(path.split('/').last);
        return json({});
      }
      if (path.endsWith('/members')) {
        members
            .add((jsonDecode(request.body) as Map)['collaboratorId'] as String);
        return json({});
      }
      if (path.endsWith('/fixture-list')) return json({});
      final show = path.contains('/shows/');
      final id = int.tryParse(path.split('/').last);
      if (id != null && (path.contains('/movies/') || show)) {
        if (request.method == 'DELETE') {
          entries.removeWhere((e) => e[show ? 'showId' : 'movieId'] == id);
          return json({});
        }
        final entry =
            listEntry(id, show ? 'Obsession TV' : 'Spider-Man', show: show);
        entries.insert(0, entry);
        return json(entry);
      }
    }
    if (path.endsWith('/fixture-list/items')) return json(entries);
    if (path.endsWith('/fixture-list/members')) return json(membership);
    if (path == '/users/list-owner') return json(listPerson('list-owner'));
    if (path.startsWith('/friends/'))
      return json({
        'friendships': [
          {'id': 'friend-edge', 'friend': listPerson('list-new-friend')}
        ]
      });
    if (path == '/search')
      return json({
        'results': [
          {'id': 3, 'title': 'Spider-Man', 'media_type': 'movie'},
          {'id': 3, 'name': 'Obsession TV', 'media_type': 'tv'}
        ]
      });
    unexpected.add(call);
    return json({'message': 'Unexpected fixture endpoint: $call'}, 500);
  }
}

Widget movieListFixtureApp(ListDetailAuth auth, GoRouter router,
        {double textScale = 1}) =>
    MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider(
              create: (_) => AnalyticsController(
                  backend: RuntimeAnalyticsBackend(),
                  consentStore: RuntimeAnalyticsConsentStore())),
        ],
        child: MaterialApp.router(
            theme: AppTheme.darkTheme,
            routerConfig: router,
            builder: (_, child) => MediaQuery(
                data: MediaQueryData.fromView(
                        WidgetsBinding.instance.platformDispatcher.views.first)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!)));
GoRouter movieListFixtureRouter({String? ownerId, bool? canEdit}) =>
    GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => MovieListDetailScreen(
              listId: 'fixture-list',
              listName: 'Fixture collection',
              ownerUserId: ownerId,
              canEditOverride: canEdit)),
      GoRoute(
          path: '/movie-lists',
          builder: (_, __) => const Scaffold(body: Text('Lists destination'))),
      GoRoute(
          path: '/movie/:id',
          builder: (_, __) => const Scaffold(body: Text('Movie destination'))),
      GoRoute(
          path: '/show/:id',
          builder: (_, __) => const Scaffold(body: Text('Show destination'))),
    ]);
