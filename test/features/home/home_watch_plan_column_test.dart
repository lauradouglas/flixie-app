import 'package:flixie_app/features/home/presentation/widgets/home_watch_plan_card.dart';
import 'package:flixie_app/features/home/presentation/widgets/home_tablet_layout.dart';
import 'package:flixie_app/features/home/presentation/widgets/section_header.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/home/presentation/widgets/home_watch_plan_column.dart';
import 'package:flixie_app/features/home/presentation/models/home_watch_plan_state.dart';
import 'package:flixie_app/models/watch_request.dart';

void main() {
  for (final width in [320.0, 600.0, 1024.0]) {
    testWidgets(
        'tablet plan column shows both actions in order at width $width',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final states = [
        for (final title in ['Alien', 'The Odyssey'])
          HomeWatchPlanState(
              plan: WatchRequest(
                  id: title,
                  requesterId: 'friend',
                  recipientId: 'me',
                  status: 'pending',
                  type: 'MOVIE_WATCH_REQUEST',
                  movie: WatchRequestMovieDetails(id: 1, title: title)),
              type: HomeWatchPlanStateType.chooseFinalMovie,
              priority: 1,
              eyebrow: 'Needs your reply',
              title: title,
              supportingText: 'Invited by a friend',
              actionLabel: 'View invitation',
              requiresAttention: true)
      ];
      await (FontLoader('Manrope')
            ..addFont(
                rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
          .load();
      String? opened;
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
              backgroundColor: const Color(0xFF150C24),
              body: RepaintBoundary(
                  key: boundaryKey,
                  child: SingleChildScrollView(
                      child: HomeWatchPlanColumn(
                          states: states,
                          onOpen: (state) => opened = state.plan.id))))));
      await tester.pump();
      final actions = find.text('View invitation');
      expect(actions, findsNWidgets(2));
      expect(tester.getTopLeft(actions.at(1)).dy,
          greaterThan(tester.getBottomLeft(actions.at(0)).dy));
      await tester.tap(actions.at(1));
      expect(opened, 'The Odyssey');
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('PLAN_COLUMN_CAPTURE') && width == 600) {
        final boundary = boundaryKey.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('/tmp/flixie-tablet-plan-column.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
  testWidgets('wide Home previews one priority plan and retains See all',
      (tester) async {
    final states = [
      for (final title in ['Alien', 'The Odyssey'])
        HomeWatchPlanState(
            plan: WatchRequest(
                id: title,
                requesterId: 'friend',
                recipientId: 'me',
                status: 'pending',
                type: 'MOVIE_WATCH_REQUEST',
                movie: WatchRequestMovieDetails(id: 1, title: title)),
            type: HomeWatchPlanStateType.chooseFinalMovie,
            priority: 1,
            eyebrow: 'Needs your reply',
            title: title,
            supportingText: 'Invited by a friend',
            actionLabel: 'View invitation',
            requiresAttention: true)
    ];
    var openedAll = false;
    String? opened;
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
            body: SingleChildScrollView(
                child: HomeTabletScope(
                    child: SizedBox(
                        width: 300,
                        child: Column(children: [
                          HomeSectionHeader(
                              title: 'Watch together',
                              onSeeAll: () => openedAll = true),
                          HomeWatchPlanColumn(
                              states: states,
                              onOpen: (s) => opened = s.plan.id),
                        ])))))));
    expect(find.byType(HomeWatchPlanCard), findsOneWidget);
    expect(find.text('Alien'), findsWidgets);
    expect(find.text('The Odyssey'), findsNothing);
    await tester.tap(find.text('View invitation'));
    expect(opened, 'Alien');
    await tester.tap(find.text('See all'));
    expect(openedAll, isTrue);
    expect(tester.takeException(), isNull);
  });
}
