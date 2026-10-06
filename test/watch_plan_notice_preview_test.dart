import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/foreground_watch_plan_notice.dart';

void main() {
  testWidgets('render the actual friend and group banner widgets',
      (tester) async {
    final fonts = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'));
    await fonts.load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    await tester.binding.setSurfaceSize(const Size(430, 630));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final boundary = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
        key: boundary,
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            home: Scaffold(
                body: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        const Text('Friend Watch Plan',
                            style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 12),
                        WatchPlanNoticeBanner(
                            notice: const ForegroundWatchPlanNotice(
                                key: 'friend',
                                title: 'Robin suggested a new date',
                                body:
                                    'Alien · Saturday 10 October. Open your plan to review the latest suggestion.',
                                path: '/watch-requests/friend'),
                            onOpen: () {},
                            onDismiss: () {}),
                        const SizedBox(height: 32),
                        const Text('Group Watch Plan',
                            style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 12),
                        WatchPlanNoticeBanner(
                            notice: const ForegroundWatchPlanNotice(
                                key: 'group',
                                title: 'Ellis suggested a new time',
                                body:
                                    'Four Film Friends · The Odyssey\nSunday 11 October at 7:30pm. Review it with your group.',
                                path: '/groups/group'),
                            onOpen: () {},
                            onDismiss: () {}),
                      ],
                    ))))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('View plan'), findsNWidgets(2));
    if (Platform.environment['WRITE_NOTICE_PREVIEW'] == '1') {
      await expectLater(find.byKey(boundary),
          matchesGoldenFile('/tmp/flixie-watch-plan-banners.png'));
    }
  });
}
