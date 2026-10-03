import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/router/router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/analytics/analytics_backend.dart';
import 'package:flixie_app/core/analytics/analytics_consent.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/features/home/presentation/pages/home_screen.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/movies/presentation/pages/movie_detail_screen.dart';
import 'package:flixie_app/features/movies/presentation/pages/show_detail_screen.dart';
import 'package:flixie_app/features/profile/presentation/pages/profile_screen.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'package:flixie_app/features/social/data/watch_request_cache.dart';
import 'package:flixie_app/features/social/presentation/pages/community_space_screen.dart';
import 'package:flixie_app/features/social/presentation/pages/watch_requests_screen.dart';
import 'package:flixie_app/features/watchlist/presentation/pages/watchlist_screen.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/watch_provider.dart';
import '../../test/support/watchlist_auth.dart';

// Frozen public title metadata; all accounts, activity and plans are fictional.
const screenshotMovies = <Map<String, dynamic>>[
  {
    'id': 157336,
    'title': 'Interstellar',
    'voteAverage': 8.7,
    'voteCount': 3,
    'posterPath': '/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg',
    'releaseDate': '2014-11-05',
    'runtime': 169,
    'overview':
        'A team of explorers travels beyond this galaxy to discover whether mankind has a future among the stars.',
    'genres': [
      {'id': 878, 'name': 'Science Fiction'},
      {'id': 18, 'name': 'Drama'}
    ],
  },
  {
    'id': 348,
    'title': 'Alien',
    'posterPath': '/vfrQk5IPloGg1v9Rzbh2Eg3VGyM.jpg',
    'releaseDate': '1979-05-25',
    'runtime': 117,
    'voteAverage': 8.7,
    'genres': [
      {'id': 878, 'name': 'Science Fiction'}
    ],
  },
  {
    'id': 1368337,
    'title': 'The Odyssey',
    'posterPath': '/5rhTDKUhPYvpdQIijFIs5VoWsON.jpg',
    'releaseDate': '2026-07-15',
    'genres': [
      {'id': 12, 'name': 'Adventure'}
    ],
  },
  {
    'id': 129,
    'title': 'Spirited Away',
    'posterPath': '/39wmItIWsg5sZMyRUHLkWBcuVCM.jpg',
    'releaseDate': '2001-07-20',
    'runtime': 125,
    'voteAverage': 8.7,
  },
];
const screenshotShow = <String, dynamic>{
  'id': 15621,
  'name': 'The Newsroom',
  'title': 'The Newsroom',
  'posterPath': '/2s6IPLtfw0GiMxlJznb1TkA6KXk.jpg',
  'backdropPath': '/1dQHZhnej0acyQn5jlVb8NHDMDM.jpg',
  'firstAirDate': '2012-06-24',
  'numberOfEpisodes': 25,
  'numberOfSeasons': 3,
  'status': 'Ended',
  'overview':
      'Behind the scenes at a nightly cable-news programme, a passionate team sets out to do the news well.',
  'genres': [
    {'id': 18, 'name': 'Drama'}
  ],
  'seasons': [
    {
      "id": 27151,
      "seasonNumber": 1,
      "name": "Season 1",
      "episodeCount": 10,
      "episodes": [
        {
          "id": 540676,
          "seasonNumber": 1,
          "episodeNumber": 1,
          "name": "We Just Decided To",
          "airDate": "2012-06-24",
          "runtime": 72,
          "watched": true
        },
        {
          "id": 540677,
          "seasonNumber": 1,
          "episodeNumber": 2,
          "name": "News Night 2.0",
          "airDate": "2012-07-01",
          "runtime": 58,
          "watched": true
        },
        {
          "id": 540671,
          "seasonNumber": 1,
          "episodeNumber": 3,
          "name": "The 112th Congress",
          "airDate": "2012-07-08",
          "runtime": 59,
          "watched": true
        },
        {
          "id": 540674,
          "seasonNumber": 1,
          "episodeNumber": 4,
          "name": "I'll Try to Fix You",
          "airDate": "2012-07-15",
          "runtime": 60,
          "watched": true
        },
        {
          "id": 540679,
          "seasonNumber": 1,
          "episodeNumber": 5,
          "name": "Amen",
          "airDate": "2012-07-22",
          "runtime": 54,
          "watched": false
        },
        {
          "id": 540681,
          "seasonNumber": 1,
          "episodeNumber": 6,
          "name": "Bullies",
          "airDate": "2012-07-29",
          "runtime": 58,
          "watched": false
        },
        {
          "id": 540683,
          "seasonNumber": 1,
          "episodeNumber": 7,
          "name": "5/1",
          "airDate": "2012-08-05",
          "runtime": 53,
          "watched": false
        },
        {
          "id": 540685,
          "seasonNumber": 1,
          "episodeNumber": 8,
          "name": "The Blackout Part I: Tragedy Porn",
          "airDate": "2012-08-12",
          "runtime": 58,
          "watched": false
        },
        {
          "id": 540684,
          "seasonNumber": 1,
          "episodeNumber": 9,
          "name": "The Blackout Part II: Mock Debate",
          "airDate": "2012-08-19",
          "runtime": 55,
          "watched": false
        },
        {
          "id": 540686,
          "seasonNumber": 1,
          "episodeNumber": 10,
          "name": "The Greater Fool",
          "airDate": "2012-08-26",
          "runtime": 61,
          "watched": false
        }
      ]
    },
    {
      "id": 27154,
      "seasonNumber": 2,
      "name": "Season 2",
      "episodeCount": 9,
      "episodes": [
        {
          "id": 540689,
          "seasonNumber": 2,
          "episodeNumber": 1,
          "name": "First Thing We Do, Let's Kill All the Lawyers",
          "airDate": "2013-07-14",
          "runtime": 53,
          "watched": false
        },
        {
          "id": 540690,
          "seasonNumber": 2,
          "episodeNumber": 2,
          "name": "The Genoa Tip",
          "airDate": "2013-07-21",
          "runtime": 54,
          "watched": false
        },
        {
          "id": 540691,
          "seasonNumber": 2,
          "episodeNumber": 3,
          "name": "Willie Pete",
          "airDate": "2013-07-28",
          "runtime": 58,
          "watched": false
        },
        {
          "id": 540692,
          "seasonNumber": 2,
          "episodeNumber": 4,
          "name": "Unintended Consequences",
          "airDate": "2013-08-04",
          "runtime": 58,
          "watched": false
        },
        {
          "id": 540693,
          "seasonNumber": 2,
          "episodeNumber": 5,
          "name": "News Night with Will McAvoy",
          "airDate": "2013-08-11",
          "runtime": 57,
          "watched": false
        },
        {
          "id": 540695,
          "seasonNumber": 2,
          "episodeNumber": 6,
          "name": "One Step Too Many",
          "airDate": "2013-08-18",
          "runtime": 50,
          "watched": false
        },
        {
          "id": 540694,
          "seasonNumber": 2,
          "episodeNumber": 7,
          "name": "Red Team III",
          "airDate": "2013-08-25",
          "runtime": 57,
          "watched": false
        },
        {
          "id": 540696,
          "seasonNumber": 2,
          "episodeNumber": 8,
          "name": "Election Night (1)",
          "airDate": "2013-09-08",
          "runtime": 47,
          "watched": false
        },
        {
          "id": 540697,
          "seasonNumber": 2,
          "episodeNumber": 9,
          "name": "Election Night (2)",
          "airDate": "2013-09-15",
          "runtime": 59,
          "watched": false
        }
      ]
    },
    {
      "id": 62666,
      "seasonNumber": 3,
      "name": "Season 3",
      "episodeCount": 6,
      "episodes": [
        {
          "id": 1011921,
          "seasonNumber": 3,
          "episodeNumber": 1,
          "name": "Boston",
          "airDate": "2014-11-09",
          "runtime": 53,
          "watched": false
        },
        {
          "id": 1011922,
          "seasonNumber": 3,
          "episodeNumber": 2,
          "name": "Run",
          "airDate": "2014-11-16",
          "runtime": 58,
          "watched": false
        },
        {
          "id": 1011923,
          "seasonNumber": 3,
          "episodeNumber": 3,
          "name": "Main Justice",
          "airDate": "2014-11-23",
          "runtime": 57,
          "watched": false
        },
        {
          "id": 1011924,
          "seasonNumber": 3,
          "episodeNumber": 4,
          "name": "Contempt",
          "airDate": "2014-11-30",
          "runtime": 58,
          "watched": false
        },
        {
          "id": 1015057,
          "seasonNumber": 3,
          "episodeNumber": 5,
          "name": "Oh Shenandoah",
          "airDate": "2014-12-07",
          "runtime": 56,
          "watched": false
        },
        {
          "id": 1015058,
          "seasonNumber": 3,
          "episodeNumber": 6,
          "name": "What Kind of Day Has It Been?",
          "airDate": "2014-12-14",
          "runtime": 64,
          "watched": false
        }
      ]
    }
  ],
};
const screenshotPerson = <String, dynamic>{
  'id': 'store-viewer',
  'username': 'alexriver',
  'firstName': 'Alex',
  'lastName': 'River',
  'profileBadges': ['FOUNDER'],
};
const screenshotFriend = <String, dynamic>{
  'id': 'store-jamie',
  'username': 'jamie',
  'firstName': 'Jamie',
  'lastName': 'Park',
  'profileBadges': ['FOUNDER'],
};

