import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import '../patrol_test/support/fixture_app.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/social/data/community_service.dart';
import 'package:flixie_app/features/social/presentation/pages/community_activity_feed.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/models/activity_list_item.dart';

ActivityListItem fixture(String id) => ActivityListItem.fromJson({
      'id': id,
      'userId': 'friend',
      'username': 'A friend with a longer name',
      'firstName': '',
      'lastName': '',
      'createdAt': '2026-09-24T12:00:00Z',
      'updatedAt': '2026-09-24T12:00:00Z',
      'type': 'movie-review',
      'movieId': 1,
      'movie': {'title': 'A film that stays with you long after the credits'},
      'rating': 9,
      'body': 'A thoughtful story, beautifully told.',
      'recommended': true,
      'profileBadges': ['founder'],
    });

class FixtureCommunity extends CommunityService {
  @override
  Future<bool> follows(String path) async => false;
  @override
  Future<void> follow(String path, bool value) async {}
  @override
  Future<Map<String, dynamic>> replies(ActivityListItem item,
          {String? cursor, String? parent}) async =>
      {'items': [], 'nextCursor': null, 'repliesEnabled': true};
  @override
  Future<void> resetFeedPreferences() async {}

  bool enabled = false, fail = false;
  final cursors = <String?>[];
  final queries = <String>[];
  final savedPosts = <String>{};
  final prefs = <String, dynamic>{
    'communityProfileDetails': false,
    'communityReplyNotifications': true,
    'communityReactionNotifications': true
  };
  @override
  Future<Map<String, dynamic>> settings() async =>
      {'communitySharing': enabled, ...prefs};
  @override
  Future<void> updateSettings(Map<String, bool> values) async {
    if (fail) throw Exception('offline');
    prefs.addAll(values);
  }

  @override
  Future<bool> isSaved(ActivityListItem item) async =>
      savedPosts.contains(item.id);
  @override
  Future<void> save(ActivityListItem item, bool saved) async {
    if (fail) throw Exception('offline');
    if (saved) {
      savedPosts.add(item.id);
    } else {
      savedPosts.remove(item.id);
    }
  }

  @override
  Future<bool> sharing() async => enabled;
  @override
  Future<void> setSharing(bool value) async {
    if (fail) throw Exception('offline');
    enabled = value;
  }

  @override
  Future<CommunityPage> load(
      {String? cursor,
      String filter = 'all',
      String sort = 'latest',
      String? owner,
      bool saved = false}) async {
    cursors.add(cursor);
    queries.add('$filter:$sort:$saved');
    if (fail) throw Exception('offline');
    return CommunityPage([fixture(cursor == null ? 'first' : 'second')],
        cursor == null ? 'next' : null);
  }
}

Widget app(FixtureCommunity service, {double scale = 1}) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.darkTheme,
    home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
            backgroundColor: FlixieColors.background,
            body: CommunityActivityFeed(service: service))));
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
  testWidgets(
      'saving a community film sends the watchlist request and confirms success',
      (tester) async {
    final auth = FixtureAuth();
    addTearDown(auth.dispose);
    final writes = <String>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth, child: app(FixtureCommunity())));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Activity options').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Watchlist'));
      await tester.pumpAndSettle();
      expect(writes.single, contains('/watchlist/1'));
      expect(find.text('Saved to watchlist'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              if (request.method == 'POST') {
                writes.add(request.url.path);
                return http.Response(
                    jsonEncode({
                      'id': 'saved',
                      'userId': 'patrol-viewer',
                      'movieId': 1,
                      'removed': false
                    }),
                    200);
              }
              return http.Response('{}', 200);
            }));
  });

  testWidgets(
      'sharing persists, pagination appends, failures keep the previous setting',
      (tester) async {
    final service = FixtureCommunity();
    await tester.pumpWidget(app(service));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileAvatarView), findsOneWidget);
    expect(
        tester
            .widget<ProfileAvatarView>(find.byType(ProfileAvatarView))
            .profileBadges,
        ['founder']);
    await tester.tap(find.byTooltip('Around Flixie sharing'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.descendant(
        of: find.widgetWithText(SwitchListTile, 'Share on Around Flixie'),
        matching: find.byType(Switch)));
    await tester.tap(find.descendant(
        of: find.widgetWithText(SwitchListTile, 'Share on Around Flixie'),
        matching: find.byType(Switch)));
    await tester.pumpAndSettle();
    expect(service.enabled, true);
    service.fail = true;
    await tester.tap(find.descendant(
        of: find.widgetWithText(SwitchListTile, 'Share on Around Flixie'),
        matching: find.byType(Switch)));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<Switch>(find.descendant(
                of: find.widgetWithText(SwitchListTile, 'Share on Around Flixie'),
                matching: find.byType(Switch)))
            .value,
        true);
    expect(find.text('Couldn’t update sharing. Please try again.'),
        findsOneWidget);
    service.fail = false;
    await tester.tap(find.byTooltip('Close settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Show more'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Show more'));
    await tester.pumpAndSettle();
    expect(service.cursors.last, 'next');
    expect(find.text('Show more'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final scenario in [
    (const Size(320, 700), 1.0),
    (const Size(430, 900), 1.0),
    (const Size(900, 500), 2.0),
    (const Size(768, 1024), 1.5)
  ]) {
    testWidgets('community fits ${scenario.$1} at ${scenario.$2} text scale',
        (tester) async {
      tester.view.physicalSize = scenario.$1;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final capture = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: capture, child: app(FixtureCommunity(), scale: scenario.$2)));
      await tester.pumpAndSettle();
      const screenshots = String.fromEnvironment('COMMUNITY_SCREENSHOTS');
      if (screenshots.isNotEmpty) {
        await tester.runAsync(() async {
          final boundary = capture.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(screenshots).create(recursive: true);
          await File('$screenshots/community-${scenario.$1.width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.byTooltip('Activity options').first);
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('failed feed has a working retry', (tester) async {
    final service = FixtureCommunity()..fail = true;
    await tester.pumpWidget(app(service));
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t load Around Flixie.'), findsOneWidget);
    service.fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t load Around Flixie.'), findsNothing);
    expect(find.byType(ProfileAvatarView), findsOneWidget);
  });
}
