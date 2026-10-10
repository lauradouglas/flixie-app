import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import '../test/features/profile/friend_profile_screen_test.dart'
    show FriendScreenFixture, openFriendTab;

void main() {
  patrolTest('Preview incoming friend request can be accepted', ($) async {
    final f = FriendScreenFixture()
      ..friends = false
      ..preview = true
      ..pending = true;
    f.install();
    addTearDown(f.dispose);
    await $.pumpWidgetAndSettle(f.app(1.5));
    await $.tester.ensureVisible(find.text('Accept'));
    await $.pumpAndSettle();
    await $(find.text('Accept')).tap();
    expect(f.updates.single['status'], 'ACCEPTED');
    expect(find.text('Accept'), findsNothing);
    expect(find.text('Decline'), findsNothing);
    expect($.tester.takeException(), isNull);
  });

  patrolTest('Friend Profile gallery and tab returns stay reachable',
      ($) async {
    final f = FriendScreenFixture();
    f.install();
    addTearDown(f.dispose);
    await $.pumpWidgetAndSettle(f.app(1.5));
    final gallery = find.byTooltip('See all favourite movies');
    for (var i = 0; i < 15 && gallery.hitTestable().evaluate().isEmpty; i++) {
      await $.tester.drag(find.byType(ListView).first, const Offset(0, -200));
      await $.pumpAndSettle();
    }
    await $(gallery).tap();
    await $.tester.scrollUntilVisible(find.text('Spider-Man'), 200,
        scrollable: find.descendant(
            of: find.byType(GridView), matching: find.byType(Scrollable)));
    await $.pumpAndSettle();
    expect(find.text('Spider-Man'), findsOneWidget);
    await $.tester.tapAt(const Offset(10, 70));
    await $.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    for (final tab in ['Activity', 'Reviews', 'Overview', 'Reviews']) {
      await openFriendTab($.tester, tab);
    }
    expect(f.calls.where((p) => p.endsWith('/reviews')), hasLength(1));
    expect($.tester.takeException(), isNull);
  });
}
