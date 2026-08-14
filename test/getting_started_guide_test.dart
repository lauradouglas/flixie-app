import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flixie_app/features/authentication/presentation/pages/getting_started_guide_screen.dart';

void main() {
  testWidgets('guide covers Flixie core journeys', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GettingStartedGuideScreen(openedFromSettings: true),
      ),
    );

    expect(find.textContaining('Favourite on a movie'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.textContaining('movie log'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Watch Providers'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.textContaining('watch request'), findsOneWidget);
    expect(find.textContaining('create a group'), findsOneWidget);
    expect(find.textContaining('Chat directly'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(
      find.text('Choose selected friends who can add to a joint list'),
      findsOneWidget,
    );
    expect(find.text('Flixie is better with friends'), findsOneWidget);
    expect(find.text('Invite a film friend'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });
}
