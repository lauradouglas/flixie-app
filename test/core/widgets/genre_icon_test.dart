import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/utils/genre_catalogue.dart';
import 'package:flixie_app/core/widgets/genre_icon.dart';
import 'package:flixie_app/features/authentication/presentation/pages/auth_ui.dart'
    as auth;

void main() {
  test('TV films are omitted regardless of catalogue spelling', () {
    for (final name in ['TV Movie', 'TV Films', ' tv film ', 'TV movies']) {
      expect(isVisibleGenre(name), isFalse);
    }
    expect(isVisibleGenre('Television', id: 10770), isFalse);
    expect(isVisibleGenre('Science Fiction'), isTrue);
    expect(genreIconId('Sci-fi'), genreIconId('Science Fiction'));
  });

  testWidgets('genre icon keeps selection working at large text sizes',
      (tester) async {
    var selected = false;
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2)),
      child: Scaffold(
          body: StatefulBuilder(
              builder: (context, setState) => Wrap(children: [
                    auth.GenreChip(
                        label: 'Science Fiction',
                        selected: selected,
                        onTap: () => setState(() => selected = !selected)),
                  ]))),
    )));
    expect(find.byType(GenreIcon), findsOneWidget);
    await tester.tap(find.text('Science Fiction'));
    await tester.pump();
    expect(selected, isTrue);
    await tester.tap(find.text('Science Fiction'));
    await tester.pump();
    expect(selected, isFalse);
    expect(tester.takeException(), isNull);
  });
}
