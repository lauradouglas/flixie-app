import 'package:flixie_app/features/home/presentation/widgets/friends_activity_section.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_tile.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('one friends section expands and opens the full feed', (tester) async {
    final items = List.generate(4, (i) => ActivityListItem(
      id: '$i', userId: 'friend-$i', username: 'Friend $i',
      firstName: 'Friend', lastName: '', removed: false,
      createdAt: '2026-09-24', updatedAt: '2026-09-24',
      type: ActivityListType.movieRating, movieId: i + 1,
      mediaTitle: 'Film $i', mediaRating: 9, profileBadges: const [],
    ));
    var expanded = false;
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => Scaffold(body: SingleChildScrollView(
        child: StatefulBuilder(builder: (context, setState) => FriendsActivitySection(
          activity: items, expanded: expanded,
          onExpand: () => setState(() => expanded = true),
        )),
      ))),
      GoRoute(path: '/friends-activity', builder: (_, __) => const Scaffold(body: Text('Full feed'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('Friends’ activity'), findsOneWidget);
    expect(find.byType(ActivityTile), findsNWidgets(3));
    expect(find.byType(ProfileAvatarView), findsNWidgets(3));
    expect(find.text('Friend 0'), findsOneWidget);
    await tester.ensureVisible(find.text('Show 1 more'));
    await tester.tap(find.text('Show 1 more'));
    await tester.pumpAndSettle();
    expect(find.byType(ActivityTile), findsNWidgets(4));
    await tester.ensureVisible(find.text('See all'));
    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();
    expect(find.text('Full feed'), findsOneWidget);
  });
}
