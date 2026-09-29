import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'package:flixie_app/features/social/presentation/pages/community_space_screen.dart';
import '../test/community_space_test.dart'
    show SpaceFixture, SpaceMembership, MentionFixture;
import '../test/support/watchlist_auth.dart';
import 'package:flixie_app/features/social/presentation/pages/community_discussion_screen.dart';

void main() {
  patrolTest('mention a member while replying to their comment', ($) async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final fixture = MentionFixture()..spoiler = false;
    final auth = TestAuth();
    addTearDown(auth.dispose);
    await $.pumpWidgetAndSettle(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: CommunityDiscussionScreen(
                communityId: -1,
                discussionId: 'thread',
                service: fixture,
                joined: true))));
    await $('Reply').scrollTo().tap();
    await $('Replying to @Ellis').waitUntilVisible();
    await $(find.byType(TextField)).scrollTo().enterText('Hi @El');
    await $('@Ellis').scrollTo().tap();
    await $(find.byTooltip('Post reply')).scrollTo().tap();
    expect(fixture.payload?['mentionIds'], ['ellis']);
    expect(fixture.payload?['parentReplyId'], 'parent');
  });
  patrolTest('join Anime, reveal a discussion, reply and resume', ($) async {
    // Isolate native fixture preferences from any simulator account.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final fixture = SpaceFixture()..joined = false;
    final membership = SpaceMembership(fixture);
    final auth = TestAuth();
    addTearDown(auth.dispose);
    await $.pumpWidgetAndSettle(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<MovieRatingPrivacy>(
              create: (_) => MovieRatingPrivacy(loadRatings: (_) async => {129})
                ..syncUser('viewer'))
        ],
        child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: CommunitySpaceScreen(
                communityId: -1, service: fixture, membership: membership))));
    if (const bool.fromEnvironment('COMMUNITY_NATIVE_CAPTURE')) {
      // A bounded pause lets simctl capture the actual native screen.
      debugPrint('COMMUNITY_CAPTURE_READY');
      await Future<void>.delayed(const Duration(seconds: 15));
    }
    await $('Join').tap();
    expect(membership.writes, 0);
    await $(find.widgetWithText(FilledButton, 'Join')).tap();
    expect(membership.writes, 1);
    await $('Spoiler discussion').tap();
    expect(find.text('A thoughtful ending'), findsNothing);
    await $('Reveal discussion').tap();
    await $('A thoughtful ending').waitUntilVisible();
    await $(find.byType(TextField)).scrollTo().enterText('My reply');
    await $(find.byTooltip('Post reply')).scrollTo().tap();
    await $('My reply').waitUntilVisible();
    expect(fixture.posts, 1);
    await $.platform.mobile.pressHome();
    await $.platform.mobile.openApp();
    await $('My reply').waitUntilVisible();
  });
}
