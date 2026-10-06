// Design exploration only. Alternative widgets are not wired into the app.
// WRITE_NOTIFICATION_MOCKUPS=1 flutter test --update-goldens test/notification_design_mockups_test.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/foreground_watch_plan_notice.dart';
import 'package:flixie_app/core/widgets/flixie_wordmark.dart';

const _samples = [
  ForegroundWatchPlanNotice(key: 'plan', title: 'Robin suggested a new time',
    body: 'Alien · Saturday 10 October at 7:30pm. Open your plan to review the suggestion.', path: '/watch-requests/plan'),
  ForegroundWatchPlanNotice(key: 'message', title: 'New message from Ellis',
    body: 'Shall we watch The Odyssey on Sunday?', path: '/chat/ellis', actionLabel: 'View message'),
  ForegroundWatchPlanNotice(key: 'invite', title: 'You’re invited to Four Film Friends',
    body: 'Robin invited you to join the group. Open your notifications to respond.', path: '/notifications', actionLabel: 'View invitation'),
];
const _icons = [Icons.calendar_today_outlined, Icons.chat_bubble_outline, Icons.group_add_outlined];
const _labels = ['Watch Plan update', 'Direct message', 'Group invitation'];

void main() {
  testWidgets('compare current banner with two isolated design variations', (tester) async {
    await (FontLoader('Manrope')..addFont(rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'))).load();
    await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await tester.binding.setSurfaceSize(const Size(1380, 1140));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final boundary = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: boundary, child: MaterialApp(
      debugShowCheckedModeBanner: false, theme: AppTheme.darkTheme,
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(36), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Text.rich(flixieWordmarkSpan(fontSize: 30, fontFamily: 'Manrope')), const Spacer(),
            const Text('In-app notifications · Design comparison', style: TextStyle(color: FlixieColors.light))]),
          const SizedBox(height: 24),
          const Text('A little update. Back to your film.', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Same events, three treatments. Each example appears individually at the top of the app.', style: TextStyle(color: FlixieColors.light, fontSize: 15)),
          const SizedBox(height: 34),
          Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var variant = 0; variant < 3; variant++) ...[
              if (variant > 0) const SizedBox(width: 24),
              Expanded(child: _Column(variant: variant)),
            ],
          ])),
          const Text('Illustrative content · Current uses the existing Flutter widget · Alternatives are mockups only', style: TextStyle(color: FlixieColors.light, fontSize: 13)),
          const SizedBox(height: 8),
          const Text('Community replies stay in the notifications tab; none of these banners is shown for them.', style: TextStyle(color: FlixieColors.light, fontSize: 13)),
        ],
      ))))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('View plan'), findsNWidgets(3));
    if (Platform.environment['WRITE_NOTIFICATION_MOCKUPS'] == '1') {
      await expectLater(find.byKey(boundary), matchesGoldenFile('/tmp/flixie-notification-designs.png'));
    }
  });
}

class _Column extends StatelessWidget {
  const _Column({required this.variant});
  final int variant;
  @override
  Widget build(BuildContext context) {
    const names = ['Current', 'Compact', 'Clear action'];
    const descriptions = ['The existing banner, unchanged.', 'Less space. A lighter interruption.', 'Stronger hierarchy and a clear next step.'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(names[variant], style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(descriptions[variant], style: const TextStyle(fontSize: 13, color: FlixieColors.light)),
      const SizedBox(height: 24),
      for (var i = 0; i < _samples.length; i++)
        SizedBox(height: 244, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_labels[i], style: const TextStyle(color: FlixieColors.light, fontSize: 12)),
          const SizedBox(height: 10),
          if (variant == 0)
            WatchPlanNoticeBanner(notice: _samples[i], onOpen: () {}, onDismiss: () {})
          else _Alternative(notice: _samples[i], icon: _icons[i], prominent: variant == 2),
        ])),
    ]);
  }
}

class _Alternative extends StatelessWidget {
  const _Alternative({required this.notice, required this.icon, required this.prominent});
  final ForegroundWatchPlanNotice notice;
  final IconData icon;
  final bool prominent;
  @override
  Widget build(BuildContext context) {
    return Material(color: prominent ? const Color(0xFF2E1D51) : FlixieColors.surfaceElevated,
      borderRadius: BorderRadius.circular(prominent ? 16 : 12), elevation: 6,
      child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 8, 12), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 9, right: 12), child: Icon(icon, size: 22, color: FlixieColors.primaryTint)),
            Expanded(child: Padding(padding: const EdgeInsets.only(top: 7), child: Text(notice.title,
              style: TextStyle(fontSize: prominent ? 16 : 14, fontWeight: FontWeight.w700, height: 1.35)))),
            SizedBox(width: 44, height: 44, child: IconButton(onPressed: () {}, tooltip: 'Dismiss update', icon: const Icon(Icons.close, size: 18, color: FlixieColors.light))),
          ]),
          Padding(padding: EdgeInsets.only(left: prominent ? 0 : 34, right: 8), child: Text(notice.body,
            style: const TextStyle(fontSize: 13, height: 1.5, color: FlixieColors.lightTint))),
          const SizedBox(height: 8),
          if (prominent) Padding(padding: const EdgeInsets.only(right: 8), child: SizedBox(width: double.infinity, height: 44,
            child: FilledButton(style: FilledButton.styleFrom(backgroundColor: FlixieColors.primary,
              foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () {}, child: Text(notice.actionLabel, style: const TextStyle(fontWeight: FontWeight.w700)))))
          else Padding(padding: const EdgeInsets.only(left: 22), child: TextButton(onPressed: () {},
            style: TextButton.styleFrom(foregroundColor: FlixieColors.primaryTint, minimumSize: const Size(44, 44)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [Text(notice.actionLabel), const SizedBox(width: 8), const Icon(Icons.arrow_forward, size: 16)]))),
        ],
      )));
  }
}
