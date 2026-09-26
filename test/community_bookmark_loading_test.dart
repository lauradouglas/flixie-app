import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/features/social/presentation/widgets/community_bookmark_button.dart';
import 'community_activity_feed_test.dart' as fixtures;

class SlowBookmarks extends fixtures.FixtureCommunity {
  Completer<void> pending = Completer<void>();
  int saves = 0;
  @override
  Future<void> save(ActivityListItem item, bool saved) async {
    saves++;
    await pending.future;
    await super.save(item, saved);
  }
}

void main() {
  for (final iconOnly in [true, false]) {
    testWidgets('bookmark spins until save/removal completes: icon=$iconOnly',
        (tester) async {
      final service = SlowBookmarks();
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: CommunityBookmarkButton(
        item: fixtures.fixture('first'),
        service: service,
        iconOnly: iconOnly,
      ))));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.bookmark_border));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(CircularProgressIndicator));
      expect(service.saves, 1);
      service.pending.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      service.pending = Completer<void>();
      await tester.tap(find.byIcon(Icons.bookmark));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      service.pending.completeError(Exception('offline'));
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      expect(
          find.text('Couldn’t update saved posts. Try again.'), findsOneWidget);
    });
  }
}
