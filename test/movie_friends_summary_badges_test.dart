import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/movies/presentation/widgets/movie_friends_summary_badges.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'package:flixie_app/models/movie_friend_activity.dart';

void main() {
  testWidgets(
      'summary averages only ratings, counts each status and respects privacy',
      (tester) async {
    final privacy = MovieRatingPrivacy()
      ..userId = 'me'
      ..loaded = true;
    addTearDown(privacy.dispose);
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: privacy,
        child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
                body: MediaQuery(
                    data: MediaQueryData(textScaler: TextScaler.linear(2)),
                    child: MovieFriendsSummaryBadges(movieId: 1, activities: [
                      MovieFriendActivity(
                          userId: 'a',
                          username: 'A',
                          watched: true,
                          onWatchlist: false,
                          favorited: true,
                          rating: 8,
                          recommended: true),
                      MovieFriendActivity(
                          userId: 'b',
                          username: 'B',
                          watched: true,
                          onWatchlist: false,
                          favorited: false,
                          rating: 10,
                          recommended: true),
                      MovieFriendActivity(
                          userId: 'c',
                          username: 'C',
                          watched: false,
                          onWatchlist: true,
                          favorited: false),
                    ]))))));
    expect(find.text('9.0/10 avg'), findsOneWidget);
    expect(find.byTooltip('2 friends recommend'), findsOneWidget);
    expect(find.byTooltip('On 1 friends’ watchlists'), findsOneWidget);
    expect(find.byTooltip('Favourited by 1 friends'), findsOneWidget);
    expect(tester.takeException(), isNull);
    privacy.enabled = true;
    // Rebuild through the public rating update notification.
    privacy.ratingSaved('me', 2, 8);
    await tester.pump();
    expect(find.text('9.0/10 avg'), findsNothing);
    expect(find.byIcon(Icons.thumb_up_alt_rounded), findsOneWidget);
    privacy.ratingSaved('me', 1, 9);
    await tester.pump();
    expect(find.text('9.0/10 avg'), findsOneWidget);
  });
}
