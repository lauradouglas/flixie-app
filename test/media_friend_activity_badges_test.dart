import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/movies/presentation/widgets/media_friend_activity_row.dart';
import 'package:flixie_app/models/movie_friend_activity.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
        'friend badges wrap and row opens in ${dark ? 'dark' : 'light'} mode',
        (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var opened = false;
      await tester.pumpWidget(MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        home: Scaffold(
            body: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: MediaFriendActivityRow(
            activity: const MovieFriendActivity(
                userId: 'friend',
                username: 'LauraD',
                watched: true,
                watchCount: 4,
                rating: 10,
                recommended: true,
                favorited: true,
                onWatchlist: true,
                reviewed: true),
            onTap: () => opened = true,
          ),
        )),
      ));
      expect(find.text('4 times'), findsOneWidget);
      expect(find.text('10/10'), findsOneWidget);
      expect(find.text('Favourite'), findsNothing);
      expect(find.text('In watchlist'), findsNothing);
      final badges = tester.widgetList<Tooltip>(find.descendant(
          of: find.byType(Wrap), matching: find.byType(Tooltip)));
      expect(badges.map((badge) => badge.message), [
        'Watched 4 times',
        'Rated 10 out of 10',
        'Recommends',
        'Favourite',
        'In watchlist',
        'Reviewed',
      ]);
      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('LauraD'));
      expect(opened, isTrue);
    });
  }
}
