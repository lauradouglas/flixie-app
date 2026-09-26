import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_tile.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/models/activity_list_item.dart';

void main() {
  for (final type in ActivityListType.values) {
    testWidgets(
        '${type.value} renders at narrow width and large text without losing badges',
        (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final person = type == ActivityListType.favoritePerson;
      final list = type == ActivityListType.movieListAdded;
      final show = type.value.contains('show');
      final item = ActivityListItem(
          id: 'one',
          userId: 'author',
          username: 'Someone with a long username',
          firstName: '',
          lastName: '',
          removed: false,
          createdAt: '2026-09-25T12:00:00Z',
          updatedAt: '',
          type: type,
          movieId: person || list || show ? null : 1,
          showId: show ? 2 : null,
          personId: person ? 3 : null,
          mediaTitle: person
              ? 'A favourite filmmaker'
              : 'A film with a meaningful and long title',
          listId: list ? 'list' : null,
          listOwnerId: list ? 'author' : null,
          listName: list ? 'Weekend favourites' : null,
          listAdditionCount: list ? 8 : null,
          mediaRating: 8,
          profileBadges: const ['founder'],
          isRewatch: true,
          watchCount: 3);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                  body: SingleChildScrollView(
                      child: Padding(
                          padding: const EdgeInsets.all(20),
                          child:
                              ActivityTile(item: item, feedStyle: true)))))));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<ProfileAvatarView>(find.byType(ProfileAvatarView))
              .profileBadges,
          ['founder']);
      if (person) {
        expect(find.text('Person'), findsOneWidget);
        expect(find.text('8/10'), findsNothing);
      }
      if (list) {
        expect(find.text('Weekend favourites'), findsOneWidget);
        expect(find.text('8 titles'), findsOneWidget);
        expect(find.text('8/10'), findsNothing);
      }
      if (type == ActivityListType.movieWatched ||
          type == ActivityListType.showWatched) {
        expect(find.textContaining('3 times'), findsOneWidget);
      }
      expect(find.text('View review'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('spoiler text is hidden and a long review can be expanded',
      (tester) async {
    final body =
        List.filled(30, 'A thoughtful review with a surprising ending.')
            .join(' ');
    final item = ActivityListItem.fromJson({
      'id': 'review',
      'userId': 'friend',
      'username': 'LauraD',
      'type': 'movie-review',
      'movieId': 1,
      'movie': {'title': 'Film'},
      'body': body,
      'containsSpoilers': true,
      'createdAt': '2026-09-25T12:00:00Z',
      'updatedAt': ''
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: ActivityTile(item: item, feedStyle: true)))));
    await tester.pumpAndSettle();
    expect(find.text(body), findsNothing);
    await tester.tap(find.text('Show review · contains spoilers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read more'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text(body)).maxLines, isNull);
  });
}
