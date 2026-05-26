import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/screens/profile/activity_tile.dart';
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
}) {
  return ActivityListItem(
    id: 'a1',
    userId: 'u1',
    username: 'dougasaur',
    firstName: 'Doug',
    lastName: '',
    movieId: 101,
    removed: false,
    createdAt: DateTime.now().toUtc().toIso8601String(),
    updatedAt: DateTime.now().toUtc().toIso8601String(),
    type: type,
    mediaTitle: title ?? 'Jurassic Park',
    mediaRating: rating,
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
    expect(find.text('Rated'), findsOneWidget);
  });

  testWidgets('renders compact watchlist activity with notes', (tester) async {
    final item = _item(
      type: ActivityListType.movieWatchlist,
      notes: 'Can’t wait to watch this one.',
    );
    await tester.pumpWidget(_wrap(ActivityTile(item: item, compact: true)));

    expect(find.textContaining('added to watchlist'), findsOneWidget);
    expect(find.text('Can’t wait to watch this one.'), findsOneWidget);
  });
}
