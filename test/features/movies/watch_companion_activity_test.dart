import 'package:flixie_app/features/profile/presentation/widgets/watched_with_row.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/activity_reaction.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/features/profile/presentation/widgets/compact_activity_post.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/movies/presentation/widgets/movie_watch_history_section.dart';

void main() {
  test('multiple linked companions survive watch hydration and write payloads',
      () {
    final people = [
      {
        'id': 'sophie',
        'username': 'Sophie',
        'profileBadges': ['EARLY_ADOPTER']
      },
      {
        'id': 'casey',
        'username': 'Casey',
        'profileBadges': ['FOUNDER']
      },
    ];
    final entry = MovieWatchEntry.fromJson({
      'id': 'watch',
      'userId': 'author',
      'movieId': 348,
      'watchPlanConfirmations': [
        for (final person in people)
          {
            'request': {
              'id': 'plan-${person['id']}',
              'requesterId': 'author',
              'recipient': person,
            }
          }
      ],
    });
    expect(entry.allCompanions.map((person) => person.id), ['sophie', 'casey']);
    expect(
        MovieWatchEntry.fromJson(entry.toJson())
            .allCompanions
            .last
            .profileBadges,
        ['FOUNDER']);
    expect(
        LogMovieWatchRequest(
                movieId: 348,
                companionIds:
                    entry.allCompanions.map((person) => person.id).toList())
            .toJson()['companionIds'],
        ['sophie', 'casey']);
  });
  test('one shared plan hydrates all companions for its third participant', () {
    final entry = MovieWatchEntry.fromJson({
      'id': 'watch',
      'userId': 'ellis',
      'movieId': 348,
      'watchPlanConfirmations': [
        {
          'request': {
            'id': 'shared',
            'requesterId': 'casey',
            'recipientId': 'robin',
            'requester': {'id': 'casey', 'username': 'Casey'},
            'recipient': {'id': 'robin', 'username': 'Robin'},
            'participants': [
              {
                'user': {
                  'id': 'casey',
                  'username': 'Casey',
                  'profileBadges': ['FOUNDER']
                }
              },
              {
                'user': {
                  'id': 'robin',
                  'username': 'Robin',
                  'profileBadges': ['EARLY_ADOPTER']
                }
              },
              {
                'user': {'id': 'ellis', 'username': 'Ellis'}
              },
            ],
          }
        }
      ],
    });
    expect(entry.planId, 'shared');
    expect(entry.allCompanions.map((p) => p.id).toSet(), {'casey', 'robin'});
    expect(entry.allCompanions.firstWhere((p) => p.id == 'robin').profileBadges,
        ['EARLY_ADOPTER']);
  });
  testWidgets('multiple avatars wrap and personalise the viewer in activity',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 280,
                child: WatchedWithRow(viewerUserId: 'casey', companions: [
                  FriendshipUser(
                      id: 'sophie',
                      username: 'Sophie',
                      profileBadges: ['EARLY_ADOPTER']),
                  FriendshipUser(
                      id: 'casey',
                      username: 'Casey',
                      profileBadges: ['FOUNDER']),
                ])))));
    expect(find.text('Watched with Sophie and you'), findsOneWidget);
    expect(find.byType(ProfileAvatarView), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
  final json = <String, dynamic>{
    'id': 'watch',
    'userId': 'author',
    'movieId': 348,
    'type': 'watched_movie',
    'movie': {'title': 'Alien'},
    'companion': {
      'id': 'sophie',
      'username': 'Sophie',
      'profileBadges': [
        {'badge': 'EARLY_SUPPORTER'}
      ]
    },
  };
  test('activity companion survives parsing and avatar copies', () {
    final item = ActivityListItem.fromJson(json).copyWith();
    expect(item.companion?.username, 'Sophie');
    expect(item.companion?.profileBadges, ['EARLY_SUPPORTER']);
    expect(ActivityListItem.fromJson({...json, 'companion': null}).companion,
        isNull);
  });
  testWidgets('uses you for the viewer and names other companions',
      (tester) async {
    const companion = FriendshipUser(id: 'sophie', username: 'Sophie');
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: Column(children: [
      WatchedWithRow(companion: companion, viewerUserId: 'sophie'),
      WatchedWithRow(companion: companion, viewerUserId: 'other'),
    ]))));
    expect(find.text('Watched with you'), findsOneWidget);
    expect(find.text('Watched with Sophie'), findsOneWidget);
  });
  for (final width in [320.0, 820.0]) {
    testWidgets('watch entry and activity show companion at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
              body: SingleChildScrollView(
                  child: Column(children: [
            CompactActivityPost(
                item: ActivityListItem.fromJson(json),
                label: 'Watched',
                age: '',
                reactions: const ActivityReactionSummary()),
            MovieWatchHistorySection(
                entries: [MovieWatchEntry.fromJson(json)],
                loading: false,
                formatDate: (_) => '16/10/2026',
                onAdd: () {},
                onEdit: (_) {},
                onDelete: (_) {}),
          ])))));
      expect(find.text('Watched with Sophie'), findsNWidgets(2));
      final avatars =
          tester.widgetList<ProfileAvatarView>(find.byType(ProfileAvatarView));
      expect(
          avatars
              .where(
                  (avatar) => avatar.profileBadges.contains('EARLY_SUPPORTER'))
              .length,
          2);
      expect(tester.takeException(), isNull);
    });
  }
}
