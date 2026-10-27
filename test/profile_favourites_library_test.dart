import 'package:flixie_app/features/profile/presentation/widgets/favourite_poster_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/profile/presentation/pages/profile_screen.dart';

void main() {
  testWidgets(
      'empty favourites keep films shows and people in collection order',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: ProfileFavouritesLibrary(
                    movies: [], shows: [], people: [])))));
    final films = find.text('Favourite films');
    final shows = find.text('Favourite shows');
    final people = find.text('Favourite people');
    expect(tester.getTopLeft(films).dy, lessThan(tester.getTopLeft(shows).dy));
    expect(tester.getTopLeft(shows).dy, lessThan(tester.getTopLeft(people).dy));
    expect(find.text('Add favourite films'), findsOneWidget);
    expect(find.text('Add favourite shows'), findsOneWidget);
    expect(find.text('Add favourite people'), findsOneWidget);
  });
  testWidgets('editable profile shows use the same poster rail as films',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: SingleChildScrollView(
          child: ProfileFavouritesLibrary(movies: const [], shows: const [
        {
          'show': {'id': 1, 'title': 'One Piece'}
        }
      ], people: const [], onChoosePerson: (_, __) async {})),
    )));
    final rail =
        tester.widget<FavouritePosterRail>(find.byType(FavouritePosterRail));
    expect(rail.title, 'Favourite shows');
    expect(rail.onRank, isNotNull);
    expect(find.text('One Piece'), findsOneWidget);
    expect(find.text('All (1)'), findsOneWidget);
    expect(find.byTooltip('Rank shows'), findsOneWidget);
    expect(find.text('1 favourite'), findsNothing);
  });

  testWidgets('saved shows and people remain visible and open their galleries',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: ProfileFavouritesLibrary(movies: [], shows: [
      {
        'show': {'id': 1, 'title': 'One Piece'}
      }
    ], people: [
      {'id': 2, 'name': 'Sigourney Weaver'}
    ])))));
    expect(find.text('One Piece'), findsOneWidget);
    expect(find.text('Sigourney Weaver'), findsOneWidget);
    await tester.ensureVisible(find.text('All (1)').last);
    await tester.tap(find.text('All (1)').last);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Sigourney Weaver'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
