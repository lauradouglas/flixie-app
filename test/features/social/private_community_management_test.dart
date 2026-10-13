import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/social/data/private_community_service.dart';
import 'package:flixie_app/features/social/presentation/widgets/private_community_manage_sheet.dart';

class ManageFixture extends PrivateCommunityService {
  String role = 'MEMBER';
  int changed = 0, revoked = 0;
  @override
  Future<Map<String, dynamic>> get(String path,
          [Map<String, String> query = const {}]) async =>
      path.endsWith('/members')
          ? {
              'items': [
                {
                  'role': role,
                  'user': {
                    'id': 'fixture-member',
                    'username': 'dev_movie_blair',
                    'profileBadges': []
                  }
                }
              ],
              'nextAfter': null
            }
          : {
              'items': revoked == 0
                  ? [
                      {
                        'id': 'invite',
                        'link': false,
                        'username': 'dev_movie_robin',
                        'expiresAt': '2026-10-18T12:00:00Z'
                      }
                    ]
                  : []
            };
  @override
  Future<void> changeRole(int id, String user, String next) async {
    changed++;
    role = next;
  }

  @override
  Future<void> revoke(int id, String invitation) async {
    revoked++;
  }
}

Future<void> tapManage(WidgetTester t, String text) async {
  final raw = find.text(text);
  if (raw.evaluate().isEmpty) {
    await t.scrollUntilVisible(raw, 200,
        scrollable: find.byType(Scrollable).last);
  }
  await t.ensureVisible(raw.last);
  await t.pumpAndSettle();
  await t.tap(raw.last);
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
      'owner promotes and demotes with accurate bottom-sheet confirmations',
      (t) async {
    final fixture = ManageFixture();
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
            builder: (c) => Scaffold(
                body: TextButton(
                    onPressed: () => showPrivateCommunityManagement(
                        c, -1000, 'OWNER',
                        service: fixture),
                    child: const Text('Manage'))))));
    await tapManage(t, 'Manage');
    expect(find.text('Invite for dev_movie_robin'), findsOneWidget);
    await tapManage(t, 'Make admin');
    expect(fixture.changed, 0);
    expect(find.byType(AlertDialog), findsNothing);
    await tapManage(t, 'Confirm');
    expect(fixture.role, 'ADMIN');
    await tapManage(t, 'Remove admin role');
    expect(
        find.text(
            'They will lose access to invitations, member management and poll creation. They can still vote and discuss as a member.'),
        findsOneWidget);
    await tapManage(t, 'Confirm');
    expect(fixture.role, 'MEMBER');
    expect(fixture.changed, 2);
  });
  testWidgets(
      'management is scrollable with enlarged text and revoke requires confirmation',
      (t) async {
    t.view.physicalSize = const Size(320, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final fixture = ManageFixture();
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: Builder(
            builder: (c) => Scaffold(
                body: TextButton(
                    onPressed: () => showPrivateCommunityManagement(
                        c, -1000, 'OWNER',
                        service: fixture),
                    child: const Text('Manage'))))));
    await tapManage(t, 'Manage');
    await tapManage(t, 'Revoke');
    expect(fixture.revoked, 0);
    await tapManage(t, 'Cancel');
    expect(fixture.revoked, 0);
    await tapManage(t, 'Revoke');
    await t.ensureVisible(find.widgetWithText(FilledButton, 'Revoke'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Revoke'));
    await t.pumpAndSettle();
    expect(fixture.revoked, 1);
    expect(t.takeException(), isNull);
  });
}
