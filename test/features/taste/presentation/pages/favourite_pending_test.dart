import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/authentication/data/setup_service.dart';
import 'package:flixie_app/features/authentication/presentation/widgets/signup_title_grid.dart';

void main() {
  testWidgets('only pending favourite spins while other hearts are disabled',
      (tester) async {
    var calls = 0;
    Widget grid(bool busy) => MaterialApp(
            home: Scaffold(
                body: SignupTitleGrid(
          titles: const [
            SetupTitle(348, 'Alien', null),
            SetupTitle(157336, 'Interstellar', null)
          ],
          saved: const {},
          pending: busy ? {'movie:348'} : {},
          favourites: true,
          disabled: busy,
          onAdd: (_) => calls++,
        )));
    await tester.pumpWidget(grid(true));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final alien = find.byTooltip('Add Alien to favourites');
    final other = find.byTooltip('Add Interstellar to favourites');
    expect(
        find.descendant(
            of: alien, matching: find.byType(CircularProgressIndicator)),
        findsOneWidget);
    expect(
        find.descendant(
            of: other, matching: find.byType(CircularProgressIndicator)),
        findsNothing);
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate((widget) =>
                widget is IconButton &&
                widget.tooltip == 'Add Interstellar to favourites'))
            .onPressed,
        isNull);
    await tester.tap(other);
    expect(calls, 0);
    await tester.pumpWidget(grid(false));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(other);
    expect(calls, 1);
  });
}
