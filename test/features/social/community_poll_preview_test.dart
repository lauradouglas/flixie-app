import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/social/presentation/widgets/discussion/community_poll_preview.dart';

void main() {
  testWidgets(
      'feed ranks real results, marks own vote and opens without voting',
      (t) async {
    var opened = 0;
    final poll = {
      'totalVotes': 3,
      'selectedOptionId': 'a',
      'options': [
        {'id': 'b', 'title': 'Spirited Away', 'votes': 1},
        {'id': 'a', 'title': 'Attack on Titan', 'votes': 2},
      ]
    };
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CommunityPollPreview(poll: poll, onOpen: () => opened++))));
    expect(t.getTopLeft(find.text('Attack on Titan')).dy,
        lessThan(t.getTopLeft(find.text('Spirited Away')).dy));
    expect(find.text('67%'), findsOneWidget);
    expect(find.text('33%'), findsOneWidget);
    expect(find.text('Your pick'), findsOneWidget);
    await t.tap(find.text('Attack on Titan'));
    await t.tap(find.text('Vote or add a title'));
    expect(opened, 2);
    expect(poll['totalVotes'], 3);
  });

  testWidgets('own pick remains visible below three leaders', (t) async {
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CommunityPollPreview(poll: {
      'totalVotes': 7,
      'selectedOptionId': '3',
      'options': List.generate(
          4, (i) => {'id': '$i', 'title': 'Title $i', 'votes': i == 3 ? 1 : 2})
    }, onOpen: () {}))));
    expect(find.text('Your pick: Title 3'), findsOneWidget);
    expect(find.text('+1 more titles'), findsOneWidget);
  });

  testWidgets('empty closed results remain readable with enlarged text',
      (t) async {
    await t.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(
          size: Size(320, 700), textScaler: TextScaler.linear(2)),
      child: Scaffold(
          body: SingleChildScrollView(
              child: CommunityPollPreview(poll: {
        'totalVotes': 0,
        'closedAt': 'closed',
        'options': [
          {'id': 'a', 'title': 'Nausicaä of the Valley of the Wind', 'votes': 0}
        ]
      }, onOpen: () {}))),
    )));
    expect(find.text('No votes yet'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('View results'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
