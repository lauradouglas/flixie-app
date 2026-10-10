import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/social/presentation/pages/community_discussion_screen.dart';
import '../../../community_space_test.dart' show SpaceFixture;
import '../../../support/watchlist_auth.dart';

class DiscussionBaselineFixture extends SpaceFixture {
  DiscussionBaselineFixture() {
    spoiler = false;
  }
  final replies = Completer<Map<String, dynamic>>();
  var focusedReads = 0;
  @override
  Future<Map<String, dynamic>> get(int id, String path,
      [Map<String, String> query = const {}]) async {
    if (path.endsWith('/replies')) return replies.future;
    if (path == '/replies/target') {
      focusedReads++;
      return row(0);
    }
    return super.get(id, path, query);
  }

  Map<String, dynamic> row(int i) => {
        'id': i == 0 ? 'target' : 'reply-$i',
        'user': author,
        'body': 'Alien discussion reply $i'
      };
}

void main() {
  testWidgets('thread is useful before replies and focus reuses a loaded reply',
      (tester) async {
    final fixture = DiscussionBaselineFixture();
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
                initialReplyId: 'target'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('A thoughtful ending'), findsOneWidget);
    fixture.replies.complete({
      'items': [for (var i = 0; i < 40; i++) fixture.row(i)],
      'nextCursor': null
    });
    await tester.pumpAndSettle();
    expect(fixture.focusedReads,
        const bool.fromEnvironment('DISCUSSION_BEFORE') ? 1 : 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
