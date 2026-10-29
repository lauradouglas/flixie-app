import 'package:flixie_app/features/home/presentation/widgets/home_tablet_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/home/presentation/widgets/cinema_list.dart';
import 'package:flixie_app/models/movie_short.dart';

void main() {
  testWidgets(
      'personal watchlist state, pending protection and optional star rating',
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
    expect(find.text('8.2'), findsOneWidget);
    expect(find.textContaining('TMDB'), findsNothing);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    final outline = find.byIcon(Icons.bookmark_outline_rounded);
    expect(outline, findsOneWidget);
    expect(find.byIcon(Icons.bookmark_add_outlined), findsNothing);
    expect(tester.getTopRight(outline).dx,
        tester.getTopRight(find.byType(CinemaList)).dx);
    expect(tester.getTopLeft(outline).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.text('The Odyssey')).dy));
    expect(find.byTooltip('Remove from watchlist'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove from watchlist'));
    expect(saves, 1);
    await show(pending: true);
    final button = tester.widget<IconButton>(find.byType(IconButton).first);
    expect(button.onPressed, isNull);
    expect(find.textContaining('friends'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'tablet cinema swipes to later titles and keeps save/details actions',
      (tester) async {
    final opened = <int>[], saved = <int>[];
    final movies =
        List.generate(8, (i) => MovieShort(id: i, name: 'Cinema $i'));
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
            body: HomeTabletScope(
                child: SizedBox(
                    width: 650,
                    child: CinemaList(
                        movies: movies,
                        savedIds: const {7},
                        onDetails: (m) => opened.add(m.id),
                        onSave: (m) => saved.add(m.id),
                        onTrailer: (_) {}))))));
    final rail = find.byKey(const ValueKey('tablet-cinema-rail'));
    expect(find.text('Cinema 7').hitTestable(), findsNothing);
    for (var i = 0; i < 4; i++) {
      await tester.drag(rail, const Offset(-600, 0));
      await tester.pumpAndSettle();
    }
    expect(find.text('Cinema 7').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Cinema 7'));
    await tester.tap(find.byTooltip('Remove from watchlist'));
    expect(opened, [7]);
    expect(saved, [7]);
    expect(find.text('Show more cinema releases'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
