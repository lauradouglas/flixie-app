import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'package:flixie_app/features/social/data/community_space_service.dart';
import 'package:flixie_app/features/social/data/genre_community_service.dart';
import 'package:flixie_app/features/social/presentation/pages/community_space_screen.dart';
import 'package:flixie_app/features/social/presentation/pages/community_discussion_screen.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'support/watchlist_auth.dart';
import 'package:flixie_app/features/social/presentation/widgets/community_mention_suggestions.dart';
import 'package:flixie_app/features/social/presentation/widgets/community_identity.dart';

class SpaceFixture extends CommunitySpaceService {
  bool fail = false, joined = true, spoiler = true;
  int posts = 0;
  Map<String, dynamic>? payload;
  Completer<Map<String, dynamic>>? pending;
  final calls = <String>[];
  Map<String, dynamic> get author => {
        'id': 'ellis',
        'username': 'Ellis',
        'firstName': 'Ellis',
        'avatar': null,
        'profileBadges': ['FOUNDER']
      };
  Map<String, dynamic> thread(bool reveal) => {
        'id': 'thread',
        'user': author,
        'title':
            spoiler && !reveal ? 'Spoiler discussion' : 'An ending to remember',
        'body': spoiler && !reveal ? null : 'A thoughtful ending',
        'spoiler': spoiler ? 'episode' : 'none',
        'season': 1,
        'episode': 25,
        'replyCount': 2,
        'createdAt':
            DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        'show': {'id': 1429, 'title': 'Attack on Titan'}
      };
  @override
  Future<Map<String, dynamic>> get(int id, String path,
      [Map<String, String> query = const {}]) async {
    calls.add('$path:${query.toString()}');
    if (fail) throw Exception('offline');
    if (path == '') return {'id': -1, 'name': 'Anime', 'joined': joined};
    if (path == '/discussions') {
      return {
        'items': [thread(false)],
        'nextCursor': null
      };
    }
    if (path == '/discussions/thread') return thread(query['reveal'] == 'true');
    if (path.endsWith('/replies')) {
      return {
        'items': [
          if (posts > 0) {'id': 'reply', 'user': author, 'body': 'My reply'}
        ],
        'nextCursor': null
      };
    }
    if (path == '/titles') {
      return {
        'items': [
          {'id': 1429, 'title': 'Attack on Titan', 'kind': 'show'}
        ]
      };
    }
    if (path == '/discover') {
      return {
        'items': [
          {
            'id': 129,
            'title': 'Spirited Away',
            'kind': 'movie',
            'posterPath': null,
            'average': 8.8,
            'count': 42
          },
          {
            'id': 128,
            'title': 'Princess Mononoke',
            'kind': 'movie',
            'posterPath': null,
            'average': 8.7,
            'count': 36
          }
        ],
        'nextOffset': null
      };
    }
    return {'items': []};
  }

  @override
  Future<Map<String, dynamic>> post(
      int id, String path, Map<String, dynamic> body) async {
    posts++;
    payload = body;
    if (fail) throw Exception('offline');
    if (pending != null) return pending!.future;
    return {'id': 'new'};
  }
}

class SpaceMembership extends GenreCommunityService {
  SpaceMembership(this.fixture);
  final SpaceFixture fixture;
  int writes = 0;
  @override
  Future<void> setJoined(int id, bool value) async {
    writes++;
    fixture.joined = value;
  }
}

Future<void> showSpace(WidgetTester tester, Widget child) async {
  final auth = TestAuth();
  addTearDown(auth.dispose);
  await tester.pumpWidget(MultiProvider(providers: [
    ChangeNotifierProvider<AuthProvider>.value(value: auth),
    ChangeNotifierProvider<MovieRatingPrivacy>(
        create: (_) => MovieRatingPrivacy(loadRatings: (_) async => {129})
          ..syncUser('viewer'))
  ], child: MaterialApp(theme: AppTheme.darkTheme, home: child)));
  await tester.pumpAndSettle();
}

