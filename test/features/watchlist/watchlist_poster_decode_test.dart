import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/storage/library_image_warmup.dart';
import 'package:flixie_app/features/watchlist/presentation/widgets/watchlist_movie_row.dart';
import 'package:flixie_app/models/watchlist_movie.dart';

void main() {
  test('decode target follows pixel density and does not exceed the source',
      () {
    expect(watchlistPosterDecodeWidth(1), 68);
    expect(watchlistPosterDecodeWidth(2), 136);
    expect(watchlistPosterDecodeWidth(3), 204);
    expect(watchlistPosterDecodeWidth(2.625), 179);
    expect(watchlistPosterDecodeWidth(6), 342);
  });
  testWidgets('row and Home library warmup resolve the same resized image key',
      (tester) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var opened = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: WatchlistMovieRow(
      watchlistItem: const WatchlistMovie(
          id: 'fixture',
          userId: 'fixture',
          movieId: 348,
          movie: WatchlistMovieDetails(
              id: 348, title: 'Alien', posterPath: '/alien.jpg')),
      isWatched: false,
      onTap: () => opened = true,
      onMarkAsWatched: () {},
      onRemove: () {},
    ))));
    final image = tester
        .widget<CachedNetworkImage>(find.byType(CachedNetworkImage).first);
    expect(image.memCacheWidth, 204);
    expect(image.memCacheHeight, isNull);
    expect(image.imageUrl, 'https://image.tmdb.org/t/p/w342/alien.jpg');
    final rowProvider = ResizeImage.resizeIfNeeded(image.memCacheWidth,
        image.memCacheHeight, CachedNetworkImageProvider(image.imageUrl));
    final warmed = libraryPosterWarmupProvider(image.imageUrl, 3);
    expect(await warmed.obtainKey(ImageConfiguration.empty),
        await rowProvider.obtainKey(ImageConfiguration.empty));
    await tester.tap(find.text('Alien'));
    expect(opened, true);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'decoder keeps poster aspect ratio at physical display resolution',
      (tester) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
          const Rect.fromLTWH(0, 0, 342, 513), Paint()..color = Colors.purple);
      final picture = recorder.endRecording();
      final source = await picture.toImage(342, 513);
      final png = await source.toByteData(format: ui.ImageByteFormat.png);
      final buffer =
          await ui.ImmutableBuffer.fromUint8List(png!.buffer.asUint8List());
      final codec = await PaintingBinding.instance
          .instantiateImageCodecWithSize(buffer,
              getTargetSize: (width, height) =>
                  ui.TargetImageSize(width: watchlistPosterDecodeWidth(3)));
      final decoded = await codec.getNextFrame();
      expect(decoded.image.width, 204);
      expect(decoded.image.height, 306);
      expect(decoded.image.width * decoded.image.height * 4, 249696);
      decoded.image.dispose();
      codec.dispose();
      source.dispose();
      picture.dispose();
    });
  });
}
