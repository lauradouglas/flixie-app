import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/country.dart';
import 'package:flixie_app/features/authentication/presentation/pages/signup_screen.dart';

void main() {
  testWidgets(
      'signup country picker renders, filters and selects without ink assertions',
      (tester) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Country? selected;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
          body: Builder(
              builder: (context) => TextButton(
                    child: const Text('Country'),
                    onPressed: () async {
                      selected = await showModalBottomSheet<Country>(
                        context: context,
                        isScrollControlled: true,
                        useRootNavigator: true,
                        useSafeArea: true,
                        builder: (_) =>
                            const SignupCountryPickerSheet(countries: [
                          Country(
                              id: 1,
                              name: 'United Kingdom',
                              abbreviation: 'GB',
                              nativeName: 'United Kingdom'),
                          Country(
                              id: 2,
                              name: 'France',
                              abbreviation: 'FR',
                              nativeName: 'France'),
                        ]),
                      );
                    },
                  ))),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Country'));
    await tester.tap(find.text('Country'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('United Kingdom'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Search countries...'), 'United');
    await tester.pumpAndSettle();
    expect(find.text('France'), findsNothing);
    await tester.tap(find.text('United Kingdom'));
    await tester.pumpAndSettle();
    expect(selected?.name, 'United Kingdom');
    expect(tester.takeException(), isNull);
  });
}
