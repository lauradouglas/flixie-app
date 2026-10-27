// Opt-in visual inspection: flutter test tool/render_rating_share_cards_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/sharing/models/rating_card_style.dart';
import 'package:flixie_app/features/sharing/presentation/widgets/rating_share_card.dart';
import 'package:flixie_app/features/sharing/presentation/share_card_sheet.dart';
import '../test/features/sharing/rating_share_card_test.dart' show fixtureData;

void main() {
  setUpAll(() async {
    await (FontLoader('Manrope')
          ..addFont(
              rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
        .load();
    await (FontLoader('Roboto')
          ..addFont(
              rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
        .load();
    await (FontLoader('.SF Pro Display')
          ..addFont(
              rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  testWidgets('render share-card templates and responsive sheet', (t) async {
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    final poster = MemoryImage(
        File('assets/images/why-flixie-alien.jpg').readAsBytesSync());
    final key = GlobalKey();
    Future<void> capture(String name) async {
      // Native image decode/readback runs outside the test's fake clock.
      await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 120)));
      await t.pumpAndSettle();
      expect(find.text('Loading poster…'), findsNothing);
      expect(find.text('Poster unavailable'), findsNothing);
      expect(t.takeException(), isNull);
      await t.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final file = File('output/rating-share-cards/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
      });
    }

    for (final style in RatingCardStyle.values) {
      t.view.physicalSize = const Size(430, 900);
      await t.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
              body: Center(
                  child: RepaintBoundary(
                      key: key,
                      child: CustomPaint(
                          painter: const ShareTransparencyPainter(),
                          child: RatingShareCard(
                              data: fixtureData(),
                              style: style,
                              posterProvider: poster,
                              pip: 'cinemaClub',
                              showNote:
                                  style != RatingCardStyle.fullStory)))))));
      await capture(style.name);
    }
    const user = User(
        id: 'fictional-viewer',
        username: 'Dougasaur',
        email: 'viewer@example.test',
        iconColorId: 0,
        completedSetup: true,
        darkMode: true);
    final interstellar = MemoryImage(
        File('test/features/sharing/fixtures/interstellar.jpg')
            .readAsBytesSync());
    for (final long in [false, true]) {
      for (final style in RatingCardStyle.values) {
        final data = fixtureData(
            title: 'Interstellar',
            rating: 10,
            user: long
                ? const User(
                    id: 'fictional-viewer',
                    username: 'a_very_long_movie_club_username',
                    email: 'viewer@example.test',
                    iconColorId: 0,
                    completedSetup: true,
                    darkMode: true)
                : user,
            note: long
                ? 'An extraordinary evening at the cinema. The performances, the scale and the ending stayed with me for days afterwards, and I would happily watch the entire film again.'
                : 'sob fest');
        await t.pumpWidget(MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
                body: Center(
                    child: RepaintBoundary(
                        key: key,
                        child: CustomPaint(
                            painter: const ShareTransparencyPainter(),
                            child: RatingShareCard(
                                data: data,
                                style: style,
                                posterProvider: interstellar,
                                pip: long ? 'cinemaClub' : null)))))));
        await capture('${long ? 'long-quote' : 'interstellar'}-${style.name}');
      }
    }
    for (final size in [
      const Size(320, 568),
      const Size(430, 932),
      const Size(768, 1024)
    ]) {
      t.view.physicalSize = size;
      await t.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(size.width == 320 ? 2 : 1)),
              child: child!),
          home: RepaintBoundary(
              key: key,
              child: Scaffold(
                  body: ShareCardSheet(
                      data: fixtureData(), posterProvider: poster)))));
      await capture('sheet-${size.width.toInt()}');
      if (size.width == 430) {
        final ticket = find.widgetWithText(ChoiceChip, 'Ticket');
        await t.ensureVisible(ticket);
        await t.tap(ticket);
        await t.pumpAndSettle();
        await capture('sheet-ticket-430');
        final colourTab = find.byKey(const ValueKey('share-tab-1'));
        await t.ensureVisible(colourTab);
        await t.tap(colourTab);
        await t.pumpAndSettle();
        await capture('sheet-colour-430');
      }
    }
  });
}
