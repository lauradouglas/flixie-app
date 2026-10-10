import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:patrol/patrol.dart';
import 'package:flixie_app/models/favorite_movie.dart';
import 'package:flixie_app/features/profile/presentation/widgets/favourite_poster_rail.dart';
import '../test/features/profile/profile_screen_test.dart'
    show ProfileScreenFixture, openProfileTab;

void main() {
  patrolTest(
      'Profile gallery and tabs keep favourites reachable and Stats lazy',
      ($) async {
    final f = ProfileScreenFixture();
    addTearDown(f.dispose);
    f.auth.account = f.auth.account!.copyWith(
        favoriteMovies: List.generate(
            10,
            (i) => FavoriteMovie(
                    id: 'fixture-$i',
                    movieId: i + 1,
                    userId: 'viewer',
                    rank: i + 1,
                    movie: {
                      'title': i == 9
                          ? 'Spider-Man'
                          : i == 0
                              ? 'The Odyssey'
                              : i == 1
                                  ? 'Alien'
                                  : 'Fixture film ${i + 1}'
                    })));
    await http.runWithClient(() async {
      await $.pumpWidgetAndSettle(f.app(1.5));
      expect(f.paths.where((p) => p.contains('/wrapped/')), isEmpty);
      await $(find.descendant(
              of: find.byType(FavouritePosterRail).first,
              matching: find.text('See all')))
          .tap();
      await $.tester.scrollUntilVisible(find.text('Spider-Man'), 200,
          scrollable: find.descendant(
              of: find.byType(BottomSheet), matching: find.byType(Scrollable)));
      await $.pumpAndSettle();
      expect(find.text('Spider-Man'), findsOneWidget);
      await $(find.byTooltip('Close')).tap();
      await openProfileTab($.tester, 'Activity');
      await openProfileTab($.tester, 'Stats');
      expect(f.paths.where((p) => p.contains('/wrapped/')), hasLength(1));
      await openProfileTab($.tester, 'Library');
      await openProfileTab($.tester, 'Stats');
      expect(f.paths.where((p) => p.contains('/wrapped/')), hasLength(1));
      expect($.tester.takeException(), isNull);
    }, () => f.client);
  });
}
