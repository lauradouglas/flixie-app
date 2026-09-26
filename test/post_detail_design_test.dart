import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/features/social/presentation/pages/community_post_screen.dart';
import 'package:flixie_app/features/social/presentation/pages/friend_activity_screen.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_post_detail.dart';
import 'community_features_test.dart' show DiscussionFixture;

class DetailFixture extends DiscussionFixture {
  bool list = false, unavailable = false;
  @override
  Future<ActivityListItem> post(String owner, String type, String id) async {
    if (unavailable) throw Exception('private');
    if (!list) return super.post(owner, type, id);
    return const ActivityListItem(
        id: 'list',
        userId: 'author',
        username: 'LauraD',
        firstName: '',
        lastName: '',
        removed: false,
        createdAt: '2026-09-25T12:00:00Z',
        updatedAt: '',
        type: ActivityListType.movieListAdded,
        listId: 'list',
        listOwnerId: 'author',
        listName: 'Weekend favourites',
        listDescription: 'A few favourites for a cosy night in.',
        listAdditionCount: 8,
        listPreviewPosterPaths: ['/first.jpg', '/second.jpg', '/third.jpg'],
        profileBadges: ['founder']);
  }
}

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
      'public list shows real count, preserves preview data and opens its list',
      (tester) async {
    final service = DetailFixture()..list = true;
    final item = await service.post('author', 'movie-list-added', 'list');
    expect(item.copyWith().listPreviewPosterPaths, item.listPreviewPosterPaths);
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => CommunityPostScreen(
              ownerId: 'author',
              type: 'movie-list-added',
              postId: 'list',
              service: service)),
      GoRoute(
          path: '/movie-lists/:id',
          builder: (_, s) =>
              Scaffold(body: Text('List ${s.pathParameters['id']}')))
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('Public list · 8 titles'), findsOneWidget);
    expect(find.text('+5'), findsOneWidget);
    expect(find.text('View review'), findsNothing);
    await tester.scrollUntilVisible(find.text('Open list'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Open list'));
    await tester.pumpAndSettle();
    expect(find.text('List list'), findsOneWidget);
  });
  for (final kind in ['review', 'list', 'friends']) {
    for (final spec in [
      (const Size(390, 844), 1.0),
      (const Size(900, 500), 2.0)
    ]) {
      testWidgets('$kind detail reflows at ${spec.$1} / ${spec.$2}',
          (tester) async {
        tester.view.physicalSize = spec.$1;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = DetailFixture()..list = kind == 'list';
        final boundary = GlobalKey();
        final page = kind == 'friends'
            ? FriendActivityScreen(
                ownerId: 'author',
                type: 'movie-review',
                postId: 'post',
                service: service)
            : CommunityPostScreen(
                ownerId: 'author',
                type: kind == 'list' ? 'movie-list-added' : 'movie-review',
                postId: 'post',
                service: service);
        await tester.pumpWidget(RepaintBoundary(
            key: boundary,
            child: MaterialApp(
                theme: AppTheme.darkTheme,
                home: MediaQuery(
                    data: MediaQueryData(
                        size: spec.$1, textScaler: TextScaler.linear(spec.$2)),
                    child: ColoredBox(
                        color: FlixieColors.background, child: page)))));
        await tester.pumpAndSettle();
        expect(find.byType(ActivityPostDetail), findsOneWidget);
        expect(find.text('View review'), findsNothing);
        expect(tester.takeException(), isNull);
        const output = String.fromEnvironment('POST_SCREENSHOTS');
        if (output.isNotEmpty) {
          await tester.runAsync(() async {
            final image = await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            await Directory(output).create(recursive: true);
            await File('$output/$kind-${spec.$1.width.toInt()}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        if (kind == 'friends') {
          expect(find.byType(TextField), findsOneWidget);
          await tester.ensureVisible(find.byType(TextField));
          await tester.enterText(find.byType(TextField), 'My comment');
          await tester.pump();
          expect(tester.takeException(), isNull);
        } else {
          await tester.scrollUntilVisible(find.byType(TextField), 250,
              scrollable: find.byType(Scrollable).first);
          await tester.pumpAndSettle();
          expect(find.byType(TextField), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
