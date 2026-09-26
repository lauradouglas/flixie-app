import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/features/social/presentation/pages/friends_activity_screen.dart';
import 'community_activity_feed_test.dart' show FixtureCommunity;

class _Auth extends ChangeNotifier implements AuthProvider {
  @override
  User? get dbUser => null;
  @override
  List<ActivityListItem>? get cachedFriendsActivity => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
      'Activity opens Friends and Community can be browsed without opting in',
      (tester) async {
    final auth = _Auth();
    addTearDown(auth.dispose);
    final service = FixtureCommunity();
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
            home: FriendsActivityScreen(communityService: service))));
    await tester.pumpAndSettle();
    expect(
        find.text('No friend activity in the last two weeks.'), findsOneWidget);
    expect(find.text('Around Flixie'), findsOneWidget);
    await tester.tap(find.byTooltip('Around Flixie sharing'));
    await tester.pumpAndSettle();
    expect(find.text('Share on Around Flixie'), findsOneWidget);
    await tester.tap(find.byTooltip('Close settings'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Around Flixie sharing'), findsOneWidget);
    expect(service.enabled, false);
    expect(find.text('A friend with a longer name'), findsOneWidget);
    await tester.tap(find.text('Friends'));
    await tester.pumpAndSettle();
    expect(
        find.text('No friend activity in the last two weeks.'), findsOneWidget);
  });
}
