import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_favourite_people.dart';

void main() {
  testWidgets('people gallery shows actual departments and only selected roles',
      (t) async {
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
            body: SingleChildScrollView(
                child: ProfileFavouritePeople(people: const [
          {'id': 1, 'name': 'Christopher Nolan', 'department': 'Directing'},
          {'id': 2, 'name': 'Florence Pugh', 'department': 'Acting'},
          {'id': 3, 'name': 'Cillian Murphy', 'department': 'Acting'},
        ], featured: const {
          'director': 1,
          'actress': 2
        }, onChoose: (_, __) async {})))));
    await t.tap(find.text('All (3)'));
    await t.pumpAndSettle();
    expect(find.text('Directing'), findsOneWidget);
    expect(find.text('Acting'), findsNWidgets(2));
    expect(find.text('Director').hitTestable(), findsOneWidget);
    expect(find.text('Actress').hitTestable(), findsOneWidget);
    expect(find.text('Actor').hitTestable(), findsNothing);
    expect(t.takeException(), isNull);
  });
}
