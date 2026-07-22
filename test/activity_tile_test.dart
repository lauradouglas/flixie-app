import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_tile.dart';
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
  testWidgets('renders watched activity sentence and status chip',
      (tester) async {
    final item = _item(type: ActivityListType.movieWatched);
    await tester.pumpWidget(_wrap(ActivityTile(item: item)));

    expect(find.textContaining('Doug watched'), findsOneWidget);
    expect(find.text('Watchlist'), findsNothing);
    expect(find.text('Watched'), findsOneWidget);
  });

  testWidgets('renders rating badge when media rating is available',
      (tester) async {
    final item = _item(type: ActivityListType.movieRating, rating: 9);
    await tester.pumpWidget(_wrap(ActivityTile(item: item)));

    expect(find.text('9.0/10'), findsOneWidget);
    expect(find.text('Rated 9+/10'), findsOneWidget);
  });

  testWidgets('renders explicit do-not-recommend choice', (tester) async {
    final item = _item(
      type: ActivityListType.movieRating,
      rating: 8,
      recommended: false,
    );
    await tester.pumpWidget(_wrap(ActivityTile(item: item)));

    expect(find.text('Doesn\'t recommend'), findsOneWidget);
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

    expect(find.textContaining('rewatched Jurassic Park (3 times)'),
        findsOneWidget);
    expect(find.text('Rewatched'), findsOneWidget);
  });
}
