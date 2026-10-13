import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/pip_reaction.dart';
import 'package:flixie_app/models/activity_reaction.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_reaction_bubble.dart';
import 'package:flixie_app/features/movies/presentation/widgets/review/review_reactions.dart';

Future<void> pipReactionJourney(WidgetTester tester) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  Object? selected;
  await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!),
      home: Scaffold(
          body: Builder(
              builder: (context) => TextButton(
                  onPressed: () async {
                    selected = await showActivityReactionBubble(
                        context, context,
                        current: '❤️', canReply: true);
                  },
                  child: const Text('React'))))));
  for (final reaction in ActivityReaction.selectable) {
    await tester.tap(find.text('React'));
    await tester.pumpAndSettle();
    final option = find.byTooltip(reaction.label);
    await tester.ensureVisible(option);
    await tester.tap(option);
    await tester.pumpAndSettle();
    expect(selected, reaction);
    expect(tester.takeException(), isNull);
  }
  await tester.tap(find.text('React'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Reply in chat'));
  await tester.tap(find.text('Reply in chat'));
  await tester.pumpAndSettle();
  expect(selected, 'reply');
}

void main() {
  testWidgets('ten Pip options and reply fit a small phone with large text',
      pipReactionJourney);
  testWidgets('review picker sends stable keys for all ten Pip reactions',
      (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ReviewReactionStrip(
                reactions: const {},
                myReaction: null,
                reactingType: null,
                onReact: (key) => selected = key))));
    for (final key in [
      'love',
      'like',
      'dislike',
      'angry',
      'hot_take',
      'crying',
      'funny',
      'hmm',
      'fire',
      'agree',
    ]) {
      final emoji = reviewActivityReactions[key]!.emoji;
      final option = find.byWidgetPredicate(
          (widget) => widget is PipReaction && widget.value == emoji);
      await tester.ensureVisible(option);
      await tester.tap(option);
      expect(selected, key);
    }
    expect(find.byType(PipReaction), findsNWidgets(10));
  });
  testWidgets('legacy Interested and Surprised counts retain their meaning',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: ReviewReactionPreview(
                reactions: {'interested': 2, 'surprised': 1},
                myReaction: 'interested'))));
    expect(
        find.byWidgetPredicate((widget) =>
            widget is PipReactionCount &&
            widget.value == 'interested' &&
            widget.count == 2),
        findsOneWidget);
    expect(
        find.byWidgetPredicate((widget) =>
            widget is PipReactionCount &&
            widget.value == 'surprised' &&
            widget.count == 1),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('all selectable and legacy Pip assets are bundled transparent PNGs',
      () async {
    for (final reaction in ActivityReaction.values) {
      final data = await rootBundle.load(reaction.asset);
      final bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      expect(bytes[25], anyOf(4, 6), reason: reaction.label);
    }
  });
}
