import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/social/presentation/widgets/social_groups_view.dart';
import 'package:flixie_app/features/social/presentation/widgets/invitation_card.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import '../../../patrol_test/support/runtime_database_fixture.dart';
import 'social_controllers_test.dart' show SocialAuth;

void main() {
  for (final switchAccount in [false, true]) {
    testWidgets(
        switchAccount
            ? 'create sheet closes after account change'
            : 'group creation is single flight and publishes the persisted group',
        (t) async {
      final auth = SocialAuth();
      addTearDown(auth.dispose);
      final analytics = AnalyticsController(
          backend: RuntimeAnalyticsBackend(),
          consentStore: RuntimeAnalyticsConsentStore());
      await analytics.initialize();
      addTearDown(analytics.dispose);
      final response = Completer<http.Response>();
      final writes = <Map<String, dynamic>>[];
      ApiClient.useClientForTesting(MockClient((r) async {
        if (r.method == 'POST' && r.url.path == '/groups') {
          writes.add(jsonDecode(r.body));
          return response.future;
        }
        return http.Response(
            jsonEncode(r.url.path.startsWith('/friends/')
                ? {
                    'friendships': [],
                    'pendingFriends': [],
                    'requestedFriends': []
                  }
                : []),
            200);
      }));
      addTearDown(() => ApiClient.useClientForTesting(null));
      await t.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<AnalyticsController>.value(value: analytics),
          ],
          child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(body: SocialGroupsView()))));
      await t.pumpAndSettle();
      await t.tap(find.text('Create').first);
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField).first, 'Alien Crew');
      await t.ensureVisible(find.text('Next'));
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      expect(find.text('Add Members'), findsOneWidget);
      if (switchAccount) {
        auth.viewer = 'other';
        auth.notifyOnly();
        await t.pumpAndSettle();
        expect(find.text('Add Members'), findsNothing);
        expect(writes, isEmpty);
      } else {
        await t.tap(find.text('Skip'));
        await t.tap(find.text('Skip'));
        expect(writes, hasLength(1));
        expect(writes.single['members'], [
          {'memberId': 'viewer', 'role': 'OWNER', 'inviteStatus': 'ACCEPTED'}
        ]);
        response.complete(http.Response(
            jsonEncode({
              'id': 'created',
              'name': 'Alien Crew',
              'ownerId': 'viewer',
              'visibility': 'PUBLIC'
            }),
            200));
        await t.pumpAndSettle();
        expect(auth.groups!.single.id, 'created');
        expect(find.text('Add Members'), findsNothing);
      }
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }

  for (final size in [
    const Size(320, 740),
    const Size(844, 390),
    const Size(768, 1024)
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
          'Groups search and decline remain usable at $size scale $scale',
          (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final auth = SocialAuth();
        addTearDown(auth.dispose);
        final analytics = AnalyticsController(
            backend: RuntimeAnalyticsBackend(),
            consentStore: RuntimeAnalyticsConsentStore());
        await analytics.initialize();
        addTearDown(analytics.dispose);
        final writes = <Map<String, dynamic>>[];
        ApiClient.useClientForTesting(MockClient((r) async {
          Object body = [];
          if (r.url.path == '/groups/user/viewer') {
            body = [
              for (final name in [
                'Alien Fans',
                'Odyssey Club',
                'Spider-Man Club'
              ])
                {
                  'id': name,
                  'name': name,
                  'ownerId': 'viewer',
                  'visibility': 'PRIVATE'
                }
            ];
          } else if (r.url.path.endsWith('/members')) {
            body = [
              {
                'groupId': r.url.path.split('/')[2],
                'memberId': 'viewer',
                'role': 'MEMBER',
                'user': {
                  'username': 'Fixture viewer',
                  'profileBadges': ['EARLY_ADOPTER']
                },
                'inviteStatus':
                    r.url.path.contains('Spider-Man') ? 'ACCEPTED' : 'PENDING'
              }
            ];
          } else if (r.url.path.endsWith('/inviteStatus')) {
            writes.add(jsonDecode(r.body));
            body = {};
          }
          return http.Response(jsonEncode(body), 200);
        }));
        addTearDown(() => ApiClient.useClientForTesting(null));
        await t.pumpWidget(MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: auth),
              ChangeNotifierProvider<AnalyticsController>.value(
                  value: analytics),
            ],
            child: MaterialApp(
                theme: AppTheme.darkTheme,
                builder: (_, child) => MediaQuery(
                    data: MediaQueryData(
                        size: size, textScaler: TextScaler.linear(scale)),
                    child: child!),
                home: const Scaffold(body: SocialGroupsView()))));
        await t.pumpAndSettle();
        await t.ensureVisible(find.text('View'));
        await t.tap(find.text('View'));
        await t.pumpAndSettle();
        expect(find.byType(GroupInvitationCard), findsNWidgets(2));
        final decline = find.text('Decline').first;
        await t.ensureVisible(decline);
        await t.tap(decline);
        await t.pumpAndSettle();
        expect(writes, [
          {'inviteStatus': 'DECLINED'}
        ]);
        expect(find.byType(GroupInvitationCard), findsOneWidget);
        await t.ensureVisible(find.text('Your groups'));
        await t.tap(find.text('Your groups'));
        await t.pumpAndSettle();
        expect(find.text('Alien Fans'), findsNothing);
        final avatar =
            t.widget<ProfileAvatarView>(find.byType(ProfileAvatarView));
        expect(avatar.profileBadges, ['EARLY_ADOPTER']);
        expect(avatar.size, 32);
        await t.enterText(find.byType(TextField).first, 'Alien');
        await t.pumpAndSettle();
        expect(find.text('No groups match your search.'), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      });
    }
  }
}