Map<String, dynamic> get screenshotPlan => {
      'id': 'store-movie-night',
      'type': 'MOVIE_WATCH_REQUEST',
      'requesterId': 'store-viewer',
      'recipientId': 'store-jamie',
      'requester': screenshotPerson,
      'recipient': screenshotFriend,
      'status': 'ACCEPTED',
      'message': 'Movie night? Let’s finally watch Alien together.',
      'movieId': 348,
      'movie': screenshotMovies[1],
      'scheduleStatus': 'AGREED',
      'scheduledFor': DateTime.now()
          .add(const Duration(days: 3))
          .copyWith(
              hour: 19, minute: 30, second: 0, millisecond: 0, microsecond: 0)
          .toUtc()
          .toIso8601String(),
      'location': 'Jamie’s place',
      'watchedStatus': 'NOT_DUE',
      'hasCurrentUserAccepted': true,
      'canSchedule': true,
      'candidates': [],
      'scheduleProposals': [],
      'watchConfirmations': [],
    };

class StoreScreenshotAuth extends TestAuth {
  @override
  User get dbUser => User.fromJson({
        ...screenshotPerson,
        'email': '',
        'iconColorId': 0,
        'completedSetup': true,
        'darkMode': true,
        'bio': 'Big stories, small cinemas. Always up for a movie night.',
        'watchProviderRegion': 'GB',
        'favoriteMovies': [
          for (final i in [1, 3])
            {
              'id': 'f-$i',
              'userId': 'store-viewer',
              'movieId': screenshotMovies[i]['id'],
              'rank': i,
              'movie': screenshotMovies[i]
            },
        ],
        'favoriteShows': [
          {'id': 'fs', 'showId': 15621, 'rank': 1, 'show': screenshotShow}
        ],
        'movieWatchlist': [
          for (final movie in screenshotMovies)
            {
              'id': 'wl-${movie['id']}',
              'userId': 'store-viewer',
              'movieId': movie['id'],
              'movie': movie
            },
        ],
        'showWatchlist': [
          {'id': 'wls', 'showId': 15621, 'show': screenshotShow}
        ],
        'watchedMovies': [
          for (final movie
              in screenshotMovies.where((m) => [348, 129].contains(m['id'])))
            {
              'id': 'w-${movie['id']}',
              'movieId': movie['id'],
              'movie': movie,
              'watchedAt': '2026-09-20T18:00:00Z'
            },
        ],
      });

