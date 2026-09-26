import 'package:flutter/services.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/activity_reaction.dart';
import 'package:flixie_app/features/profile/presentation/widgets/compact_activity_post.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/shared/watch_plan_components.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => '/tmp/flixie-polish-test');
    messenger.setMockMethodCallHandler(
        const MethodChannel('com.tekartik.sqflite'), (call) async {
      if (call.method == 'getDatabasesPath') return '/tmp/flixie-polish-test';
      if (call.method == 'openDatabase') return {'id': 1};
      if (call.method == 'query') return <Object>[];
      return null;
    });
  });
  for (final size in [
    const Size(320, 700),
    const Size(430, 900),
    const Size(900, 500)
  ]) {
    testWidgets('list posters and compact actions fit $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var opened = false;
      final capture = GlobalKey();
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) =>
              RepaintBoundary(key: capture, child: child!),
          home: Scaffold(
              body: SingleChildScrollView(
            child: MediaQuery(
                data: MediaQueryData(
                    size: size,
                    textScaler: TextScaler.linear(size.width == 900 ? 2 : 1)),
                child: CompactActivityPost(
                  item: const ActivityListItem(
                      id: 'list',
                      userId: 'author',
                      username: 'LauraD',
                      firstName: '',
                      lastName: '',
                      removed: false,
                      createdAt: '',
                      updatedAt: '',
                      type: ActivityListType.movieListAdded,
                      listName: '2026 hits',
                      listAdditionCount: 4,
                      listPreviewPosterPaths: [
                        '/one.jpg',
                        '/two.jpg',
                        '/three.jpg'
                      ]),
                  label: 'Added to a list',
                  age: '14h ago',
                  reactions: const ActivityReactionSummary(
                      counts: {'❤️': 1}, mine: '❤️'),
                  publicPost: true,
                  onComment: () => opened = true,
                )),
          ))));
      await tester.pump();
      expect(find.byType(WatchPlanPoster), findsNWidgets(3));
      final emoji = tester.getCenter(find.text('❤️'));
      final count = tester.getCenter(find.text('1'));
      expect((emoji.dy - count.dy).abs(), lessThan(1));
      await tester.ensureVisible(find.text('View post'));
      await tester.tap(find.text('View post'));
      expect(opened, isTrue);
      await tester.pumpAndSettle();
      if (const bool.fromEnvironment('POLISH_SCREENSHOTS')) {
        await tester.runAsync(() async {
          final boundary = capture.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('/tmp/list-polish-${size.width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(tester.takeException(), isNull);
    });
  }
}
