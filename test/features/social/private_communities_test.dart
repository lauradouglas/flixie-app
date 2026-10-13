import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/social/data/private_community_service.dart';
import 'package:flixie_app/features/social/presentation/pages/private_communities_screen.dart';

class PrivateFixture extends PrivateCommunityService {
  bool fails = false;
  bool canCreate = true;
  Map<String, dynamic>? created;
  int accepted = 0;
  @override
  Future<Map<String, dynamic>> get(String path,
      [Map<String, String> query = const {}]) async {
    if (fails) throw Exception('fixture');
    if (path == '/private') {
      return {
        'canCreateCommunity': canCreate,
        'items': [],
        'invitations': [
          {
            'id': 'personal',
            'name': 'Movie night club',
            'description': 'Friends'
          }
        ],
        'nextAfter': null
      };
    }
    return {
      'name': 'Movie night club',
      'description': 'Friends',
      'expiresAt': '2026-10-18T12:00:00Z'
    };
  }

  @override
  Future<Map<String, dynamic>> post(
      String path, Map<String, dynamic> body) async {
    if (fails) throw Exception('fixture');
    if (path == '/private') {
      created = body;
    } else {
      accepted++;
    }
    return {'id': -1000, 'name': 'Movie night club'};
  }
}

Future<void> showPrivate(WidgetTester t, PrivateFixture fixture,
    {Size size = const Size(390, 844), double scale = 1}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final router = GoRouter(initialLocation: '/private', routes: [
    GoRoute(
        path: '/private',
        builder: (c, s) => PrivateCommunitiesScreen(service: fixture)),
    GoRoute(
        path: '/genre-communities/:id',
        builder: (c, s) => const Scaffold(body: Text('Inside community')))
  ]);
  addTearDown(router.dispose);
  await t.pumpWidget(MaterialApp.router(
      theme: AppTheme.lightTheme,
      routerConfig: router,
      builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!)));
  await t.pumpAndSettle();
}

Future<void> tapPrivate(WidgetTester t, String text) async {
  final raw = find.text(text);
  if (raw.evaluate().isEmpty) {
    await t.scrollUntilVisible(raw, 200,
        scrollable: find.byType(Scrollable).last);
  }
  final finder = raw.last;
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
  await t.tap(finder);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('ordinary users can accept invites but cannot create communities',
      (t) async {
    final fixture = PrivateFixture()..canCreate = false;
    await showPrivate(t, fixture);
    expect(find.text('Create a community'), findsNothing);
    expect(find.text('Use an invite'), findsOneWidget);
    await tapPrivate(t, 'Movie night club');
    await tapPrivate(t, 'Join community');
    expect(fixture.accepted, 1);
  });
  test('invite parser accepts only Flixie links and opaque codes', () {
    final token = 'a' * 43;
    expect(
        privateInviteKey('https://www.flixie.co.uk/community-invites/$token'),
        token);
    expect(privateInviteKey(token), token);
    expect(
        privateInviteKey('https://evil.test/community-invites/$token'), isNull);
    expect(privateInviteKey('bad code'), isNull);
  });
  testWidgets('personal invite is previewed before explicit acceptance',
      (t) async {
    final fixture = PrivateFixture();
    await showPrivate(t, fixture);
    await tapPrivate(t, 'Movie night club');
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(fixture.accepted, 0);
    await tapPrivate(t, 'Join community');
    expect(fixture.accepted, 1);
    expect(find.text('Inside community'), findsOneWidget);
  });
  testWidgets(
      'create requires name, preserves failed draft and opens new community',
      (t) async {
    final fixture = PrivateFixture();
    await showPrivate(t, fixture);
    await tapPrivate(t, 'Create a community');
    await tapPrivate(t, 'Create community');
    expect(fixture.created, isNull);
    expect(find.text('Use at least 3 characters.'), findsOneWidget);
    await t.enterText(find.byType(TextFormField).first, 'Late night stream');
    fixture.fails = true;
    await tapPrivate(t, 'Create community');
    expect(
        find.text(
            'Couldn’t create the community. Your draft is saved here. Try again.'),
        findsOneWidget);
    fixture.fails = false;
    await tapPrivate(t, 'Create community');
    expect(fixture.created!['name'], 'Late night stream');
    expect(find.text('Inside community'), findsOneWidget);
  });
  testWidgets('invite sheet remains scrollable at large text on a small phone',
      (t) async {
    final fixture = PrivateFixture();
    await showPrivate(t, fixture, size: const Size(320, 700), scale: 2);
    await tapPrivate(t, 'Movie night club');
    await tapPrivate(t, 'Join community');
    expect(fixture.accepted, 1);
    expect(t.takeException(), isNull);
  });
}
