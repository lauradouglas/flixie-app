import 'dart:async';
import 'package:flixie_app/features/social/presentation/widgets/group_members/invite_members_sheet.dart';
import 'package:flixie_app/models/group_member.dart';
import 'package:flixie_app/features/social/presentation/widgets/group_members/group_member_actions.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/social/presentation/pages/group_members_screen.dart';
import '../../../support/api_fixture.dart';
import '../../profile/notifications/journey.dart' show InboxAuth;
import 'controller_test.dart' show fixture;

void main() => registerMemberJourneys((name, body) => testWidgets(name, body));

void registerMemberJourneys(
    void Function(String, Future<void> Function(WidgetTester)) register) {
  register('owner changes role, cancels removal then removes a fixture member',
      (tester) async {
    final auth = InboxAuth()..id = '99';
    addTearDown(auth.dispose);
    final rows = fixture().map((m) => m.toJson()).toList();
    final writes = <String>[];
    useApiFixture(MockClient((r) async {
      if (r.method == 'PUT') {
        writes.add('role');
        expect(r.url.path, '/groups/fictional-club/members/97/role');
        expect(jsonDecode(r.body), {'roleId': 'ADMIN'});
        rows.firstWhere((m) => m['memberId'] == '97')['role'] = 'ADMIN';
        return http.Response('{}', 200);
      }
      if (r.method == 'DELETE') {
        writes.add('remove');
        expect(jsonDecode(r.body), ['97']);
        rows.removeWhere((m) => m['memberId'] == '97');
        return http.Response('{}', 200);
      }
      return http.Response(jsonEncode(rows), 200);
    }));
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const GroupMembersScreen(
                groupId: 'fictional-club', groupName: 'Alien club'))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'AlienFan97');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(
        find.byWidgetPredicate((w) => w is Text && w.data == 'AlienFan97'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Promote to Admin'));
    await tester.pumpAndSettle();
    expect(writes, ['role']);
    await tester.tap(
        find.byWidgetPredicate((w) => w is Text && w.data == 'AlienFan97'));
    await tester.pumpAndSettle();
    expect(find.text('Demote to Member'), findsOneWidget);
    await tester.tap(find.text('Remove from Group'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(writes, ['role']);
    expect(find.byWidgetPredicate((w) => w is Text && w.data == 'AlienFan97'),
        findsOneWidget);
    await tester.tap(
        find.byWidgetPredicate((w) => w is Text && w.data == 'AlienFan97'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from Group'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(writes, ['role', 'remove']);
    expect(find.byWidgetPredicate((w) => w is Text && w.data == 'AlienFan97'),
        findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  for (final switchAccount in [false, true]) {
    register('invite completion account switch=$switchAccount', (tester) async {
      final auth = InboxAuth();
      addTearDown(auth.dispose);
      var current = true;
      var completed = 0;
      final sent = Completer<http.Response>();
      useApiFixture(MockClient((r) async {
        if (r.method == 'POST') {
          expect(jsonDecode(r.body)['members'][0]['inviterId'], 'inbox-viewer');
          return sent.future;
        }
        return http.Response(
            jsonEncode({
              'friendships': [
                {
                  'id': 'edge',
                  'friend': {
                    'id': 'odyssey',
                    'username': 'OdysseyFan',
                    'profileBadges': ['FOUNDER']
                  }
                },
                {
                  'id': 'existing',
                  'friend': {'id': 'already', 'username': 'AlreadyMember'}
                }
              ]
            }),
            200);
      }));
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Builder(
                  builder: (context) => Scaffold(
                      body: TextButton(
                          child: const Text('Open'),
                          onPressed: () => showModalBottomSheet(
                              context: context,
                              useRootNavigator: true,
                              useSafeArea: true,
                              isScrollControlled: true,
                              builder: (_) => InviteMembersSheet(
                                  groupId: 'g',
                                  currentMemberIds: const ['already'],
                                  isCurrent: () => current,
                                  onInvited: () => completed++))))))));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('AlreadyMember'), findsNothing);
      await tester.tap(find.text('OdysseyFan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Invite (1)'));
      await tester.pump();
      if (switchAccount) {
        current = false;
        auth.change('other');
      }
      sent.complete(http.Response('{}', 200));
      await tester.pumpAndSettle();
      expect(completed, switchAccount ? 0 : 1);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final owner in [true, false]) {
    register('role actions for ${owner ? 'owner' : 'admin'} preserve outcomes',
        (tester) async {
      String? changed;
      var removed = false;
      var transferred = false;
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => showGroupMemberActions(context,
                          member: const GroupMember(
                              groupId: 'g',
                              memberId: 'other',
                              role: 'ADMIN',
                              username: 'AlienFan'),
                          currentUserId: 'me',
                          isOwner: owner,
                          isAdmin: !owner,
                          changeRole: (role) => changed = role,
                          transfer: () => transferred = true,
                          remove: () => removed = true),
                      child: const Text('Manage'))))));
      await tester.tap(find.text('Manage'));
      await tester.pumpAndSettle();
      expect(find.text('Transfer Ownership'),
          owner ? findsOneWidget : findsNothing);
      expect(find.text('Remove from Group'),
          owner ? findsOneWidget : findsNothing);
      await tester.tap(find.text('Demote to Member'));
      await tester.pumpAndSettle();
      expect(changed, 'MEMBER');
      expect(removed, false);
      expect(transferred, false);
    });
  }

  register(
      'owner searches pending members; account switch removes owner actions',
      (tester) async {
    final auth = InboxAuth()..id = '99';
    addTearDown(auth.dispose);
    useApiFixture(MockClient((r) async => http.Response(
        jsonEncode(fixture().map((m) => m.toJson()).toList()), 200)));
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const GroupMembersScreen(
                groupId: 'fictional-club', groupName: 'Alien club'))));
    await tester.pumpAndSettle();
    expect(find.text('Invite'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'AlienFan2');
    await tester.pumpAndSettle();
    expect(find.text('11 members'), findsOneWidget);
    await tester.tap(find.text('Pending'));
    await tester.pumpAndSettle();
    expect(find.text('6 members'), findsOneWidget);
    auth.change('0');
    await tester.pumpAndSettle();
    expect(find.text('Invite'), findsNothing);
    expect(find.text('100 members'), findsOneWidget);
    auth.change(null);
    await tester.pumpAndSettle();
    expect(find.text('No members found'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
