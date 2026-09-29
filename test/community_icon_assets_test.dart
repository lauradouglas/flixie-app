import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/social/presentation/widgets/community_identity.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'));
    await font.load();
  });
  testWidgets('all custom community SVGs render at mobile and preview sizes',
      (t) async {
    await t.binding.setSurfaceSize(const Size(720, 940));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Manrope')
            .copyWith(
                scaffoldBackgroundColor: const Color(0xff100a22),
                colorScheme:
                    const ColorScheme.dark(secondary: Color(0xff65d6c4))),
        home: Scaffold(
            body: RepaintBoundary(
                child: GridView.count(
          crossAxisCount: 4,
          childAspectRatio: 1,
          children: CommunityIdentity.all.keys
              .map((id) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CommunityIcon(id: id, size: 56),
                      const SizedBox(height: 12),
                      CommunityIcon(id: id),
                      const SizedBox(height: 8),
                      Text(const {
                        -1: 'Anime',
                        28: 'Action',
                        12: 'Adventure',
                        16: 'Animation',
                        35: 'Comedy',
                        80: 'Crime',
                        99: 'Documentary',
                        18: 'Drama',
                        10751: 'Family',
                        14: 'Fantasy',
                        36: 'History',
                        27: 'Horror',
                        10402: 'Music',
                        9648: 'Mystery',
                        10749: 'Romance',
                        878: 'Science Fiction',
                        10770: 'TV Movie',
                        53: 'Thriller',
                        10752: 'War',
                        37: 'Western'
                      }[id]!)
                    ],
                  ))
              .toList(),
        )))));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    if (const bool.fromEnvironment('COMMUNITY_CAPTURE')) {
      final boundary = t.renderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary).first);
      await t.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('/tmp/flixie-custom-icons.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
