import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/home/presentation/widgets/cinema_list.dart';
import 'package:flixie_app/models/movie_short.dart';

void main() {
  testWidgets(
      'personal watchlist state, pending protection and optional TMDB rating',
      (tester) async {
    var saves = 0;
    Future<void> show({bool pending = false}) => tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
            body: CinemaList(
          movies: const [
            MovieShort(id: 348, name: 'Alien', voteAverage: 8.2),
            MovieShort(id: 1, name: 'The Odyssey')
          ],
          savedIds: const {348},
          pendingIds: pending ? {348} : {},
          onDetails: (_) {},
          onSave: (_) => saves++,
          onTrailer: (_) {},
        ))));
    await show();
    expect(find.text('TMDB 8.2/10'), findsOneWidget);
    expect(find.textContaining('TMDB'), findsOneWidget);
    expect(find.byTooltip('Remove from watchlist'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove from watchlist'));
    expect(saves, 1);
    await show(pending: true);
    final button = tester.widget<IconButton>(find.byType(IconButton).first);
    expect(button.onPressed, isNull);
    expect(find.textContaining('friends'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
