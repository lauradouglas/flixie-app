import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/features/home/presentation/widgets/home_community_preview.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'package:flixie_app/models/activity_list_item.dart';

void main() {
  testWidgets(
      'tablet preview preserves badges, rating privacy and post/profile actions',
      (tester) async {
    final privacy = MovieRatingPrivacy()
      ..userId = 'viewer'
      ..loaded = true;
    addTearDown(privacy.dispose);
    final actions = <String>[];
    const item = ActivityListItem(
        id: 'fixture-rating',
        userId: 'fictional-jamie',
        username: 'Jamie',
        firstName: 'Jamie',
        lastName: 'Example',
        removed: false,
        createdAt: '2026-10-27',
        updatedAt: '2026-10-27',
        type: ActivityListType.movieRating,
        movieId: 348,
        mediaTitle: 'Alien',
        mediaRating: 8.5,
        notes: 'Private spoiler text must not appear in a preview.',
        profileBadges: ['EARLY_ADOPTER']);
    Future<void> show() => tester.pumpWidget(ChangeNotifierProvider.value(
        value: privacy,
        child: MaterialApp(
            home: Scaffold(
                body: SizedBox(
                    width: 300,
                    child: HomeCommunityPreview(
                        item: item,
                        onOpen: () => actions.add('post'),
                        onProfile: () => actions.add('profile')))))));
    await show();
    expect(
        tester
            .widget<ProfileAvatarView>(find.byType(ProfileAvatarView))
            .profileBadges,
        ['EARLY_ADOPTER']);
    expect(find.text('8.5/10'), findsOneWidget);
    expect(find.textContaining('Private spoiler'), findsNothing);
    await tester.tap(find.text('Jamie'));
    await tester.tap(find.text('View post'));
    expect(actions, ['profile', 'post']);
    privacy.enabled = true;
    await show();
    await tester.pump();
    expect(find.text('8.5/10'), findsNothing);
    expect(find.text('Alien'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
