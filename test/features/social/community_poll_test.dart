import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/social/presentation/pages/community_space_screen.dart';
import 'package:flixie_app/features/social/presentation/pages/community_discussion_screen.dart';
import 'package:flixie_app/features/social/presentation/widgets/discussion/community_poll.dart';
import '../../community_space_test.dart' show SpaceFixture, showSpace, tapSpace;

class PollFixture extends SpaceFixture {
  PollFixture() {
    spoiler = false;
  }
  bool closed = false, writeFails = false, canCreatePoll = true;
  String? selected;
  final options = <Map<String, dynamic>>[
    {
      'id': 'film-option',
      'mediaId': 129,
      'kind': 'movie',
      'title': 'Spirited Away',
      'votes': 8
    },
    {
      'id': 'show-option',
      'mediaId': 1429,
      'kind': 'show',
      'title': 'Attack on Titan',
      'votes': 12
    }
  ];
  Map<String, dynamic> get poll => {
        'closedAt': closed ? '2026-10-11T12:00:00Z' : null,
        'canClose': !closed,
        'selectedOptionId': selected,
        'totalVotes': options.fold<int>(0, (n, o) => n + (o['votes'] as int)),
        'options': options.map((o) => Map<String, dynamic>.from(o)).toList()
      };
  @override
  Map<String, dynamic> thread(bool reveal) => {
        ...super.thread(reveal),
        'title': 'Best anime of all time?',
        'body': 'Pick a favourite.',
        'show': null,
        'poll': poll
      };
  @override
  Future<Map<String, dynamic>> get(int id, String path,
      [Map<String, String> query = const {}]) async {
    if (path == '')
      return {
        ...await super.get(id, path, query),
        'canCreatePoll': canCreatePoll
      };
    if (path == '/titles') {
      return {
        'items': [
          {'id': 129, 'kind': 'movie', 'title': 'Spirited Away'},
          {'id': 1429, 'kind': 'show', 'title': 'Attack on Titan'},
          {
            'id': 81,
            'kind': 'movie',
            'title': 'Nausicaä of the Valley of the Wind'
          }
        ]
            .where((o) => (o['title'] as String)
                .toLowerCase()
                .contains(query['q']!.toLowerCase()))
            .toList()
      };
    }
    return super.get(id, path, query);
  }

  @override
  Future<Map<String, dynamic>> post(
      int id, String path, Map<String, dynamic> body) async {
    posts++;
    payload = body;
    if (writeFails) throw Exception('offline');
    if (path.endsWith('/poll/vote')) {
      if (selected != null) {
        options.singleWhere((o) => o['id'] == selected)['votes']--;
      }
      selected = body['optionId'];
      options.singleWhere((o) => o['id'] == selected)['votes']++;
    }
    if (path.endsWith('/poll/options')) {
      options.add({
        'id': 'new-option',
        'mediaId': body['movieId'],
        'kind': 'movie',
        'title': 'Nausicaä of the Valley of the Wind',
        'votes': 0
      });
    }
    if (path.endsWith('/poll/close')) closed = true;
    return {};
  }
}

