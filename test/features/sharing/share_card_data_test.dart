import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flixie_app/features/sharing/models/share_card_data.dart';
import 'package:flixie_app/features/sharing/presentation/widgets/flixie_share_cards.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/models/user.dart';

void main() {
  const user = User(
    id: 'user-1',
    firstName: 'Laura',
    lastName: 'Douglas',
    username: 'dougasaur',
    email: 'laura@example.com',
    iconColorId: 1,
    completedSetup: true,
    darkMode: true,
    initials: 'LD',
    iconColor: {'hexCode': '#00D1C7'},
  );

  test('rating mapping normalises identity, poster and deep link', () {
    final data = ShareCardData.rating(
      mediaType: ShareCardMediaType.movie,
      mediaId: 42,
      title: '  The Film  ',
      posterPath: '/poster.jpg',
      user: user,
      rating: 9,
      recommended: true,
      note: '  A proper favourite.  ',
    );

    expect(data.displayName, 'Laura Douglas');
    expect(data.username, 'dougasaur');
    expect(data.initials, 'LD');
    expect(data.title, 'The Film');
    expect(data.posterUrl, 'https://image.tmdb.org/t/p/w780/poster.jpg');
    expect(data.note, 'A proper favourite.');
    expect(data.deepLink, 'flixie://movies/42?source=shared_link');
    expect(data.avatarColorValue, 0xFF00D1C7);
  });

  test('review mapping removes placeholder title and truncates long copy', () {
    final review = _review(
      title: 'Untitled review',
      body: List.filled(80, 'thoughtful').join(' '),
    );
    final data = ShareCardData.review(
      mediaType: ShareCardMediaType.show,
      mediaId: 7,
      title: 'Show Name',
      posterPath: null,
      user: user,
      review: review,
    );

    expect(data.reviewTitle, isNull);
    expect(data.reviewExcerpt, endsWith('…'));
    expect(data.reviewExcerpt!.length, lessThanOrEqualTo(280));
    expect(data.deepLink, 'flixie://shows/7?source=shared_link');
  });

  testWidgets('optional rating content is omitted cleanly', (tester) async {
    final data = ShareCardData.rating(
      mediaType: ShareCardMediaType.show,
      mediaId: 7,
      title: 'Show Name',
      posterPath: null,
      user: user,
      rating: 8,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 640,
              child: FlixieShareCard(data: data),
            ),
          ),
        ),
      ),
    );

    expect(find.text('8.0'), findsOneWidget);
    expect(find.text('Recommends'), findsNothing);
    expect(find.text("Doesn't recommend"), findsNothing);
  });

  testWidgets('poster-led rating layout handles a note and recommendation',
      (tester) async {
    final data = ShareCardData.rating(
      mediaType: ShareCardMediaType.movie,
      mediaId: 42,
      title: 'The Lord of the Rings: The Return of the King',
      posterPath: null,
      user: user,
      rating: 9,
      recommended: true,
      note: 'Beautiful, epic and surprisingly emotional.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FlixieShareCard(data: data),
        ),
      ),
    );

    expect(
        find.textContaining('recommends', findRichText: true), findsOneWidget);
    expect(find.text('Beautiful, epic and surprisingly emotional.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('watch note can be excluded from the exported card',
      (tester) async {
    const longUsernameUser = User(
      id: 'user-2',
      username: 'dougasaur-and-the-movie-club',
      email: 'club@example.com',
      iconColorId: 1,
      completedSetup: true,
      darkMode: true,
    );
    final data = ShareCardData.rating(
      mediaType: ShareCardMediaType.movie,
      mediaId: 42,
      title: 'The Film',
      posterPath: null,
      user: longUsernameUser,
      rating: 8,
      recommended: false,
      note: 'Keep this private.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FlixieShareCard(data: data, showNote: false),
        ),
      ),
    );

    expect(find.text('Keep this private.'), findsNothing);
    expect(find.byIcon(Icons.thumb_down_alt_rounded), findsOneWidget);
    expect(
        find.textContaining('@dougasaur-and-the-movie-club',
            findRichText: true),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('review card keeps the shared verdict-first structure',
      (tester) async {
    final data = ShareCardData.review(
      mediaType: ShareCardMediaType.movie,
      mediaId: 42,
      title: 'The Film',
      posterPath: null,
      user: user,
      review: _review(
        title: 'A lasting favourite',
        body: 'The ending stayed with me long after the credits.',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: FlixieShareCard(data: data))),
    );

    expect(find.text('8.0'), findsOneWidget);
    expect(find.text('A lasting favourite'), findsOneWidget);
    expect(
      find.text('The ending stayed with me long after the credits.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Review _review({required String title, required String body}) => Review(
      id: 'review-1',
      userId: 'user-1',
      showId: 7,
      rating: 8,
      title: title,
      body: body,
      upvotes: 0,
      downvotes: 0,
      containsSpoilers: false,
      language: 'en',
      recommended: true,
      createdAt: '2026-08-10T12:00:00Z',
      updatedAt: '2026-08-10T12:00:00Z',
    );
