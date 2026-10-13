import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/profile_milestone.dart';
import 'package:flixie_app/features/profile/presentation/widgets/recent_milestones.dart';

ProfileMilestone award(String title, String group, String family, int day,
        {bool earned = true}) =>
    ProfileMilestone(
        id: title,
        family: family,
        group: group,
        title: title,
        description: '',
        target: 10,
        progress: 10,
        earned: earned,
        earnedAt: DateTime(2026, 10, day));
final fixture = ProfileMilestones(owner: true, items: [
  award('Film explorer', 'Watching', 'films', 8),
  award('Movie mates', 'Together', 'movie_mates', 11),
  award('Around the world', 'Exploring', 'countries', 10),
  award('Your first review', 'Your voice', 'reviews', 9),
  award('Locked milestone', 'Watching', 'films', 12, earned: false),
]);
void main() {
  testWidgets('shows three newest earned awards and real dates across layouts',
      (t) async {
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    for (final config in [
      (320.0, 2.0),
      (430.0, 1.0),
      (834.0, 1.0),
      (1194.0, 1.0),
      (844.0, 2.0)
    ]) {
      t.view.physicalSize = Size(config.$1, 900);
      await t.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(config.$2)),
              child: Scaffold(
                  body: SingleChildScrollView(
                      child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: RecentMilestones(data: fixture)))))));
      expect(find.byType(MilestoneShield), findsNWidgets(3));
      expect(find.text('Film explorer'), findsNothing);
      expect(find.text('Locked milestone'), findsNothing);
      expect(t.getTopLeft(find.text('Movie mates')).dy,
          lessThanOrEqualTo(t.getTopLeft(find.text('Around the world')).dy));
      final date =
          MaterialLocalizations.of(t.element(find.byType(RecentMilestones)))
              .formatMediumDate(DateTime(2026, 10, 11));
      expect(find.text('Earned $date'), findsOneWidget);
      expect(t.takeException(), isNull);
    }
  });
  testWidgets('empty and failed loads are distinct; retry remains actionable',
      (t) async {
    var retried = false;
    await t.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: RecentMilestones(
                data: ProfileMilestones(items: [], owner: true)))));
    expect(find.textContaining('Your first milestone'), findsOneWidget);
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RecentMilestones(
                failed: true, onRetry: () => retried = true))));
    expect(find.textContaining('Your first milestone'), findsNothing);
    await t.tap(find.text('Retry milestones'));
    expect(retried, isTrue);
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RecentMilestones(
                data: fixture, failed: true, onRetry: () {}))));
    expect(find.byType(MilestoneShield), findsNWidgets(3));
  });
  testWidgets('capture milestone shields for visual review', (t) async {
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final font = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'));
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await t.runAsync(() async {
      await font.load();
      await icons.load();
    });
    for (final width in [390.0, 1000.0]) {
      t.view.physicalSize = Size(width, 360);
      final key = GlobalKey();
      await t.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
              body: RepaintBoundary(
                  key: key,
                  child: ColoredBox(
                      color: const Color(0xFF111019),
                      child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: RecentMilestones(data: fixture)))))));
      await t.pump();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await t.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('/tmp/flixie-milestones-${width.toInt()}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