  @override
  int get unreadNotificationCount => 0;
  @override
  Map<int, List<WatchProvider>> get cachedWatchProvidersByMovieId => {
        for (final movie in screenshotMovies)
          movie['id'] as int: screenshotProviders(movie['id'] as int)
              .map(WatchProvider.fromJson)
              .toList(),
      };
  @override
  Future<void> ensureWatchProviderCache({Iterable<int>? movieIds}) async {}
}

class StoreScreenshotFixture {
  final unexpectedRequests = <String>[];
  late final client = MockClient((request) async {
    final data = response(request);
    return http.Response(jsonEncode(data), 200,
        headers: {'content-type': 'application/json'});
  });

  Object? response(http.Request request) {
    final path = request.url.path;
    if (request.method == 'POST' && path == '/shows/by-ids') {
      return [screenshotShow];
    }
    if (request.method == 'POST' && path.endsWith('/user/rating')) return null;
    if (request.method == 'POST' && path.endsWith('/friend-recommendations')) {
      final body = jsonDecode(request.body) as Map;
      final key = path.startsWith('/shows') ? 'showId' : 'movieId';
      final ids = body[key == 'showId' ? 'showIds' : 'movieIds'] as List;
      return {
        'items': [
          for (final id in ids)
            {
              key: '$id',
              'recommendPercent': id == 1368337 ? 0 : 100,
              'friendCount': id == 1368337 ? 0 : 2,
              'recommendedCount': id == 1368337 ? 0 : 2,
              'averageFriendRating': id == 1368337 ? null : 8.5,
              'friends': screenshotRecommendations(
                  key == 'showId' ? 'show' : 'movie', id as int),
            }
        ]
      };
    }
    if (request.method != 'GET') return unexpected(request);
    if (path == '/trending/movie/day' ||
        path == '/users/store-viewer/recommendations') {
      return screenshotMovies;
    }
    if (path == '/users/store-viewer/movie/watchlist' ||
        path == '/users/store-viewer/watchlists') {
      return [
        for (final movie in screenshotMovies)
          {
            'id': 'wl-${movie['id']}',
            'movieId': movie['id'],
            'userId': 'store-viewer',
            'movie': movie
          },
      ];
    }
    if (path == '/movies/id/157336') return screenshotMovies.first;
    if (path == '/shows/id/15621') return screenshotShow;
    if (path == '/movies/157336/images') {
      return {'backdrops': [], 'posters': []};
    }
    if (path.endsWith('/credits')) return {'cast': [], 'crew': []};
    if (path.endsWith('/friend-summary')) {
      return {
        'friendCount': 2,
        'watchedCount': 2,
        'favouriteCount': 1,
        'watchlistCount': 1,
        'averageRating': 8.5,
      };
    }
    if (path.endsWith('/friend-recommendation')) {
      return {
        'movieId': '157336',
        'recommendPercent': 100,
        'friendCount': 2,
        'recommendedCount': 2,
        'averageFriendRating': 8.5,
        'friends': screenshotRecommendations('movie', 157336),
      };
    }
    if (path == '/friends/store-viewer') {
      return {
        'friendships': [],
        'requestedFriends': [],
        'pendingFriends': [],
      };
    }
    if (path == '/movies/id/157336/friends-activity') {
      return [
        {
          'user': screenshotFriend,
          'watched': true,
          'rating': 9,
          'recommended': true,
          'favorited': true,
          'watchCount': 1,
        },
        {
          'user': {
            'id': 'store-morgan',
            'username': 'morganlee',
            'firstName': 'Morgan',
            'iconColor': '#8B5CF6',
            'profileBadges': [],
          },
          'watched': true,
          'rating': 8,
          'recommended': true,
          'reviewed': true,
          'watchCount': 1,
        },
      ];
    }
    if (path == '/community/activity' &&
        request.url.queryParameters['movieId'] == '157336') {
      return {
        'movieId': 157336,
        'items': [
          {
            'id': 'store-interstellar-opinion',
            'userId': 'store-nina',
            'username': 'ninawatches',
            'type': 'movie-review',
            'movieId': 157336,
            'rating': 9,
            'recommended': true,
            'favorited': true,
            'title': 'Interstellar deserves the big screen',
            'body': 'An adventure to share with friends.',
            'containsSpoilers': false,
            'profileBadges': ['FOUNDER'],
          },
        ],
        'nextCursor': null,
      };
    }
    if (path == '/users/store-viewer/activity' ||
        path == '/community/activity') {
      return {
        'items': [],
        'nextCursor': null,
        if (request.url.queryParameters['movieId'] != null)
          'movieId': int.parse(request.url.queryParameters['movieId']!),
      };
    }
    if (path == '/users/store-viewer/watch-providers') {
      return {'watchProviders': []};
    }
    if (path == '/requests/store-viewer/all') return [screenshotPlan];
    if (path == '/watch-requests/store-movie-night/state') {
      return {
        'request': screenshotPlan,
        'needsWatchConfirmation': false,
        'hasCurrentUserLoggedWatch': false,
      };
    }
    if (path == '/groups/home/watch-plans') return {'groups': []};
    if (path == '/community/spaces/18') {
      return {'id': 18, 'name': 'Drama', 'joined': true};
    }
    if (path == '/community/spaces/18/discussions') {
      return {
        'items': [
          {
            'id': 'store-discussion',
            'user': screenshotFriend,
            'title': 'The shows that stay with you',
            'body':
                'The Newsroom makes me want to watch just one more episode. What’s your favourite character-driven drama?',
            'spoiler': 'none',
            'replyCount': 12,
            'createdAt': DateTime.now()
                .subtract(const Duration(hours: 2))
                .toIso8601String(),
            'show': screenshotShow,
          },
          {
            'id': 'store-discussion-2',
            'user': screenshotPerson,
            'title': 'Your perfect Sunday watch',
            'body':
                'A great story, a cup of tea and no spoilers. Share your picks.',
            'spoiler': 'none',
            'replyCount': 8,
            'createdAt': DateTime.now()
                .subtract(const Duration(hours: 4))
                .toIso8601String(),
          },
        ],
        'nextCursor': null
      };
    }
    final providers =
        RegExp(r'^/(movies|shows)/(\d+)/GB/watch/providers$').firstMatch(path);
    if (providers != null) return screenshotProviders(int.parse(providers[2]!));
    final interactions =
        RegExp(r'^/friends/store-viewer/interactions/movie/(\d+)$')
            .firstMatch(path);
    if (interactions != null) {
      return [
        {
          'friendId': 'store-jamie',
          'username': 'jamie',
          'watchlist': true,
          'favorite': interactions[1] != '1368337',
          'profileBadges': screenshotFriend['profileBadges'],
        }
      ];
    }
    const emptyLists = {
      '/users/store-viewer/shows/continue-watching',
      '/users/store-viewer/movies/ratings',
      '/users/store-viewer/lists',
      '/users/store-viewer/show/lists',
      '/users/store-viewer/movie/157336/watches',
      '/movies/157336/recommendations',
      '/movies/157336/reviews',
      '/users/MOVIE/157336/reviews',
      '/users/SHOW/15621/reviews',
      '/shows/15621/reviews',
      '/groups/user/store-viewer',
      '/friends/store-viewer/interactions/movie/348',
      '/friends/store-viewer/interactions/movie/129',
    };
    if (emptyLists.contains(path)) return [];
    return unexpected(request);
  }

