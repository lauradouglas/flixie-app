import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/core/utils/notification_destination.dart';
import 'package:flixie_app/features/profile/presentation/widgets/notification_inbox_card.dart';

FlixieNotification notice(String type) => FlixieNotification(
        id: 'fixture',
        userId: 'fictional',
        type: FlixieNotification.availabilityAlert,
        action: 'RECEIVED',
        read: false,
        message: 'New availability',
        data: {
          'mediaType': type,
          'mediaTitle': 'Alien',
          'providerNames': 'Netflix and Disney+',
          'country': 'GB',
          'route':
              '/${type == 'tv' ? 'shows' : 'movies'}/348?source=notification'
        });

void main() {
  testWidgets(
      'season premiere alert explains the release without provider claims',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: NotificationInboxCard(
              notification: const FlixieNotification(
                userId: 'fixture-user',
                type: FlixieNotification.availabilityAlert,
                event: 'NEW_SEASON_RELEASE',
                message: 'Alien: Earth · Season 2 premieres today.',
                data: {
                  'mediaType': 'tv',
                  'mediaTitle': 'Alien: Earth',
                  'route': '/shows/101?source=notification'
                },
              ),
              date: 'Today',
              onOptions: () {},
              onOpen: () {}),
        )));
    expect(find.text('New season today'), findsOneWidget);
    expect(
        find.text('Alien: Earth · Season 2 premieres today.'), findsOneWidget);
    expect(find.text('Availability via JustWatch'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final type in ['movie', 'tv']) {
    testWidgets('$type availability alert opens the title, never an invitation',
        (tester) async {
      final n = notice(type);
      final router = GoRouter(routes: [
        GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
                body: NotificationInboxCard(
                    notification: n,
                    date: 'Today',
                    onOptions: () {},
                    onOpen: () => context.push(notificationDestination(n))))),
        GoRoute(
            path: '/movies/:id',
            builder: (_, state) =>
                Scaffold(body: Text('Film ${state.pathParameters['id']}'))),
        GoRoute(
            path: '/shows/:id',
            builder: (_, state) =>
                Scaffold(body: Text('Show ${state.pathParameters['id']}'))),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(
          MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router));
      expect(find.text('Accept'), findsNothing);
      expect(find.text('Availability via JustWatch'), findsOneWidget);
      expect(notificationBelongsInInbox(n), isTrue);
      await tester.tap(find.text('View title →'));
      await tester.pumpAndSettle();
      expect(
          find.text('${type == 'tv' ? 'Show' : 'Film'} 348'), findsOneWidget);
    });
  }
  for (final entry in [
    (const Size(320, 640), 2.0),
    (const Size(430, 900), 1.0),
    (const Size(1000, 720), 1.0),
    (const Size(640, 320), 2.0)
  ]) {
    testWidgets('availability copy reflows at ${entry.$1} scale ${entry.$2}',
        (tester) async {
      await tester.binding.setSurfaceSize(entry.$1);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(entry.$2)),
              child: child!),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: NotificationInboxCard(
                      notification: notice('tv'),
                      date: 'Yesterday',
                      onOptions: () {},
                      onOpen: () {})))));
      expect(tester.takeException(), isNull);
      expect(find.text('Added to Netflix and Disney+ · GB'), findsOneWidget);
    });
  }
}
