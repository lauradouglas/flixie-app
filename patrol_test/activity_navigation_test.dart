import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patrol/patrol.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_tile.dart';
import 'package:flixie_app/models/activity_list_item.dart';

void main() {
  patrolTest('opening a film from friend activity closes the sheet', ($) async {
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(
                  body: ActivityTile(
                compact: true,
                item: ActivityListItem(
                  id: 'activity',
                  userId: 'friend',
                  username: 'Friend',
                  firstName: 'Friend',
                  lastName: '',
                  movieId: 101,
                  removed: false,
                  createdAt: '2026-09-01T12:00:00Z',
                  updatedAt: '2026-09-01T12:00:00Z',
                  type: ActivityListType.movieRating,
                  mediaTitle: 'Jurassic Park',
                  mediaRating: 9,
                ),
              ))),
      GoRoute(
          path: '/movies/:id',
          builder: (_, __) =>
              const Scaffold(body: Text('Film detail destination'))),
    ]);
    addTearDown(router.dispose);
    await $.pumpWidgetAndSettle(
        MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router));
    await $(ActivityTile).tap();
    await $(find.byTooltip('Close activity')).waitUntilVisible();
    await $(find.textContaining('View film')).tap();
    await $('Film detail destination').waitUntilVisible();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byTooltip('Close activity'), findsNothing);
    // Exercise the native automation channel, not just Flutter widget taps.
    await $.platform.mobile.pressHome();
    await $.platform.mobile.openApp();
    await $('Film detail destination').waitUntilVisible();
  });
}
