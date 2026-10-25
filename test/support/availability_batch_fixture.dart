import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/utils/notification_destination.dart';
import 'package:flixie_app/features/profile/presentation/widgets/notification_inbox_card.dart';
import 'package:flixie_app/features/watchlist/presentation/pages/watchlist_screen.dart';
import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/watchlist_movie.dart';
import 'watchlist_auth.dart';

class AvailabilityBatchAuth extends TestAuth {
  AvailabilityBatchAuth() {
    ids = [1, 2, 3];
  }
  @override
  User get dbUser => super.dbUser.copyWith(movieWatchlist: [
        for (final (id, title) in [
          (1, 'Alien'),
          (2, 'The Odyssey'),
          (3, 'Obsession')
        ])
          WatchlistMovie(
              id: 'fixture-$id',
              userId: 'viewer',
              movieId: id,
              movie: WatchlistMovieDetails(id: id, title: title)),
      ]);
}

class AvailabilityBatchFixture {
  AvailabilityBatchFixture({required this.date});
  final String date;
  final auth = AvailabilityBatchAuth();
  int availabilityRequests = 0;
  late final client = MockClient((request) async {
    Object body = {'watchProviders': []};
    if (request.url.path == '/availability-alerts/movies') {
      availabilityRequests++;
      body = {
        'date': request.url.queryParameters['date'],
        'movieIds': [1, 3]
      };
    } else if (request.url.path.endsWith('friend-recommendations')) {
      final ids = (jsonDecode(request.body)['movieIds'] as List? ?? []);
      body = {
        'items': [
          for (final id in ids)
            {
              'movieId': '$id',
              'friends': [],
              'friendCount': 0,
              'recommendedCount': 0,
              'recommendPercent': 0
            }
        ]
      };
    }
    return http.Response(jsonEncode(body), 200);
  });
  late final notice = FlixieNotification(
    id: 'fictional-movie-batch',
    userId: 'viewer',
    type: FlixieNotification.availabilityAlert,
    event: 'WATCHLIST_MOVIE_DIGEST',
    message: 'Alien and Obsession were added to your services.',
    data: {
      'mediaType': 'movie',
      'count': '2',
      'availabilityDate': date,
      'route': '/watchlist?availableOn=$date'
    },
  );
  late final router = GoRouter(initialLocation: '/notifications', routes: [
    GoRoute(
        path: '/notifications',
        builder: (context, _) => Scaffold(
              body: SingleChildScrollView(
                  child: NotificationInboxCard(
                notification: notice,
                date: 'Today',
                onOptions: () {},
                onOpen: () => context.push(notificationDestination(notice)),
              )),
            )),
    GoRoute(
        path: '/watchlist',
        builder: (_, state) => WatchlistScreen(
            availableOn: state.uri.queryParameters['availableOn'])),
  ]);
  Widget app({double textScale = 1}) =>
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp.router(
            theme: AppTheme.darkTheme,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!)),
      );
  void dispose() {
    router.dispose();
    auth.dispose();
    client.close();
  }
}
