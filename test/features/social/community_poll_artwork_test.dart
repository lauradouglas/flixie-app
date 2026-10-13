import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/social/presentation/widgets/discussion/community_poll_artwork.dart';

void main() {
  test(
      'poll images use w185 rows and at most w500 winners, even from original URLs',
      () {
    expect(pollPosterUrl('/poster.jpg'),
        'https://image.tmdb.org/t/p/w185/poster.jpg');
    expect(pollPosterUrl('/poster.jpg', winner: true),
        'https://image.tmdb.org/t/p/w500/poster.jpg');
    expect(pollPosterUrl('https://image.tmdb.org/t/p/original/poster.jpg'),
        'https://image.tmdb.org/t/p/w185/poster.jpg');
    expect(
        pollPosterUrl('https://image.tmdb.org/t/p/w1280/poster.jpg',
            winner: true),
        'https://image.tmdb.org/t/p/w500/poster.jpg');
    for (final path in [
      null,
      '',
      '//other.test/huge.jpg',
      'https://other.test/huge.jpg',
      '/../../huge.jpg'
    ]) {
      expect(pollPosterUrl(path), isNull);
    }
  });

  Future<void> show(WidgetTester t, List<int> votes) =>
      t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: CommunityPollOutcome(
        options: [
          for (var i = 0; i < votes.length; i++)
            {
              'title': ['Spirited Away', 'Attack on Titan'][i],
              'votes': votes[i]
            }
        ],
        total: votes.fold(0, (a, b) => a + b),
      )))));

  testWidgets('closed poll celebrates the actual winner', (t) async {
    await show(t, [2, 1]);
    expect(find.text('Community winner'), findsOneWidget);
    expect(find.text('Spirited Away'), findsOneWidget);
    expect(find.text('67% · 2 of 3 votes'), findsOneWidget);
    expect(find.text('Attack on Titan'), findsNothing);
  });
  testWidgets('ties show all joint winners and zero votes invent no winner',
      (t) async {
    await show(t, [2, 2]);
    expect(find.text('Joint winners'), findsOneWidget);
    expect(find.text('Spirited Away'), findsOneWidget);
    expect(find.text('Attack on Titan'), findsOneWidget);
    expect(find.text('50% · 2 of 4 votes'), findsNWidgets(2));
    await show(t, [0, 0]);
    expect(find.text('No winner this time.'), findsOneWidget);
    expect(find.byType(CommunityPollPoster), findsNothing);
  });
}
