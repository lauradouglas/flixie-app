import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/watch_plan_reminder_policy.dart';
import 'package:flixie_app/core/utils/watch_plan_schedule.dart';
import 'package:flixie_app/features/watch_plans/presentation/sheets/watch_plan_schedule_sheet.dart';
import 'package:flixie_app/features/watch_plans/presentation/utils/watch_plan_formatters.dart';
import 'package:flixie_app/models/watch_request.dart';
import 'package:flixie_app/models/group_watch_request.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  test(
      'date-only plan has one 9am local reminder and no start or follow-up reminder',
      () {
    final day = DateTime.utc(2026, 10, 8, 12);
    final times = watchPlanReminderTimes(day,
        now: DateTime(2026, 10, 7, 18), dateOnly: true);
    expect(times.morning, DateTime(2026, 10, 8, 9));
    expect(times.beforeWatch, isNull);
    expect(times.followUp, isNull);
    expect(
        watchPlanReminderTimes(day,
                now: DateTime(2026, 10, 8, 10), dateOnly: true)
            .morning,
        isNull);
  });

  test('date-only remains upcoming until the calendar day ends', () {
    final plan = WatchRequest.fromJson({
      'id': 'date-plan',
      'requesterId': 'one',
      'recipientId': 'two',
      'status': 'ACCEPTED',
      'type': 'MOVIE_WATCH_REQUEST',
      'scheduleStatus': 'AGREED',
      'scheduledFor': '2026-10-08T12:00:00.000Z',
      'scheduledDateOnly': true,
    });
    expect(plan.planStageFor('one', now: DateTime(2026, 10, 8, 23)),
        WatchPlanStage.upcoming);
    expect(plan.planStageFor('one', now: DateTime(2026, 10, 9, 1)),
        WatchPlanStage.past);
    expect(
        formatWatchPlanDateTime(plan.scheduledFor,
            dateOnly: true, now: DateTime(2026, 10, 8, 18)),
        'Today · Time optional');
  });

  test('a real noon appointment keeps its chosen time', () {
    final noon = DateTime(2026, 10, 8, 12);
    expect(formatWatchPlanDateTime(noon, now: DateTime(2026, 10, 7)),
        contains('12:00pm'));
    expect(watchPlanScheduleHasPassed(noon, now: DateTime(2026, 10, 8, 13)),
        isTrue);
  });

  test(
      'adding a noon time to a date-only group plan stays visible for approval',
      () {
    final plan = GroupWatchRequest.fromJson({
      'id': 'group-plan',
      'groupId': 'group',
      'userId': 'one',
      'status': 'scheduled',
      'scheduledFor': '2026-10-08T12:00:00Z',
      'scheduledDateOnly': true,
      'scheduleProposals': [
        {
          'id': 'new-time',
          'proposerId': 'two',
          'status': 'PENDING',
          'proposedFor': '2026-10-08T12:00:00Z',
          'dateOnly': false
        },
      ],
    });
    expect(plan.activeScheduleProposal?.id, 'new-time');
  });

  testWidgets(
      'saving only a date returns a date-only schedule without adding a time',
      (tester) async {
    ({
      DateTime proposedFor,
      bool dateOnly,
      String? message,
      String? location
    })? result;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Builder(
          builder: (context) => Scaffold(
              body: TextButton(
                  onPressed: () async {
                    result = await showModalBottomSheet(
                        context: context,
                        useRootNavigator: true,
                        useSafeArea: true,
                        isScrollControlled: true,
                        builder: (_) => const WatchPlanScheduleSheet());
                  },
                  child: const Text('Open schedule')))),
    ));
    await tester.tap(find.text('Open schedule'));
    await tester.pumpAndSettle();
    expect(find.text('TIME'), findsNothing);
    await tester.tap(find.text('Tomorrow'));
    await tester.ensureVisible(find.text('Save schedule'));
    await tester.tap(find.text('Save schedule'));
    await tester.pumpAndSettle();
    expect(result?.dateOnly, isTrue);
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    expect(result?.proposedFor, encodeWatchPlanDate(tomorrow));
  });

  testWidgets(
      'date-only sheet reflows on small phones, tablets, landscape and large text',
      (tester) async {
    final captureKey = GlobalKey();
    for (final sample in [
      (size: const Size(390, 844), scale: 1.0, name: 'phone'),
      (size: const Size(320, 568), scale: 2.0, name: 'small-phone'),
      (size: const Size(1024, 768), scale: 1.5, name: 'tablet'),
      (size: const Size(844, 390), scale: 1.5, name: 'landscape'),
    ]) {
      tester.view.physicalSize = sample.size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(RepaintBoundary(
          key: captureKey,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => showModalBottomSheet(
                            context: context,
                            useRootNavigator: true,
                            useSafeArea: true,
                            isScrollControlled: true,
                            builder: (_) => MediaQuery(
                                data: MediaQuery.of(context).copyWith(
                                    textScaler:
                                        TextScaler.linear(sample.scale)),
                                child: const WatchPlanScheduleSheet())),
                        child: const Text('Open schedule')))),
          )));
      await tester.tap(find.text('Open schedule'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: sample.name);
      if (sample.name == 'phone' || sample.name == 'small-phone') {
        await tester.runAsync(() async {
          final boundary = captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
                  '${Directory.systemTemp.path}/flixie-watch-date-${sample.name}.png')
              .writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.ensureVisible(find.text('Save schedule'));
      await tester.tap(find.text('Save schedule'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: sample.name);
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