void main() {
  testWidgets('ordinary members cannot see poll creation', (t) async {
    final fixture = PollFixture()..canCreatePoll = false;
    await showSpace(t, CommunitySpaceScreen(communityId: -1, service: fixture));
    expect(find.text('Create a poll'), findsNothing);
    expect(find.text('Start a discussion'), findsOneWidget);
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
      'ranked results change a single vote and nominate only a selected title',
      (t) async {
    final fixture = PollFixture();
    await showSpace(
        t,
        CommunityDiscussionScreen(
            communityId: -1,
            discussionId: 'thread',
            service: fixture,
            joined: true));
    expect(t.getTopLeft(find.text('Attack on Titan')).dy,
        lessThan(t.getTopLeft(find.text('Spirited Away')).dy));
    await tapSpace(t, 'Spirited Away');
    expect(fixture.selected, 'film-option');
    expect(find.text('Your pick'), findsOneWidget);
    expect(fixture.poll['totalVotes'], 21);
    await tapSpace(t, 'Attack on Titan');
    expect(fixture.selected, 'show-option');
    expect(fixture.poll['totalVotes'], 21);
    expect(find.text('Your pick'), findsOneWidget);
    await tapSpace(t, 'Add another title');
    await t.enterText(find.byType(TextField).last, 'not a real title');
    await tapSpace(t, 'Search titles');
    expect(
        find.text(
            'No matching titles in this community yet. Try another search.'),
        findsOneWidget);
    expect(fixture.posts, 2);
    await t.enterText(find.byType(TextField).last, 'Spirited');
    await tapSpace(t, 'Search titles');
    expect(find.text('Already added'), findsOneWidget);
    expect(
        t
            .widget<ListTile>(find.widgetWithText(ListTile, 'Spirited Away'))
            .onTap,
        isNull);
    await t.enterText(find.byType(TextField).last, 'Nausica');
    await tapSpace(t, 'Search titles');
    await tapSpace(t, 'Nausicaä of the Valley of the Wind');
    expect(fixture.payload, {'movieId': 81});
    expect(fixture.options.length, 3);
    expect(fixture.poll['totalVotes'], 21);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'create poll requires two selected catalogue titles and publishes film/show IDs',
      (t) async {
    final fixture = PollFixture();
    await showSpace(t, CommunitySpaceScreen(communityId: -1, service: fixture));
    await tapSpace(t, 'Create a poll');
    await t.enterText(
        find.byType(TextFormField).first, 'Best anime of all time?');
    await tapSpace(t, 'Publish poll');
    expect(fixture.posts, 0);
    expect(find.text('Choose at least two starting titles.'), findsOneWidget);
    for (final title in ['Spirited Away', 'Attack on Titan']) {
      await tapSpace(t, 'Add a film or series');
      await t.enterText(find.byType(TextField).last, title);
      await tapSpace(t, 'Search titles');
      await tapSpace(t, title);
    }
    fixture.writeFails = true;
    await tapSpace(t, 'Publish poll');
    expect(find.text('Spirited Away'), findsOneWidget);
    expect(find.text('Attack on Titan'), findsOneWidget);
    expect(find.text('Couldn’t publish. Your poll draft is kept. Try again.'),
        findsOneWidget);
    fixture.writeFails = false;
    await tapSpace(t, 'Publish poll');
    expect(fixture.payload!['poll'], {
      'options': [
        {'movieId': 129},
        {'showId': 1429}
      ]
    });
    expect(find.text('Create a poll'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('admin chooses a local closing date and time and publishes UTC',
      (t) async {
    final fixture = PollFixture();
    await showSpace(t, CommunitySpaceScreen(communityId: -1, service: fixture));
    await tapSpace(t, 'Create a poll');
    await t.enterText(find.byType(TextFormField).first, 'Watch anime tonight?');
    for (final title in ['Spirited Away', 'Attack on Titan']) {
      await tapSpace(t, 'Add a film or series');
      await t.enterText(find.byType(TextField).last, title);
      await tapSpace(t, 'Search titles');
      await tapSpace(t, title);
    }
    await tapSpace(t, 'Closing time');
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await t.tap(find.byTooltip('Switch to input'));
    await t.pumpAndSettle();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    await t.enterText(
        find.descendant(
            of: find.byType(DatePickerDialog),
            matching: find.byType(TextFormField)),
        '${tomorrow.month}/${tomorrow.day}/${tomorrow.year}');
    await tapSpace(t, 'OK');
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tapSpace(t, 'OK');
    await t.drag(find.byType(ListView).first, const Offset(0, -250));
    await t.pumpAndSettle();
    expect(find.text('Remove deadline'), findsOneWidget);
    await tapSpace(t, 'Publish poll');
    final closing = DateTime.parse(fixture.payload!['poll']['closesAt']);
    expect(closing.isUtc, true);
    expect(closing.isAfter(DateTime.now()), true);
    expect(t.takeException(), isNull);
  });
  testWidgets('failed vote keeps saved results and creator confirms closure',
      (t) async {
    final fixture = PollFixture()..writeFails = true;
    await showSpace(
        t,
        CommunityDiscussionScreen(
            communityId: -1,
            discussionId: 'thread',
            service: fixture,
            joined: true));
    await tapSpace(t, 'Spirited Away');
    expect(fixture.selected, isNull);
    expect(fixture.poll['totalVotes'], 20);
    expect(find.text('Couldn’t save your choice. Try again.'), findsOneWidget);
    fixture.writeFails = false;
    await tapSpace(t, 'Close voting');
    expect(fixture.closed, false);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(BottomSheet), findsOneWidget);
    await tapSpace(t, 'Cancel');
    expect(fixture.closed, false);
    await tapSpace(t, 'Close voting');
    await t.tap(find.widgetWithText(FilledButton, 'Close voting'));
    await t.pumpAndSettle();
    expect(fixture.closed, true);
    expect(find.text('Voting closed · 20 votes'), findsOneWidget);
    final writes = fixture.posts;
    await tapSpace(t, 'Spirited Away');
    expect(fixture.posts, writes);
    expect(find.text('Add another title'), findsNothing);
  });
  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    for (final scenario in [
      (const Size(320, 700), 2.0),
      (const Size(900, 500), 1.0),
      (const Size(768, 1024), 1.5)
    ]) {
      testWidgets(
          'poll reflows ${theme.brightness} at $scenario and visitors cannot vote',
          (t) async {
        t.view.physicalSize = scenario.$1;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final fixture = PollFixture();
        await t.pumpWidget(MaterialApp(
            theme: theme,
            home: Scaffold(
                body: MediaQuery(
                    data: MediaQueryData(
                        size: scenario.$1,
                        textScaler: TextScaler.linear(scenario.$2)),
                    child: SingleChildScrollView(
                        child: CommunityPoll(
                            poll: fixture.poll,
                            communityId: -1,
                            discussionId: 'thread',
                            service: fixture,
                            member: false,
                            onChanged: () async {}))))));
        await t.pumpAndSettle();
        await t.tap(find.text('Attack on Titan'));
        expect(fixture.posts, 0);
        expect(find.text('Add another title'), findsNothing);
        expect(t.takeException(), isNull);
      });
    }
  }
}
