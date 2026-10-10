import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/watchlist/data/watchlist_data_service.dart';
import 'package:flixie_app/features/watchlist/presentation/widgets/watchlist_movie_search_sheet.dart';
import 'package:flixie_app/models/movie_short.dart';

class SearchData extends WatchlistDataService {
  final queries = <String>[];

  @override
  Future<List<MovieShort>> searchMovies(String query) async {
    queries.add(query);
    return const [
      MovieShort(id: 1, name: 'Alien'),
      MovieShort(id: 2, name: 'Aliens')
    ];
  }
}

void main() {
  testWidgets('search debounces, blocks saved titles and returns a new movie',
      (tester) async {
    final data = SearchData();
    MovieShort? selected;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
      builder: (context) => TextButton(
          onPressed: () async {
            selected = await showModalBottomSheet<MovieShort>(
                context: context,
                useRootNavigator: true,
                useSafeArea: true,
                isScrollControlled: true,
                builder: (_) => WatchlistMovieSearchSheet(
                    existingMovieIds: const {1}, service: data));
          },
          child: const Text('Add movie')),
    ))));
    await tester.tap(find.text('Add movie'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ali');
    await tester.pump(const Duration(milliseconds: 349));
    expect(data.queries, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(data.queries, ['Ali']);
    await tester.tap(find.text('Alien'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(find.byType(WatchlistMovieSearchSheet), findsOneWidget);
    await tester.tap(find.text('Aliens'));
    await tester.pumpAndSettle();
    expect(selected?.id, 2);
    expect(find.byType(WatchlistMovieSearchSheet), findsNothing);
  });
}
