import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'package:flixie_app/features/home/presentation/widgets/trending_friends_section.dart';
import 'package:flixie_app/features/movies/presentation/widgets/media_friend_activity_row.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/movie_friend_activity.dart';

void main() {
  testWidgets(
      'Home and movie friends show Rated without scores until own rating',
      (tester) async {
    final privacy = MovieRatingPrivacy()
      ..userId = 'me'
      ..loaded = true
      ..enabled = true;
    addTearDown(privacy.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: privacy,
        child: MaterialApp(
            home: Scaffold(
                body: Column(children: [
          const FriendsWatchingSection(activity: [
            ActivityListItem(
              id: 'a',
              userId: 'friend',
              username: 'Laura',
              firstName: '',
              lastName: '',
              movieId: 42,
              removed: false,
              createdAt: '',
              updatedAt: '',
              type: ActivityListType.movieWatched,
              mediaTitle: 'Fixture',
              mediaRating: 10,
            )
          ]),
          MediaFriendActivityRow(
              movieId: 42,
              onTap: () {},
              activity: const MovieFriendActivity(
                userId: 'friend',
                username: 'Laura',
                watched: true,
                watchCount: 4,
                favorited: false,
                onWatchlist: false,
                rating: 10,
                recommended: true,
              )),
        ])))));
    expect(find.text('Rated'), findsNWidgets(2));
    expect(find.textContaining('/10'), findsNothing);
    expect(find.text('4 times'), findsOneWidget);
    expect(find.byIcon(Icons.thumb_up_alt_rounded), findsOneWidget);
    expect(find.byTooltip('Rated 10 out of 10'), findsNothing);
    privacy.ratingSaved('me', 42, 8);
    await tester.pump();
    expect(find.text('10/10'), findsOneWidget);
    expect(find.text('10.0/10'), findsOneWidget);
  });
}