Future<void> tapSpace(WidgetTester t, String text) async {
  await t.pump();
  final raw = text == 'Post reply' ? find.byTooltip(text) : find.text(text);
  final f = raw.last;
  if (raw.evaluate().isEmpty) {
    await t.scrollUntilVisible(raw, 250,
        scrollable: find.byType(Scrollable).first);
  }
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

class MentionFixture extends SpaceFixture {
  bool includeChild = false;
  Map<String, String>? mentionQuery;
  @override
  Future<Map<String, dynamic>> get(int id, String path,
      [Map<String, String> query = const {}]) async {
    if (path == '/mention-candidates') {
      mentionQuery = query;
      return {
        'items': [author]
      };
    }
    if (path.endsWith('/replies'))
      return {
        'items': [
          {'id': 'parent', 'user': author, 'body': 'An interesting point'},
          if (includeChild)
            {
              'id': 'child',
              'user': author,
              'body': 'Agreed',
              'parentReply': {'id': 'parent', 'user': author}
            }
        ],
        'nextCursor': null
      };
    if (path == '/replies/parent')
      return {'id': 'parent', 'user': author, 'body': 'An interesting point'};
    return super.get(id, path, query);
  }
}

void main() {
  test('removed mentions and partial usernames do not notify', () {
    final selected = {'ellis': 'Ellis'};
    expect(activeCommunityMentions(selected, 'Hi @Ellis!'), ['ellis']);
    expect(activeCommunityMentions(selected, 'Hi @Ellis'), ['ellis']);
    expect(activeCommunityMentions(selected, 'Hi @Ellison'), isEmpty);
    expect(activeCommunityMentions(selected, 'No mention now'), isEmpty);
  });

  setUpAll(() async {
    await (FontLoader('Manrope')
          ..addFont(
              rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
      'community introduction scrolls away to leave room for discussions',
      (t) async {
    await t.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await showSpace(
        t, CommunitySpaceScreen(communityId: -1, service: SpaceFixture()));
    expect(find.text('Big feelings. Different worlds. Your kind of people.'),
        findsOneWidget);
    await t.drag(find.byType(NestedScrollView), const Offset(0, -350));
    await t.pumpAndSettle();
    expect(find.byType(CommunityIdentityHeader).hitTestable(), findsNothing);
    expect(find.text('Discuss').hitTestable(), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'discussion footer shows author and age and replies open the thread',
      (t) async {
    await t.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final fixture = SpaceFixture()..spoiler = false;
    await showSpace(t, CommunitySpaceScreen(communityId: -1, service: fixture));
    expect(find.text('Ellis · 2h ago'), findsOneWidget);
    await t.ensureVisible(find.text('2 replies'));
    if (const bool.fromEnvironment('COMMUNITY_CAPTURE')) {
      final boundary = t.renderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary).first);
      await t.runAsync(() async {
        final img = await boundary.toImage();
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        await File('/tmp/flixie-discussion-styling.png')
            .writeAsBytes(data!.buffer.asUint8List());
        img.dispose();
      });
    }
    await t.tap(find.text('2 replies'));
    await t.pumpAndSettle();
    expect(find.byType(CommunityDiscussionScreen), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('Discover grid reflows for text scale $scale', (t) async {
      const size = Size(430, 932);
      await t.binding.setSurfaceSize(size);
      addTearDown(() => t.binding.setSurfaceSize(null));
      await showSpace(
          t,
          MediaQuery(
              data: MediaQueryData(
                  size: size, textScaler: TextScaler.linear(scale)),
              child: CommunitySpaceScreen(
                  communityId: -1, service: SpaceFixture())));
      await tapSpace(t, 'Discover');
      final first = find.byKey(const ValueKey('discovery-card:movie:129'));
      final second = find.byKey(const ValueKey('discovery-card:movie:128'));
      final a = t.getTopLeft(first), b = t.getTopLeft(second);
      if (scale == 1) {
        expect(a.dy, b.dy);
        expect(b.dx, greaterThan(a.dx));
      } else {
        expect(a.dx, b.dx);
        expect(b.dy, greaterThan(a.dy));
      }
      expect(t.takeException(), isNull);
      if (const bool.fromEnvironment('COMMUNITY_CAPTURE')) {
        final boundary = t.renderObject<RenderRepaintBoundary>(
            find.byType(RepaintBoundary).first);
        await t.runAsync(() async {
          final img = await boundary.toImage();
          final data = await img.toByteData(format: ui.ImageByteFormat.png);
          await File('/tmp/flixie-discover-grid-$scale.png')
              .writeAsBytes(data!.buffer.asUint8List());
          img.dispose();
        });
      }
    });
  }

  testWidgets(
      'selected mention and comment reply send recipient and parent IDs',
      (t) async {
    final fixture = MentionFixture()..spoiler = false;
    await showSpace(
        t,
        CommunityDiscussionScreen(
            communityId: -1,
            discussionId: 'thread',
            service: fixture,
            joined: true));
    await t.ensureVisible(find.widgetWithText(TextButton, 'Reply'));
    await t.tap(find.widgetWithText(TextButton, 'Reply'));
    await t.pumpAndSettle();
    expect(find.text('Replying to @Ellis'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, 'Your reply'), 'Hi @El');
    await t.pump(const Duration(milliseconds: 300));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('@Ellis'));
    await t.tap(find.text('@Ellis'));
    await t.pumpAndSettle();
    expect(
        t
            .widget<TextField>(find.widgetWithText(TextField, 'Your reply'))
            .controller!
            .text,
        'Hi @Ellis ');
    await t.ensureVisible(find.byTooltip('Post reply'));
    await t.tap(find.byTooltip('Post reply'));
    await t.pumpAndSettle();
    expect(fixture.mentionQuery?['discussionId'], 'thread');
    expect(fixture.payload?['mentionIds'], ['ellis']);
    expect(fixture.payload?['parentReplyId'], 'parent');
    expect(find.text('Replying to @Ellis'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('join requires explicit confirmation and unlocks composer',
      (t) async {
    final fixture = SpaceFixture()..joined = false;
    final membership = SpaceMembership(fixture);
    await showSpace(
        t,
        CommunitySpaceScreen(
            communityId: -1, service: fixture, membership: membership));
    expect(
        t
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Join to start or reply'))
            .onPressed,
        isNull);
    await tapSpace(t, 'Join');
    expect(membership.writes, 0);
    await tapSpace(t, 'Cancel');
    expect(membership.writes, 0);
    await tapSpace(t, 'Join');
    await t.tap(find.widgetWithText(FilledButton, 'Join'));
    await t.pumpAndSettle();
    expect(membership.writes, 1);
    expect(find.text('Start a discussion'), findsOneWidget);
    expect(
        t
            .widget<ProfileAvatarView>(find.byType(ProfileAvatarView).first)
            .profileBadges,
        ['FOUNDER']);
  });
  testWidgets('spoilers gate body and reply requests, then post reply',
      (t) async {
    final fixture = SpaceFixture();
    await showSpace(
        t,
        CommunityDiscussionScreen(
            communityId: -1,
            discussionId: 'thread',
            service: fixture,
            joined: true));
    expect(find.text('A thoughtful ending'), findsNothing);
    expect(find.text('Attack on Titan'), findsOneWidget);
    expect(fixture.calls.any((c) => c.contains('/replies')), false);
    await tapSpace(t, 'Reveal discussion');
    expect(find.text('A thoughtful ending'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'My reply');
    await tapSpace(t, 'Post reply');
    expect(fixture.payload,
        {'body': 'My reply', 'reveal': true, 'mentionIds': []});
    expect(find.text('My reply'), findsOneWidget);
  });
  testWidgets('reply failure keeps draft and permits retry', (t) async {
    final fixture = SpaceFixture()..spoiler = false;
    await showSpace(
        t,
        CommunityDiscussionScreen(
            communityId: -1,
            discussionId: 'thread',
            service: fixture,
            joined: true));
    await t.enterText(find.byType(TextField), 'Keep this draft');
    fixture.fail = true;
    await tapSpace(t, 'Post reply');
    expect(find.text('Keep this draft'), findsOneWidget);
    expect(find.textContaining('Your reply is still here'), findsOneWidget);
  });
  for (final size in [
    const Size(430, 932),
    const Size(320, 640),
    const Size(844, 390),
    const Size(768, 1024)
  ]) {
    testWidgets('thread composer stays available at $size with large text',
        (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await showSpace(
          t,
          MediaQuery(
              data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(size.width == 430 ? 1 : 1.8)),
              child: CommunityDiscussionScreen(
                  communityId: -1,
                  discussionId: 'thread',
                  service: MentionFixture()..spoiler = false,
                  joined: true)));
      if (const bool.fromEnvironment('THREAD_CAPTURE')) {
        final boundary = t.renderObject<RenderRepaintBoundary>(
            find.byType(RepaintBoundary).first);
        await t.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('/tmp/thread-${size.width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(find.byTooltip('Post reply'), findsOneWidget);
      expect(t.getRect(find.byType(TextField)).bottom,
          lessThanOrEqualTo(size.height));
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('visitor joins from thread before writing', (t) async {
    final fixture = SpaceFixture()..spoiler = false;
    final membership = SpaceMembership(fixture);
    await showSpace(
        t,
        CommunityDiscussionScreen(
            communityId: -1,
            discussionId: 'thread',
            service: fixture,
            joined: false,
            membership: membership));
    expect(find.byType(TextField), findsNothing);
    await tapSpace(t, 'Join community');
    expect(membership.writes, 0);
    await tapSpace(t, 'Join');
    expect(membership.writes, 1);
    expect(find.byType(TextField), findsOneWidget);
  });
  testWidgets('opening a parent comment highlights it then clears', (t) async {
    await showSpace(
        t,
        CommunityDiscussionScreen(
            communityId: -1,
            discussionId: 'thread',
            service: MentionFixture()
              ..spoiler = false
              ..includeChild = true,
            joined: true));
    await tapSpace(t, 'Replying to @Ellis');
    final target = find.byKey(const ValueKey('reply-highlight-parent'));
    Color? color() =>
        (t.widget<AnimatedContainer>(target).decoration as BoxDecoration).color;
    expect(color(), isNot(Colors.transparent));
    await t.pump(const Duration(seconds: 2));
    await t.pumpAndSettle();
    expect(color(), Colors.transparent);
    await tapSpace(t, 'Replying to @Ellis');
    expect(color(), isNot(Colors.transparent));
    await t.pump(const Duration(seconds: 3));
    await t.pumpAndSettle();
    expect(color(), Colors.transparent);
  });
  testWidgets('composer sends selected series and explicit episode boundary',
      (t) async {
    final fixture = SpaceFixture();
    await showSpace(
        t, CommunityDiscussionComposer(communityId: -1, service: fixture));
    await t.enterText(find.byType(TextFormField).first, 'What did you think?');
    await t.enterText(
        find.widgetWithText(TextField, 'Search films or series'), 'Attack');
    await tapSpace(t, 'Search titles');
    await tapSpace(t, 'Attack on Titan');
    await t.tap(find.byType(DropdownButtonFormField<String>));
    await t.pumpAndSettle();
    await tapSpace(t, 'Through an episode');
    await t.enterText(find.widgetWithText(TextFormField, 'Season number'), '1');
    await t.enterText(
        find.widgetWithText(TextFormField, 'Episode number'), '25');
    await t.enterText(find.widgetWithText(TextFormField, 'Your post'),
        'An interesting question');
    fixture.fail = true;
    await tapSpace(t, 'Publish discussion');
    expect(fixture.payload?['showId'], 1429);
    expect(fixture.payload?['season'], 1);
    expect(fixture.payload?['episode'], 25);
    expect(find.textContaining('Your draft is kept'), findsOneWidget);
  });
  testWidgets('community load error retries and discover labels member score',
      (t) async {
    final fixture = SpaceFixture()..fail = true;
    await showSpace(t, CommunitySpaceScreen(communityId: -1, service: fixture));
    expect(find.textContaining('Couldn’t load this community'), findsOneWidget);
    fixture.fail = false;
    await tapSpace(t, 'Try again');
    await tapSpace(t, 'Discover');
    expect(find.text('Spirited Away'), findsOneWidget);
    expect(find.text('8.8/10'), findsOneWidget);
    expect(find.text('42 Anime members'), findsOneWidget);
  });
  testWidgets(
      'failed refresh of a complete feed retries and keeps loaded posts',
      (t) async {
    final fixture = SpaceFixture();
    await showSpace(
        t,
        Scaffold(
            body: SpaceCollection(
                communityId: -1,
                service: fixture,
                section: 'discussions',
                joined: true)));
    fixture.fail = true;
    await t.drag(find.byType(ListView), const Offset(0, 450));
    await t.pumpAndSettle();
    expect(find.text('Spoiler discussion'), findsOneWidget);
    expect(find.textContaining('Couldn’t load discussions'), findsOneWidget);
    fixture.fail = false;
    final before = fixture.calls.length;
    await tapSpace(t, 'Try again');
    expect(fixture.calls.length, greaterThan(before));
    expect(find.textContaining('Couldn’t load discussions'), findsNothing);
    expect(find.text('Spoiler discussion'), findsOneWidget);
  });
  testWidgets('composer spoiler choices fit a small phone with doubled text',
      (t) async {
    const size = Size(320, 640);
    await t.binding.setSurfaceSize(size);
    addTearDown(() => t.binding.setSurfaceSize(null));
    await showSpace(
        t,
        MediaQuery(
            data: const MediaQueryData(
                size: size, textScaler: TextScaler.linear(2)),
            child: CommunityDiscussionComposer(
                communityId: -1, service: SpaceFixture())));
    final search = find.widgetWithText(TextField, 'Search films or series');
    await t.scrollUntilVisible(search, 200,
        scrollable: find.byType(Scrollable).first);
    await t.ensureVisible(search);
    await t.enterText(search, 'Attack');
    await tapSpace(t, 'Search titles');
    await tapSpace(t, 'Attack on Titan');
    final dropdown = find.byType(DropdownButtonFormField<String>);
    await t.scrollUntilVisible(dropdown, 200,
        scrollable: find.byType(Scrollable).first);
    await t.ensureVisible(dropdown);
    await t.tap(dropdown);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await tapSpace(t, 'Through an episode');
    expect(t.takeException(), isNull);
  });
  for (final size in [
    const Size(320, 640),
    const Size(430, 932),
    const Size(844, 390),
    const Size(768, 1024)
  ]) {
    testWidgets('mobile-first community fits $size with enlarged text',
        (t) async {
      await t.binding.setSurfaceSize(size);
      addTearDown(() => t.binding.setSurfaceSize(null));
      final fixture = SpaceFixture()..spoiler = false;
      await showSpace(
          t,
          MediaQuery(
              data: MediaQueryData(
                  size: size, textScaler: const TextScaler.linear(2)),
              child: CommunitySpaceScreen(communityId: -1, service: fixture)));
      if (const bool.fromEnvironment('COMMUNITY_CAPTURE')) {
        final boundary = t.renderObject<RenderRepaintBoundary>(
            find.byType(RepaintBoundary).first);
        await t.runAsync(() async {
          final img = await boundary.toImage();
          final data = await img.toByteData(format: ui.ImageByteFormat.png);
          await File('/tmp/flixie-community-${size.width.toInt()}.png')
              .writeAsBytes(data!.buffer.asUint8List());
          img.dispose();
        });
      }
      expect(t.takeException(), isNull);
    });
  }
}
