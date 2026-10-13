import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/social/presentation/pages/community_discussion_screen.dart';
import 'package:flixie_app/features/social/presentation/pages/community_space_screen.dart';
import '../test/features/social/community_poll_test.dart' show PollFixture;
import '../test/support/watchlist_auth.dart';

void main() {
  for (final light in [true, false]) {
    patrolTest(
        'community poll single vote, real-title nomination and creation ${light ? 'light' : 'dark'}',
        ($) async {
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({});
      final fixture = PollFixture();
      final auth = TestAuth();
      addTearDown(auth.dispose);
      Widget app(Widget child) => ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
              theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
              home: child));
      await $.pumpWidgetAndSettle(app(CommunityDiscussionScreen(
          communityId: -1,
          discussionId: 'thread',
          service: fixture,
          joined: true)));
      await $('Spirited Away').scrollTo().tap();
      await $('Your pick').waitUntilVisible();
      await $('Attack on Titan').scrollTo().tap();
      expect(fixture.selected, 'show-option');
      expect(fixture.poll['totalVotes'], 21);
      await $('Best anime of all time?').scrollTo();
      if (const bool.fromEnvironment('COMMUNITY_NATIVE_CAPTURE')) {
        debugPrint('POLL_CAPTURE_${light ? 'LIGHT' : 'DARK'}_READY');
        await Future<void>.delayed(const Duration(seconds: 15));
      }
      await $('Add another title').scrollTo().tap();
      await $(find.byType(TextField).last).enterText('Nausica');
      await $('Search titles').scrollTo().tap();
      await $('Nausicaä of the Valley of the Wind').scrollTo().tap();
      expect(fixture.payload, {'movieId': 81});
      expect(fixture.options.length, 3);
      await $.pumpWidgetAndSettle(
          app(CommunitySpaceScreen(communityId: -1, service: fixture)));
      await $('Create a poll').scrollTo().tap();
      await $(find.byType(TextFormField).first)
          .enterText('What should we watch tonight?');
      for (final title in ['Spirited Away', 'Attack on Titan']) {
        await $('Add a film or series').scrollTo().tap();
        await $(find.byType(TextField).last).enterText(title);
        await $('Search titles').scrollTo().tap();
        await $(title).scrollTo().tap();
      }
      await $('Publish poll').scrollTo().tap();
      expect(fixture.payload?['poll'], {
        'options': [
          {'movieId': 129},
          {'showId': 1429}
        ]
      });
      await $('Create a poll').waitUntilVisible();
    });
  }
}
