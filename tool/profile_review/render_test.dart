import 'dart:io';
import 'package:flutter/services.dart';
import '../../test/features/profile/diary/diary_test.dart' show watch;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import '../../test/features/profile/profile_screen_test.dart';
import '../../test/features/profile/featured_people_test.dart'
    show favouritePeopleFixture;
import 'package:flixie_app/models/favorite_movie.dart';

void main() {
  setUpAll(() async {
    for (final family in ['Manrope', 'Roboto', '.SF Pro Display']) {
      await (FontLoader(family)..addFont(rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'))).load();
    }
    await (FontLoader('Georgia')..addFont(Future.value(ByteData.sublistView(File('/System/Library/Fonts/Supplemental/Georgia.ttf').readAsBytesSync())))).load();
    await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  testWidgets('render approved profile composition at phone and tablet widths',
      (tester) async {
    for (final size in [const Size(390, 844), const Size(1194, 834)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final f = ProfileScreenFixture(diaryWatches: [watch('local-watch', DateTime.now().toIso8601String(), cinema: true).toJson()]);
      f.auth.account = f.auth.account!.copyWith(
          firstName: 'Casey',
          username: 'casey',
          bio: 'Films that stay with me.',
          profileBadges: ['FOUNDER', 'EARLY_ADOPTER'],
          favoritePeople: favouritePeopleFixture,
          featuredPeople: {'director': 525, 'actor': 500, 'actress': 10205},
          favoriteMovies: [
            for (final (id, title) in [
              (348, 'Alien'),
              (1368337, 'The Odyssey'),
              (634649, 'Spider-Man: No Way Home')
            ])
              FavoriteMovie(
                  id: 'f-$id',
                  userId: 'viewer',
                  movieId: id,
                  movie: {'title': title})
          ],
          favoriteShows: [
            {
              'show': {'id': 1, 'title': 'Severance'}
            }
          ]);
      final key = GlobalKey();
      await http.runWithClient(() async {
        await tester.pumpWidget(RepaintBoundary(key: key, child: f.app(1)));
        await tester.pumpAndSettle();
        for (final tab in ['Taste', 'Diary']) {
          if (tab == 'Diary') await openProfileTab(tester, tab);
          await tester.pumpAndSettle();
          final boundary =
              key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            await File(
                    'output/profile-review/${size.width.toInt()}-${tab.toLowerCase()}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => f.client);
      f.dispose();
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
