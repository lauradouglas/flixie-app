import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/auth/pending_watch_invite_store.dart';
import 'package:flixie_app/features/guest/presentation/guest_access.dart';
import 'package:flixie_app/features/social/presentation/pages/watch_requests_screen.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import '../../../../patrol_test/support/store_screenshot_fixture.dart';
import '../../../../patrol_test/support/watch_plan_fixture.dart';
import '../../../support/api_fixture.dart';

class _InviteExitAuth extends StoreScreenshotAuth {
  _InviteExitAuth(this.completed);
  final bool completed;
  @override
  User get dbUser => super.dbUser.copyWith(completedSetup: completed);
}

void main() {
  for (final completed in [false, true]) {
    testWidgets('Home leaves the invited viewing when setup is $completed',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await PendingWatchInviteStore.beginLog('patrol-plan', 'store-viewer');
      GuestAccess.destination = '/watch-invites/${'a' * 43}';
      final api = WatchPlanFixture(status: 'ACCEPTED');
      api.plan['watchConfirmations'] = [
        {
          'id': 'saved-viewer-watch',
          'userId': 'store-viewer',
          'watched': true,
          'rating': 8
        }
      ];
      useApiFixture(MockClient(api.handle));
      final auth = _InviteExitAuth(completed);
      final router =
          GoRouter(initialLocation: '/watch-requests/patrol-plan', routes: [
        GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: Text('Home destination'))),
        GoRoute(
            path: '/onboarding',
            builder: (_, __) =>
                const Scaffold(body: Text('Setup destination'))),
        GoRoute(
            path: '/watch-requests/:id',
            builder: (_, __) => const WatchRequestsScreen(
                initialRequestId: 'patrol-plan', logOnOpen: true)),
      ]);
      await tester.pumpWidget(storeScreenshotApp(auth, router));
      await tester.pumpAndSettle();
      expect(find.byType(RewatchLogSheet), findsNothing);
      await tester.tap(find.byTooltip('Home'));
      await tester.pumpAndSettle();
      expect(find.text(completed ? 'Home destination' : 'Setup destination'),
          findsOneWidget);
      expect(await PendingWatchInviteStore.readLog('store-viewer'), isNull);
      expect(GuestAccess.destination, isNull);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      auth.dispose();
      GuestAccess.clear();
    });
  }
}
