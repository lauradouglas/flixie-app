// Frozen card is byte-identical to the signed iOS 2.0.5 builds 128 and 129
// source manifests: SHA256 17f704a57c691a097786479b31fe71b6df0201a4933b45c8f2c28dd150ae86a4.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/notification_deep_link.dart';
import 'package:flixie_app/models/notification.dart';
import '../../../fixtures/releases/availability_notification_card_129.dart'
    as released;

void main() {
  testWidgets(
      'released 128/129 card reads movie batches and opens its existing full watchlist',
      (tester) async {
    final notice = FlixieNotification.fromJson({
      'id': 'fictional-digest',
      'userId': 'fixture-viewer',
      'type': 'AVAILABILITY_ALERT',
      'event': 'WATCHLIST_MOVIE_DIGEST',
      'message': 'Alien on Netflix. The Odyssey on Disney+.',
      'data': {
        'type': 'AVAILABILITY_ALERT',
        'event': 'WATCHLIST_MOVIE_DIGEST',
        'mediaType': 'movie',
        'mediaTitle': '2 films from your watchlist',
        'providerNames': 'Netflix · Disney+',
        'country': 'GB',
        'count': '2',
        'route': '/watchlist?availableOn=2026-10-24'
      },
    });
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
                  body: released.AvailabilityNotificationCard(
                notification: notice,
                date: 'Today',
                onOptions: () {},
                onOpen: () =>
                    context.push(notificationDeepLinkPath(notice.data!)),
              ))),
      // Released route accepts the existing path and ignores unknown queries.
      GoRoute(
          path: '/watchlist',
          builder: (_, __) => const Scaffold(body: Text('Full watchlist'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router));
    expect(find.text('2 films from your watchlist'), findsOneWidget);
    expect(find.text('Added to Netflix · Disney+ · GB'), findsOneWidget);
    expect(find.text('A title on your watchlist'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('View title →'));
    await tester.pumpAndSettle();
    expect(find.text('Full watchlist'), findsOneWidget);
  });

  testWidgets(
      'released card tolerates new episode event and keeps the show route',
      (tester) async {
    final notice = FlixieNotification.fromJson({
      'id': 'fictional-episode',
      'userId': 'fixture-viewer',
      'type': 'AVAILABILITY_ALERT',
      'event': 'NEW_EPISODE_RELEASE',
      'message': 'New episode of Vision Quest: S1 E2. Show listed on Disney+.',
      'data': {
        'type': 'AVAILABILITY_ALERT',
        'event': 'NEW_EPISODE_RELEASE',
        'mediaType': 'tv',
        'mediaTitle': 'Vision Quest',
        'mediaId': '101',
        'providerNames': 'Disney+',
        'country': 'GB',
        'episodeId': '1002',
        'route': '/shows/101?source=notification'
      },
    });
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
            body: released.AvailabilityNotificationCard(
                notification: notice,
                date: 'Today',
                onOptions: () {},
                onOpen: () {}))));
    expect(find.text('Vision Quest'), findsOneWidget);
    expect(find.text('Added to Disney+ · GB'), findsOneWidget);
    expect(notificationDeepLinkPath(notice.data!),
        '/shows/101?source=notification');
    expect(tester.takeException(), isNull);
  });
}
