import 'package:go_router/go_router.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_tile.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

ActivityListItem _item({
  required ActivityListType type,
  String? title,
  double? rating,
  String? notes,
  String username = '',
  bool isRewatch = false,
  int? watchCount,
  bool? recommended,
}) {
  return ActivityListItem(
    id: 'a1',
    userId: 'u1',
    username: username,
    firstName: 'Doug',
    lastName: '',
    movieId: 101,
    removed: false,
    createdAt: DateTime.now().toUtc().toIso8601String(),
    updatedAt: DateTime.now().toUtc().toIso8601String(),
    type: type,
    mediaTitle: title ?? 'Jurassic Park',
    mediaRating: rating,
    recommended: recommended,
    isRewatch: isRewatch,
    watchCount: watchCount,
    notes: notes,
  );
}

void main() {
  testWidgets('opening media dismisses compact activity sheet', (tester) async {
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
              body: ActivityTile(
                  item: _item(type: ActivityListType.movieRating, rating: 9),
                  compact: true))),
      GoRoute(
          path: '/movies/:id',
          builder: (_, __) => const Scaffold(body: Text('Movie destination'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.byType(ActivityTile));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close activity'), findsOneWidget);
    await tester.tap(find.textContaining('View film'));
    await tester.pumpAndSettle();
    expect(find.text('Movie destination'), findsOneWidget);
    expect(find.byTooltip('Close activity'), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('renders watched activity with shared card header',
      (tester) async {
    final item = _item(type: ActivityListType.movieWatched);
    await tester.pumpWidget(_wrap(ActivityTile(item: item)));

    expect(find.text('Doug'), findsOneWidget);
    expect(find.text('Watchlist'), findsNothing);
    expect(find.textContaining('Watched a film'), findsOneWidget);
  });

  testWidgets('renders rating badge when media rating is available',
      (tester) async {
    final item = _item(type: ActivityListType.movieRating, rating: 9);
    await tester.pumpWidget(_wrap(ActivityTile(item: item)));

    expect(find.text('★ 9 / 10'), findsOneWidget);
    expect(find.textContaining('Rated a film'), findsOneWidget);
  });

  testWidgets('renders explicit do-not-recommend choice', (tester) async {
    final item = _item(
      type: ActivityListType.movieRating,
      rating: 8,
      recommended: false,
    );
    await tester.pumpWidget(_wrap(ActivityTile(item: item)));

    expect(find.text('Doesn’t recommend'), findsOneWidget);
  });

  testWidgets('renders compact watchlist activity with notes', (tester) async {
    final item = _item(
      type: ActivityListType.movieWatchlist,
      notes: 'Can’t wait to watch this one.',
    );
    await tester.pumpWidget(_wrap(ActivityTile(item: item, compact: true)));

    expect(find.textContaining('to watchlist'), findsOneWidget);
    expect(find.text('Can’t wait to watch this one.'), findsOneWidget);
  });

  testWidgets('renders rewatch headline with watch count', (tester) async {
    final item = _item(
      type: ActivityListType.movieWatched,
      isRewatch: true,
      watchCount: 3,
    );
    await tester.pumpWidget(_wrap(ActivityTile(item: item)));

    expect(find.textContaining('Watched again · 3 times'), findsOneWidget);
    expect(find.text('Jurassic Park'), findsOneWidget);
  });

  testWidgets('favourite person activity renders the person portrait',
      (tester) async {
    final item = ActivityListItem.fromJson({
      'id': 'person-favourite-1',
      'userId': 'u1',
      'username': 'Laura',
      'personId': 287,
      'type': 'favorite_person',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'person': {
        'id': 287,
        'name': 'Brad Pitt',
        'profileImgUrl': '/person-profile.jpg',
      },
    });

    await tester.pumpWidget(_wrap(ActivityTile(item: item)));

    expect(find.textContaining('Brad Pitt'), findsWidgets);
    final portrait = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage).first,
    );
    expect(
      portrait.imageUrl,
      'https://image.tmdb.org/t/p/w342/person-profile.jpg',
    );
  });
}
