import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/favorite_movie.dart';
import 'package:flixie_app/features/profile/presentation/widgets/favourite_limit_sheet.dart';
import 'package:flixie_app/features/profile/presentation/widgets/favourite_ranking_sheet.dart';
import 'watchlist_recommendation_batch_test.dart' show TestAuth;

class FavouriteAuth extends TestAuth {
  @override
  User get dbUser => User(
      id: 'viewer',
      username: 'Me',
      email: '',
      iconColorId: 0,
      completedSetup: true,
      darkMode: false,
      favoriteMovies: List.generate(
          10,
          (i) => FavoriteMovie(
              id: 'fav-$i',
              userId: 'viewer',
              movieId: i + 1,
              rank: i + 1,
              movie: {'title': 'Film ${i + 1}'})));
}

void main() {
  testWidgets(
      'full list opens removal picker directly and cancellation adds nothing',
      (tester) async {
    var added = false;
    final auth = FavouriteAuth();
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
            home: Scaffold(
                body: Builder(
                    builder: (context) => TextButton(
                        onPressed: () => showFavouriteLimitPrompt(context,
                                type: FavouriteLimitType.movie,
                                onSpaceMade: () async {
                              added = true;
                            }),
                        child: const Text('Add')))))));
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Which favourite should make room?'), findsOneWidget);
    expect(find.text('Film 1'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(added, isFalse);
  });
  testWidgets(
      'ranking editor supports accessible moves without changing saved order before save',
      (tester) async {
    final auth = FavouriteAuth();
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
            home: Scaffold(
                body: Builder(
                    builder: (context) => TextButton(
                        onPressed: () =>
                            showFavouriteRankingSheet(context, shows: false),
                        child: const Text('Rank')))))));
    await tester.tap(find.text('Rank'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Move down').first);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Film 2')).dy,
        lessThan(tester.getTopLeft(find.text('Film 1')).dy));
    expect(auth.dbUser.favoriteMovies!.first.movieId, 1);
  });
}