  Never unexpected(http.Request request) {
    final description = '${request.method} ${request.url.path}';
    unexpectedRequests.add(description);
    throw StateError('Unconfigured screenshot API: $description');
  }
}

GoRouter storeScreenshotRouter() => GoRouter(routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainNavigationShell(navigationShell: shell),
        branches: [
          for (final (path, screen) in <(String, Widget)>[
            ('/', const HomeScreen()),
            ('/search', const SizedBox.shrink()),
            ('/plans', const WatchRequestsScreen()),
            ('/social', const SizedBox.shrink()),
            ('/profile', const ProfileScreen()),
          ])
            StatefulShellBranch(
                routes: [GoRoute(path: path, builder: (_, __) => screen)]),
        ],
      ),
      GoRoute(path: '/watchlist', builder: (_, __) => const WatchlistScreen()),
      GoRoute(
          path: '/watch-requests/store-movie-night',
          builder: (_, __) =>
              const WatchRequestsScreen(initialRequestId: 'store-movie-night')),
      GoRoute(
          path: '/community/spaces/18',
          builder: (_, __) => const CommunitySpaceScreen(communityId: 18)),
      GoRoute(
          path: '/movies/157336',
          builder: (_, __) => const MovieDetailScreen(movieId: '157336')),
      GoRoute(
          path: '/shows/15621',
          builder: (_, __) => const ShowDetailScreen(showId: '15621')),
    ]);

