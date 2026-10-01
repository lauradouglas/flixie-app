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
    await tester.ensureVisible(find.text('See all').last);
    await tester.tap(find.text('See all').last);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Sigourney Weaver'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
