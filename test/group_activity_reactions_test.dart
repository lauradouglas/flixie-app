import 'package:flixie_app/features/profile/presentation/widgets/activity_tile.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/activity_reaction.dart';
import 'package:flixie_app/features/social/presentation/widgets/group_detail_activity_tab.dart';
import 'package:flixie_app/features/social/presentation/widgets/group_activity_card.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  @override
  User get dbUser => const User(
      id: 'me',
      username: 'Laura',
      email: '',
      iconColorId: 0,
      completedSetup: true,
      darkMode: true);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

const item = ActivityListItem(
    id: 'activity',
    userId: 'friend',
    username: 'LauraD',
    firstName: '',
    lastName: '',
    removed: false,
    createdAt: '',
    updatedAt: '',
    type: ActivityListType.movieWatched,
    movieId: 1,
    mediaTitle: 'The Odyssey');
void main() {
  setUpAll(() async {
    await (FontLoader('Manrope')
          ..addFont(
              rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  test('switching and removing a reaction adjusts only your contribution', () {
    const original = ActivityReactionSummary(counts: {'❤️': 2}, mine: '❤️');
    final changed = original.selecting('💯');
    expect(changed.counts['❤️'], 1);
    expect(changed.counts['💯'], 1);
    expect(changed.selecting(null).counts['💯'], 0);
    expect(original.counts['❤️'], 2);
  });
  testWidgets(
      'seven reactions save, change and remove through the activity API',
      (tester) async {
    final auth = _Auth();
    addTearDown(auth.dispose);
    var summary = const ActivityReactionSummary(counts: {'❤️': 1});
    final sent = <String?>[];
    var failNext = false;
    await http.runWithClient(() async {
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                  body: GroupActivityTab(
                      group: null,
                      memberCount: 2,
                      groupId: 'group',
                      initialRequests: const [],
                      initialActivity: const [item],
                      groupLists: const [],
                      onRefresh: () async {})))));
      await tester.pumpAndSettle();
      expect(find.text('Latest activity'), findsOneWidget);
      expect(find.text('❤️ 1'), findsOneWidget);
      for (final emoji in ['❤️', '👀', '🔥', '😂', '😮', '💯', '👎', '👎']) {
        final react = find.byTooltip('Add reaction');
        await tester.ensureVisible(react);
        if (sent.isEmpty) {
          await tester.longPress(find.byType(GroupActivityCard));
        } else {
          await tester.tap(react);
        }
        await tester.pumpAndSettle();
        final option = find.byTooltip(ActivityReaction.values
            .firstWhere((value) => value.emoji == emoji)
            .label);
        expect(find.text('Reply in chat'), findsOneWidget);
        await tester.tap(option.last);
        await tester.pumpAndSettle();
      }
      expect(sent, ['❤️', '👀', '🔥', '😂', '😮', '💯', '👎', null]);
      expect(find.byTooltip('Add reaction'), findsOneWidget);
      failNext = true;
      await tester.tap(find.byTooltip('Add reaction'));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byTooltip(ActivityReaction.values.first.label).last);
      await tester.pumpAndSettle();
      expect(find.text('Couldn’t save your reaction'), findsOneWidget);
      expect(find.byTooltip('Add reaction'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Add reaction'), findsOneWidget);
      expect(find.text('❤️ 2'), findsOneWidget);
      await tester.tap(find.text('❤️ 2'));
      await tester.pumpAndSettle();
      expect(find.text('❤️ 1'), findsOneWidget);
      expect(find.byTooltip('Add reaction'), findsOneWidget);
      expect(find.text('Reply in chat'), findsNothing);
      expect(sent.last, isNull);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.method == 'PUT') {
                if (failNext) {
                  failNext = false;
                  return http.Response('{}', 500);
                }
                final body = jsonDecode(request.body) as Map;
                sent.add(body['reaction'] as String?);
                summary = summary.selecting(body['reaction'] as String?);
                return http.Response(
                    jsonEncode(
                        {'counts': summary.counts, 'mine': summary.mine}),
                    200,
                    headers: {
                      'content-type': 'application/json; charset=utf-8'
                    });
              }
              return http.Response(
                  jsonEncode({
                    'items': [
                      {
                        'id': 'activity',
                        'userId': 'friend',
                        'username': 'LauraD',
                        'type': 'watched_movie',
                        'movie': {'id': 1, 'title': 'The Odyssey'}
                      }
                    ],
                    'reactions': {
                      'watched-movie:activity': {
                        'counts': summary.counts,
                        'mine': summary.mine
                      }
                    }
                  }),
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }));
  });
  testWidgets('friend-feed reactions save, change, remove and retry',
      (tester) async {
    final auth = _Auth();
    addTearDown(auth.dispose);
    var summary = const ActivityReactionSummary(counts: {'❤️': 1});
    final sent = <String?>[];
    var failNext = false;
    await http.runWithClient(() async {
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(body: ActivityTile(item: item)))));
      await tester.pumpAndSettle();
      expect(find.text('❤️ 1'), findsOneWidget);
      for (final emoji in ['❤️', '👀', '🔥', '😂', '😮', '💯', '👎', '👎']) {
        final react = find.byTooltip('Add reaction');
        await tester.ensureVisible(react);
        if (sent.isEmpty) {
          await tester.longPress(find.byType(GroupActivityCard));
        } else {
          await tester.tap(react);
        }
        await tester.pumpAndSettle();
        final option = find.byTooltip(ActivityReaction.values
            .firstWhere((value) => value.emoji == emoji)
            .label);
        expect(find.text('Reply in chat'), findsOneWidget);
        await tester.tap(option.last);
        await tester.pumpAndSettle();
      }
      expect(sent, ['❤️', '👀', '🔥', '😂', '😮', '💯', '👎', null]);
      expect(find.byTooltip('Add reaction'), findsOneWidget);
      failNext = true;
      await tester.tap(find.byTooltip('Add reaction'));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byTooltip(ActivityReaction.values.first.label).last);
      await tester.pumpAndSettle();
      expect(find.text('Couldn’t save your reaction'), findsOneWidget);
      expect(find.byTooltip('Add reaction'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Add reaction'), findsOneWidget);
      expect(find.text('❤️ 2'), findsOneWidget);
      await tester.tap(find.text('❤️ 2'));
      await tester.pumpAndSettle();
      expect(find.text('❤️ 1'), findsOneWidget);
      expect(find.byTooltip('Add reaction'), findsOneWidget);
      expect(find.text('Reply in chat'), findsNothing);
      expect(sent.last, isNull);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.method == 'PUT') {
                if (failNext) {
                  failNext = false;
                  return http.Response('{}', 500);
                }
                final body = jsonDecode(request.body) as Map;
                sent.add(body['reaction'] as String?);
                summary = summary.selecting(body['reaction'] as String?);
                return http.Response(
                    jsonEncode(
                        {'counts': summary.counts, 'mine': summary.mine}),
                    200,
                    headers: {
                      'content-type': 'application/json; charset=utf-8'
                    });
              }
              return http.Response(
                  jsonEncode({
                    'watched-movie:activity': {
                      'counts': summary.counts,
                      'mine': summary.mine
                    }
                  }),
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }));
  });
  testWidgets('activity card fits phones, tablets and large text',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [
      const Size(390, 844),
      const Size(320, 800),
      const Size(800, 1000)
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(size.width == 320 ? 2 : 1)),
              child: child!),
          home: Scaffold(
              body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: GroupActivityCard(
                      item: item,
                      reactions: const ActivityReactionSummary(
                          counts: {'❤️': 2, '💯': 1}, mine: '💯'),
                      onReact: (_) {},
                      onOpen: () {},
                      onProfile: () {},
                      onReply: () {})))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('The Odyssey'), findsOneWidget);
      expect(find.text('Reply'), findsOneWidget);
    }
  });
}
