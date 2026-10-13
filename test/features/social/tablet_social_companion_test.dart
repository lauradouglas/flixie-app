import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/watch_request.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/social/presentation/widgets/social_tablet_companion.dart';
import '../../support/watchlist_auth.dart';

class PlansAuth extends TestAuth {
  String viewer = 'viewer';
  @override
  User get dbUser => super.dbUser.copyWith(id: viewer);
  @override
  List<WatchRequest> get cachedWatchRequests => [
        WatchRequest.fromJson({
          'id': 'fictional-plan',
          'requesterId': 'viewer',
          'recipientId': 'sam',
          'status': 'ACCEPTED',
          'type': 'MOVIE_WATCH_REQUEST',
          'movie': {'id': 348, 'title': 'Alien'},
          'recipient': {
            'id': 'sam',
            'username': 'Sam',
            'profileBadges': ['FOUNDER']
          },
        })
      ];
}

void main() {
  testWidgets(
      'sidebar plan preserves badge, opens detail, and clears for new viewer',
      (t) async {
    final auth = PlansAuth();
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: SocialTabletCompanion())),
      GoRoute(
          path: '/watch-requests/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Plan ${state.pathParameters['id']}'))),
    ]);
    addTearDown(auth.dispose);
    addTearDown(router.dispose);
    await t.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth, child: MaterialApp.router(routerConfig: router)));
    await t.pumpAndSettle();
    expect(
        t
            .widget<ProfileAvatarView>(find.byType(ProfileAvatarView))
            .profileBadges,
        ['FOUNDER']);
    await t.tap(find.text('Alien'));
    await t.pumpAndSettle();
    expect(find.text('Plan fictional-plan'), findsOneWidget);
    router.pop();
    await t.pumpAndSettle();
    auth.viewer = 'other';
    auth.notifyOnly();
    await t.pumpAndSettle();
    expect(find.text('Alien'), findsNothing);
    expect(t.takeException(), isNull);
  });
}
