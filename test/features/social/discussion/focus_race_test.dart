import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/safety/safety_service.dart';
import 'package:flixie_app/features/social/presentation/pages/community_discussion_screen.dart';
import '../../../community_space_test.dart' show SpaceFixture;
import '../../../support/watchlist_auth.dart';

class FocusRaceFixture extends SpaceFixture {
  FocusRaceFixture() {
    spoiler = false;
  }
  final focused = Completer<Map<String, dynamic>>();
  int focusReads = 0;
  @override
  Future<Map<String, dynamic>> get(int id, String path,
      [Map<String, String> query = const {}]) async {
    if (path == '/replies/late') {
      focusReads++;
      return focused.future;
    }
    return super.get(id, path, query);
  }
}

void main() {
  testWidgets(
      'moderation refresh prevents an old focused reply from reappearing',
      (tester) async {
    final fixture = FocusRaceFixture();
    final auth = TestAuth();
    addTearDown(auth.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
            home: CommunityDiscussionScreen(
                communityId: -1,
                discussionId: 'thread',
                service: fixture,
                joined: false,
                initialReplyId: 'late'))));
    await tester.pumpAndSettle();
    expect(fixture.focusReads, 1);
    SafetyService.changes.value++;
    await tester.pumpAndSettle();
    fixture.focused.complete(
        {'id': 'late', 'user': fixture.author, 'body': 'Old muted reply'});
    await tester.pumpAndSettle();
    expect(find.text('Old muted reply'), findsNothing);
    expect(find.text('Selected comment'), findsNothing);
    expect(find.text('A thoughtful ending'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
