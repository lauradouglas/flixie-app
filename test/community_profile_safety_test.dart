import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/core/safety/safety_service.dart';
import 'package:flixie_app/features/social/presentation/pages/community_profile_screen.dart';
import 'community_features_test.dart' show DiscussionFixture;

void main() {
  testWidgets(
      'Community profile can report and block a user, hiding their content immediately',
      (tester) async {
    SafetyService.reset();
    addTearDown(SafetyService.reset);
    final writes = <String, Map<String, dynamic>>{};
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
          home: CommunityProfileScreen(
              userId: 'friend', service: DiscussionFixture())));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('User safety options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report user'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spam or scam'));
      await tester.pumpAndSettle();
      expect(
          writes['/safety/reports'], containsPair('reportedUserId', 'friend'));
      expect(writes['/safety/reports'], containsPair('targetType', 'USER'));
      expect(writes['/safety/reports'], containsPair('reason', 'SPAM'));
      await tester.tap(find.byTooltip('User safety options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block user'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();
      expect(writes['/safety/blocks'], containsPair('blockedUserId', 'friend'));
      expect(SafetyService.isBlocked('friend'), true);
      expect(find.text('This user is blocked.'), findsOneWidget);
      expect(find.text('I love thoughtful films and sharing recommendations.'),
          findsNothing);
      expect(find.byTooltip('User safety options'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              writes[request.url.path] =
                  Map<String, dynamic>.from(jsonDecode(request.body));
              return http.Response(
                  request.url.path.endsWith('/blocks') ? '' : '{}',
                  request.url.path.endsWith('/blocks') ? 204 : 201);
            }));
  });
}
