import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/sharing/presentation/media_chat_share.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import '../../support/api_fixture.dart';
import 'fixture.dart';

Widget shareHost(ShareAuth auth, {bool show = false, double scale = 1}) =>
    ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
            theme: AppTheme.darkTheme,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: Builder(
                builder: (context) => Scaffold(
                    body: Center(
                        child: TextButton(
                            onPressed: () => MediaChatShare(context).show(
                                ChatShareMedia(
                                    id: 123,
                                    title: 'The Odyssey and Alien: a recommendation for the weekend',
                                    isShow: show)),
                            child: const Text('Open share')))))));

Future<void> openPicker(WidgetTester tester, bool group) async {
  await tester.tap(find.text('Open share'));
  await tester.pumpAndSettle();
  await tester
      .tap(find.text(group ? 'Share to group chat' : 'Share to friend'));
  await tester.pumpAndSettle();
}

Future<void> sendJourney(WidgetTester tester, {required bool group}) async {
  final auth = ShareAuth();
  addTearDown(auth.dispose);
  var sends = 0;
  final bodies = <Map<String, dynamic>>[];
  useApiFixture(MockClient((r) async {
    if (r.url.path.startsWith('/friends')) {
      return http.Response(jsonEncode(friendsPayload(100)), 200);
    }
    if (r.url.path.startsWith('/groups/user')) {
      return http.Response(jsonEncode(groupsPayload(100)), 200);
    }
    if (r.url.path.endsWith('/members')) return http.Response('[]', 200);
    if (r.url.path.endsWith('/messages')) {
      sends++;
      bodies.add(jsonDecode(r.body));
      return http.Response(
          sends == 1 ? '{}' : '{"id":"sent"}', sends == 1 ? 400 : 200);
    }
    expect(jsonDecode(r.body)[group ? 'pgGroupId' : 'otherUserId'],
        group ? 'group-1' : 'friend-1');
    return http.Response('{"id":"fixture-conversation"}', 200);
  }));
  await tester.pumpWidget(shareHost(auth, show: group));
  await tester.pumpAndSettle();
  await openPicker(tester, group);
  if (!group) {
    expect(
        tester
            .widget<ProfileAvatarView>(find.byType(ProfileAvatarView).first)
            .profileBadges,
        ['FOUNDER']);
  }
  await tester.tap(find.text(group ? 'Odyssey Club 1' : 'OdysseyFan1'));
  await tester.pumpAndSettle();
  final button =
      find.text(group ? 'Share in group chat' : 'Share in direct chat');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
  expect(
      find.text(group
          ? 'Could not share to that group yet'
          : 'Could not share to that friend yet'),
      findsOneWidget);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
  expect(sends, 2);
  expect(bodies.last['senderId'], 'fixture-viewer');
  expect(bodies.last['text'],
      contains(group ? 'FLIXIE_SHOW_SHARE' : 'FLIXIE_MOVIE_SHARE'));
  expect(find.byType(TextField), findsNothing);
  expect(find.text('Open share'), findsOneWidget);
  await tester.pumpWidget(const SizedBox());
}

Future<void> dismissJourney(WidgetTester tester) async {
  final auth = ShareAuth();
  addTearDown(auth.dispose);
  final pending = Completer<http.Response>();
  var sends = 0;
  useApiFixture(MockClient((r) async {
    if (r.url.path.startsWith('/friends')) {
      return http.Response(jsonEncode(friendsPayload(100)), 200);
    }
    if (r.url.path.endsWith('/messages')) {
      sends++;
      return http.Response('{}', 200);
    }
    return pending.future;
  }));
  await tester.pumpWidget(shareHost(auth));
  await tester.pumpAndSettle();
  await openPicker(tester, false);
  await tester.ensureVisible(find.text('Share in direct chat'));
  await tester.tap(find.text('Share in direct chat'));
  await tester.pump();
  final context = tester.element(find.byType(TextField));
  Navigator.of(context).pop();
  await tester.pumpAndSettle();
  pending.complete(http.Response('{"id":"conversation"}', 200));
  await tester.pumpAndSettle();
  expect(sends, 0);
  expect(find.text('Open share'), findsOneWidget);
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
}
