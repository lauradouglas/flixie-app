import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/features/authentication/presentation/pages/signup_screen.dart';
import '../../app/router/watch_invite_startup_test.dart' show InviteAuth;
import '../guest/guest_router_test.dart' show GuestReferrals;
import '../movies/movie_detail_action_flow_test.dart' show ActionAnalytics;

void main() {
  testWidgets('referral is optional and expands to accept code or username',
      (tester) async {
    final auth = InviteAuth();
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<AnalyticsController>.value(
              value: ActionAnalytics()),
        ],
        child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: SignupScreen(referralStore: GuestReferrals()))));
    expect(find.text('Weak'), findsNothing,
        reason: 'No strength judgement before typing');
    final toggle = find.byKey(const ValueKey('signup-referral-toggle'));
    expect(tester.widget<ExpansionTile>(toggle).initiallyExpanded, isFalse);
    await tester.ensureVisible(toggle);
    await tester.tap(find.text('Referred by a friend?'));
    await tester.pumpAndSettle();
    expect(find.text('Referral code or username'), findsWidgets);
    expect(find.text('Enter a referral code or your friend’s @username.'),
        findsOneWidget);
    await tester.tap(find.text('Referred by a friend?'));
    await tester.pumpAndSettle();
    expect(
        find
            .text('Enter a referral code or your friend’s @username.')
            .hitTestable(),
        findsNothing);
    expect(tester.takeException(), isNull);
  });
}