Widget storeScreenshotApp(StoreScreenshotAuth auth, GoRouter router) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AnalyticsController>(
            create: (_) => AnalyticsController(
                backend: _ScreenshotAnalytics(),
                consentStore: _ScreenshotConsent())),
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        Provider<MovieService>(create: (_) => MovieService()),
        ChangeNotifierProvider<WatchRequestCache>(
            create: (_) => WatchRequestCache()),
        ChangeNotifierProvider<MovieRatingPrivacy>.value(
            value: MovieRatingPrivacy.instance),
      ],
      child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          color: FlixieColors.background,
          builder: (context, child) => ColoredBox(
                key: const ValueKey('screenshot-app-background'),
                color: context.colors.background,
                child: child ?? const SizedBox.shrink(),
              ),
          routerConfig: router),
    );

class _ScreenshotAnalytics implements AnalyticsBackend {
  @override
  Future<void> setCollectionEnabled(bool enabled) async {}
  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) async {}
  @override
  Future<void> logScreenView(String screenName) async {}
}

class _ScreenshotConsent implements AnalyticsConsentStore {
  @override
  Future<AnalyticsConsent> read() async => AnalyticsConsent.declined;
  @override
  Future<void> write(AnalyticsConsent consent) async {}
}

// Fictional social data is shared by list, home and detail responses.
List<Map<String, dynamic>> screenshotRecommendations(String scope, int id) => [
      for (final (user, rating) in [
        (screenshotFriend, 9),
        (
          {
            'id': 'store-morgan',
            'username': 'morganlee',
            'profileBadges': <String>[]
          },
          8
        )
      ])
        {
          'userId': user['id'],
          'username': user['username'],
          'profileBadges': user['profileBadges'],
          'watched': id != 1368337,
          'rating': id == 1368337 ? null : rating,
          'ratingScope': scope,
          'recommends': id != 1368337,
        },
    ];

// Representative UK purchase offers. The Odyssey has no fixture offer;
// no live service is queried.
List<Map<String, dynamic>> screenshotProviders(int id) => id == 1368337
    ? []
    : [
        {
          'id': 2,
          'providerName': 'Apple TV',
          'logoPath': '/9ghgSC0MA082EL6HLCW3GalykFD.jpg',
          'displayPriority': 1,
          'availabilityTypes': ['buy'],
          'movies': true,
          'tvShows': true,
          'supportsGb': true,
          'watchUrl':
              'https://www.themoviedb.org/${id == 15621 ? 'tv' : 'movie'}/$id/watch?locale=GB',
        },
      ];
