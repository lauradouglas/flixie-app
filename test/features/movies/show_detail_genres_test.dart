import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/movies/presentation/widgets/genre_chip.dart';
import 'package:flixie_app/features/movies/presentation/widgets/show_detail_hero.dart';
import 'package:flixie_app/models/show.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 390.0, 844.0, 1024.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('show genres wrap at width $width and text scale $scale',
          (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1100));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final show = TvShow.fromJson({
          'id': 101,
          'name': 'Alien: Earth',
          'genres': [
            {'id': 18, 'name': 'Drama'},
            {'id': 9648, 'name': 'Mystery'},
            {'id': 10765, 'name': 'Sci-Fi & Fantasy'},
          ],
        });
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
              body: CustomScrollView(slivers: [ShowDetailHero(show: show)])),
        ));
        await tester.pumpAndSettle();
        expect(find.byType(GenreChip), findsNWidgets(3));
        expect(find.text('DRAMA'), findsOneWidget);
        expect(find.text('MYSTERY'), findsOneWidget);
        expect(find.text('SCI-FI & FANTASY'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('show with no genres omits genre chips', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CustomScrollView(slivers: [
      ShowDetailHero(
          show: TvShow.fromJson({'id': 101, 'name': 'Fixture show'})),
    ]))));
    expect(find.byType(GenreChip), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
