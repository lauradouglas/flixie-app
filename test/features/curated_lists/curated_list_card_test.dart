import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/curated_lists/presentation/widgets/curated_list_views.dart';
import 'curated_list_fixtures.dart';
import 'package:flixie_app/features/curated_lists/models/curated_list.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'));
    await font.load();
  });
  for (final width in [320.0, 390.0, 768.0]) {
    for (final scale in [1.0, 1.7]) {
      testWidgets('list card fits $width at text scale $scale', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var opened = 0;
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
                body: MediaQuery(
                    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                    child: Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: CuratedListCard(
                                list: CuratedList(
                                    id: fixtureId,
                                    theme: CuratedListTheme.christmas,
                                    title: 'Did someone say Christmas?',
                                    filmCount: 31,
                                    completionTarget: 5,
                                    rewards: fixtureList().rewards,
                                    films: const [
                                      CuratedFilm(id: 1, title: 'Elf'),
                                      CuratedFilm(id: 2, title: 'Home Alone'),
                                      CuratedFilm(id: 3, title: 'The Holiday'),
                                      CuratedFilm(id: 4, title: 'Klaus'),
                                      CuratedFilm(id: 5, title: 'Bad Santa')
                                    ]),
                                onTap: () => opened++)))))));
        expect(tester.takeException(), isNull);
        expect(find.text('View list'), findsOneWidget);
        if (width == 390 && scale == 1) {
          expect(tester.getSize(find.byType(CuratedListCard)).height,
              lessThanOrEqualTo(400));
        }
        expect(find.text('2 rewards to collect'), findsOneWidget);
        expect(find.byType(CuratedPoster), findsNWidgets(4));
        for (final element in find.byType(CuratedPoster).evaluate()) {
          final size = tester.getSize(find.byWidget(element.widget));
          expect(size.height / size.width, closeTo(1.5, .001));
        }
        expect(find.text('5'), findsOneWidget);
        expect(find.text('Choose from 31 films'), findsOneWidget);
        await tester.tap(find.text('View list'));
        expect(opened, 1);
      });
    }
  }
}
