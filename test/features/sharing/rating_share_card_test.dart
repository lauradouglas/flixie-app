import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flixie_app/features/sharing/presentation/share_card_quote.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/pip/models/pip_collection.dart';
import 'package:flixie_app/features/pip/presentation/controllers/pip_collection_controller.dart';
import 'package:flixie_app/features/sharing/models/rating_card_style.dart';
import 'package:flixie_app/features/sharing/models/share_card_data.dart';
import 'package:flixie_app/features/sharing/presentation/share_card_sheet.dart';
import 'package:flixie_app/features/sharing/services/share_card_export_service.dart';
import 'package:flixie_app/features/sharing/presentation/widgets/rating_share_card.dart';
import 'package:flixie_app/features/sharing/presentation/widgets/blended_share_poster.dart';
import 'package:flixie_app/models/user.dart';
import 'fixture.dart';

const fixtureUser = User(
    id: 'fixture-viewer',
    username: 'casey',
    email: 'casey@example.test',
    iconColorId: 0,
    completedSetup: true,
    darkMode: true);
ShareCardData fixtureData(
        {String title = 'Alien',
        String? note = 'Still the perfect nightmare.',
        bool? recommended = true,
        bool neutral = false,
        User user = fixtureUser,
        int rating = 9}) =>
    ShareCardData.rating(
        mediaType: ShareCardMediaType.movie,
        mediaId: 348,
        title: title,
        posterPath: null,
        user: user,
        rating: rating,
        recommended: recommended,
        neutralRecommendation: neutral,
        note: note);

class OwnedPips extends PipCollectionController {
  OwnedPips() {
    collection = const PipCollection(cinemaUnlocked: true);
    verified = true;
  }
  @override
  String? get userId => 'fixture-viewer';
}

class RecordingExport extends ShareCardExportService {
  int renders = 0;
  final saves = <Uint8List>[];
  @override
  Future<Uint8List> renderPng(GlobalKey boundaryKey) async =>
      Uint8List.fromList([++renders]);
  @override
  Future<void> save(
      {required Uint8List bytes, required ShareCardData data}) async {
    saves.add(bytes);
  }
}

void main() {
  setUpAll(() async {
    await (FontLoader('Manrope')
          ..addFont(
              rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
        .load();
  });
  testWidgets('ticket colours retain a separate QR stub', (t) async {
    for (final style in [
      RatingCardStyle.cinemaTicket,
      RatingCardStyle.pocketTicket
    ]) {
      for (final background in RatingCardBackground.values) {
        await t.pumpWidget(MaterialApp(
            home: Scaffold(
                body: Center(
                    child: RatingShareCard(
                        data: fixtureData(),
                        style: style,
                        background: background)))));
        await t.pumpAndSettle();
        final surface =
            t.widget<Container>(find.byKey(const ValueKey('ticket-surface')));
        expect(
            surface.color,
            switch (background) {
              RatingCardBackground.transparent => Colors.transparent,
              RatingCardBackground.bone => const Color(0xFFEEE6D8),
              RatingCardBackground.dark => const Color(0xFF15121C),
              RatingCardBackground.lilac => const Color(0xFFCFC0E8),
            });
        expect(find.text('ADMISSION 1'), findsOneWidget);
        expect(find.text('flixie.co.uk'), findsOneWidget);
        final qr = find.byKey(const ValueKey('ticket-flixie-qr'));
        expect(qr, findsOneWidget);
        expect(
            t.getRect(qr).top,
            greaterThan(t
                .getRect(find.byKey(const ValueKey('share-card-attribution')))
                .bottom));
        expect(t.takeException(), isNull);
      }
    }
  });

  testWidgets(
      'all templates retain attribution, note privacy and intact poster geometry',
      (t) async {
    t.view.physicalSize = const Size(430, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final poster = MemoryImage(
        File('assets/images/why-flixie-alien.jpg').readAsBytesSync());
    for (final style in RatingCardStyle.values) {
      for (final showNote in [true, false]) {
        await t.pumpWidget(MaterialApp(
            home: Scaffold(
                body: Center(
                    child: RatingShareCard(
                        data: fixtureData(
                            title:
                                'The Lord of the Rings: The Return of the King'),
                        style: style,
                        showNote: showNote,
                        posterProvider: poster,
                        pip: 'classic')))));
        await t.pumpAndSettle();
        expect(find.textContaining('@casey'), findsWidgets);
        expect(find.text('9'), findsOneWidget);
        expect(find.text('9.0'), findsNothing);
        expect(find.text('Still the perfect nightmare.'),
            showNote ? findsOneWidget : findsNothing);
        expect(find.text('The Lord of the Rings: The Return of the King'),
            findsOneWidget);
        if (style == RatingCardStyle.cinemaTicket)
          expect(find.text('ADMISSION 1'), findsOneWidget);
        if (style == RatingCardStyle.posterSticker) {
          final pip = find.byKey(const ValueKey('sticker-top-pip'));
          final title = find.byKey(const ValueKey('share-card-title'));
          expect(t.getRect(pip).bottom, lessThan(t.getRect(title).top));
        }
        if (style == RatingCardStyle.fullStory) {
          final pip = find.byKey(const ValueKey('full-story-pip'));
          final attribution = find.byKey(const ValueKey('share-card-attribution'));
          expect(t.getRect(pip).left, greaterThan(t.getRect(attribution).right));
          expect(t.getCenter(pip).dy, closeTo(t.getCenter(attribution).dy, 1));
        }
        if (style == RatingCardStyle.polaroid) {
          final pip = find.byKey(const ValueKey('polaroid-pip'));
          final attribution =
              find.byKey(const ValueKey('share-card-attribution'));
          expect(
              t.getRect(pip).left, greaterThan(t.getRect(attribution).right));
          expect((t.getCenter(pip).dy - t.getCenter(attribution).dy).abs(),
              lessThan(20));
        }
        expect(t.takeException(), isNull,
            reason: '${style.label}, note=$showNote');
      }
    }
  });

  testWidgets(
      'circle colour fills the shape while exported margins always stay transparent',
      (t) async {
    final key = GlobalKey();
    for (final background in RatingCardBackground.values) {
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Center(
                  child: RepaintBoundary(
                      key: key,
                      child: RatingShareCard(
                          data: fixtureData(note: null),
                          style: RatingCardStyle.circleStamp,
                          background: background))))));
      await t.pumpAndSettle();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final bytes = await t.runAsync(() async {
        final image = await boundary.toImage();
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final codec = await ui.instantiateImageCodec(png!.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        final rgba =
            await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
        frame.image.dispose();
        codec.dispose();
        return rgba;
      });
      expect(bytes!.getUint8(3), 0);
      final circle = t.widgetList<Container>(find.byType(Container)).firstWhere(
          (c) =>
              c.constraints?.maxWidth == 312 &&
              c.constraints?.maxHeight == 312);
      final outline = circle.foregroundDecoration as BoxDecoration?;
      expect(outline != null, background == RatingCardBackground.transparent);
      if (outline != null) {
        expect(outline.shape, BoxShape.circle);
        expect(outline.border, isNotNull);
      }
      // Blank point inside the left edge of the circle, away from text/art.
      final offset = (320 * 360 + 40) * 4;
      expect(bytes.getUint8(offset + 3),
          background == RatingCardBackground.transparent ? 0 : 255);
      if (background == RatingCardBackground.bone) {
        expect([
          bytes.getUint8(offset),
          bytes.getUint8(offset + 1),
          bytes.getUint8(offset + 2)
        ], [
          238,
          230,
          216
        ]);
      }
      final title = t.widget<Text>(find.text('Alien'));
      expect(
          title.style!.color,
          background == RatingCardBackground.bone ||
                  background == RatingCardBackground.lilac
              ? const Color(0xFF15121C)
              : Colors.white);
    }
  });

  testWidgets(
      'sheet choices change the exported rating card and honour Pip ownership',
      (t) async {
    t.view.physicalSize = const Size(430, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final auth = ShareAuth();
    final pips = OwnedPips();
    addTearDown(auth.dispose);
    addTearDown(pips.dispose);
    await t.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<PipCollectionController>.value(value: pips),
        ],
        child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(body: ShareCardSheet(data: fixtureData())))));
    await t.pumpAndSettle();
    expect(t.widget<RatingShareCard>(find.byType(RatingShareCard)).background,
        RatingCardBackground.bone);
    Future<void> choose(String text) async {
      final tab = RatingCardBackground.values.any((b) => b.label == text)
          ? 1
          : ['None', 'Classic', 'Cinema Club'].contains(text)
              ? 2
              : 0;
      await openEditorTab(t, tab);
      final chip = tab == 2 ? find.byKey(ValueKey('pip-option-$text')) : find.widgetWithText(ChoiceChip, text);
      await t.ensureVisible(chip);
      await t.tap(chip);
      await t.pumpAndSettle();
    }

    await choose('Circle stamp');
    final zoom = t.widget<Transform>(
        find.byKey(const ValueKey('share-preview-zoom')));
    expect(zoom.transform.storage[0], 1.45);
    expect(t.getSize(find.byType(RatingShareCard)), const Size(360, 640));
    await choose('Full Story');
    expect(t.widget<Transform>(find.byKey(const ValueKey('share-preview-zoom')))
        .transform.storage[0], 1);
    for (final background in RatingCardBackground.values) {
      await choose(background.label);
      final card = t.widget<RatingShareCard>(find.byType(RatingShareCard));
      expect(card.background, background);
      final surface = t
          .widget<Container>(find.byKey(const ValueKey('rating-card-surface')));
      expect(
          surface.color,
          switch (background) {
            RatingCardBackground.transparent => Colors.transparent,
            RatingCardBackground.dark => const Color(0xFF15121C),
            RatingCardBackground.lilac => const Color(0xFFCFC0E8),
            RatingCardBackground.bone => const Color(0xFFEEE6D8),
          });
      final title = t.widget<Text>(find.text('Alien'));
      expect(
          title.style!.color,
          background == RatingCardBackground.bone ||
                  background == RatingCardBackground.lilac
              ? const Color(0xFF15121C)
              : Colors.white);
    }
    expect(find.widgetWithText(ChoiceChip, 'Compact poster'), findsNothing);
    await choose('Ticket');
    expect(find.text('Ticket type'), findsOneWidget);
    await choose('Pocket ticket');
    expect(t.widget<RatingShareCard>(find.byType(RatingShareCard)).style,
        RatingCardStyle.pocketTicket);
    await choose('Polaroid');
    expect(find.text('Ticket type'), findsNothing);
    await choose('Ticket');
    expect(t.widget<RatingShareCard>(find.byType(RatingShareCard)).style,
        RatingCardStyle.pocketTicket);
    await choose('Compact poster');
    expect(find.text('ADMISSION 1'), findsOneWidget);
    await choose('Lilac');
    await choose('Cinema Club');
    var card = t.widget<RatingShareCard>(find.byType(RatingShareCard));
    expect(card.style, RatingCardStyle.cinemaTicket);
    expect(card.background, RatingCardBackground.lilac);
    expect(card.pip, 'cinemaClub');
    expect(pips.collection.activePip, 'classic',
        reason: 'Share decoration must not change account Pip');
    await openEditorTab(t, 3);
    final toggle = find.byType(SwitchListTile);
    await t.ensureVisible(toggle);
    await t.tap(toggle);
    await t.pumpAndSettle();
    expect(find.text('Still the perfect nightmare.'), findsNothing);
    pips.verified = false;
    pips.notifyListeners();
    await t.pumpAndSettle();
    card = t.widget<RatingShareCard>(find.byType(RatingShareCard));
    expect(card.pip, isNull);
    expect(find.byKey(const ValueKey('pip-option-Cinema Club')), findsNothing);
    await choose('None');
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'sheet reflows on small phones, landscape, tablets and large text',
      (t) async {
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    for (final size in [
      const Size(320, 568),
      const Size(844, 390),
      const Size(768, 1024)
    ]) {
      t.view.physicalSize = size;
      await t.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!),
          home: Scaffold(body: ShareCardSheet(data: fixtureData()))));
      await t.pumpAndSettle();
      expect(find.text('Share…'), findsOneWidget);
      final actions = find.byKey(const ValueKey('share-editor-actions'));
      final before = t.getRect(actions);
      expect(before.bottom, lessThanOrEqualTo(size.height));
      expect(before.bottom, greaterThan(size.height - 24));
      await openEditorTab(t, 2);
      expect(t.getRect(actions), before);

      expect(t.takeException(), isNull, reason: '$size at 200%');
      await t.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets(
      'saving reuses only unchanged images and re-renders after customisation',
      (t) async {
    final export = RecordingExport();
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
            body: ShareCardSheet(data: fixtureData(), exportService: export))));
    await t.pumpAndSettle();
    Future<void> save() async {
      final action = find.widgetWithText(OutlinedButton, 'Save');
      await t.ensureVisible(action);
      await t.tap(action);
      await t.pumpAndSettle();
    }

    await save();
    await save();
    expect(export.renders, 1);
    final chip = find.widgetWithText(ChoiceChip, 'Circle stamp');
    await t.ensureVisible(chip);
    await t.tap(chip);
    await t.pumpAndSettle();
    await save();
    expect(export.renders, 2);
    await openEditorTab(t, 3);
    final toggle = find.byType(SwitchListTile);
    await t.ensureVisible(toggle);
    await t.tap(toggle);
    await t.pumpAndSettle();
    await save();
    expect(export.renders, 3);
    expect(export.saves.map((bytes) => bytes.single), [1, 1, 2, 3]);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'background extension preserves the poster subject proportions in a wide area',
      (t) async {
    final poster = await t.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(Colors.black, BlendMode.src);
      canvas.drawRect(const Rect.fromLTWH(40, 55, 20, 40),
          Paint()..color = const Color(0xFFFF0000));
      final picture = recorder.endRecording();
      final image = await picture.toImage(100, 150);
      picture.dispose();
      return image;
    });
    final key = GlobalKey();
    await t.pumpWidget(MaterialApp(
        home: Center(
            child: RepaintBoundary(
                key: key,
                child: SizedBox(
                    width: 200,
                    height: 150,
                    child: ColoredBox(
                        color: Colors.black,
                        child: BlendedSharePoster(image: poster)))))));
    await t.pumpAndSettle();
    final rgba = await t.runAsync(() async {
      final image = await (key.currentContext!.findRenderObject()!
              as RenderRepaintBoundary)
          .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return bytes!;
    });
    final xs = <int>[], ys = <int>[];
    for (var y = 0; y < 150; y++) {
      for (var x = 0; x < 200; x++) {
        final i = (y * 200 + x) * 4;
        if (rgba!.getUint8(i) > 240 && rgba.getUint8(i + 1) < 10) {
          xs.add(x);
          ys.add(y);
        }
      }
    }
    xs.sort();
    ys.sort();
    expect(xs.last - xs.first + 1, 20);
    expect(ys.last - ys.first + 1, 40);
    await t.pumpWidget(const SizedBox.shrink());
    poster!.dispose();
  });

  testWidgets('failed poster offers retry and permits explicit fallback export',
      (t) async {
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ShareCardSheet(
                data: fixtureData(),
                posterProvider:
                    MemoryImage(Uint8List.fromList([0, 1, 2, 3]))))));
    expect(
        t
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Share…'))
            .onPressed,
        isNull);
    await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await t.pumpAndSettle();
    expect(find.text('Retry poster'), findsOneWidget);
    expect(
        t
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Share…'))
            .onPressed,
        isNotNull);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'poster colours stay in the artwork while the card keeps readable Flixie chrome',
      (t) async {
    const background = Color(0xFF999999);
    final png = await t.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(background, BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(100, 150);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      return bytes!.buffer.asUint8List();
    });
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RatingShareCard(
                data: fixtureData(),
                background: RatingCardBackground.dark,
                posterProvider: MemoryImage(png!)))));
    await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await t.pumpAndSettle();
    final surface =
        t.widget<Container>(find.byKey(const ValueKey('rating-card-surface')));
    expect(surface.color, const Color(0xFF15121C));
    for (final label in ['Alien', '@casey', 'Still the perfect nightmare.']) {
      for (final text in t.widgetList<Text>(find.text(label))) {
        final foreground = text.style!.color!;
        final a = foreground.computeLuminance(),
            b = surface.color!.computeLuminance();
        final contrast = a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
        expect(contrast, greaterThanOrEqualTo(4.5), reason: label);
      }
    }
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'Interstellar never breaks mid-word and circle attribution stays inside its curve',
      (t) async {
    t.view.physicalSize = const Size(430, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    const user = User(
        id: 'fictional-viewer',
        username: 'Dougasaur',
        email: 'viewer@example.test',
        iconColorId: 0,
        completedSetup: true,
        darkMode: true);
    final poster = MemoryImage(
        File('test/features/sharing/fixtures/interstellar.jpg')
            .readAsBytesSync());
    for (final style in RatingCardStyle.values) {
      for (final pip in [null, 'cinemaClub']) {
        await t.pumpWidget(MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
                body: Center(
                    child: RatingShareCard(
                        data: fixtureData(
                            title: 'Interstellar',
                            user: user,
                            rating: 10,
                            note: 'sob fest'),
                        style: style,
                        pip: pip,
                        posterProvider: poster)))));
        await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 40)));
        await t.pumpAndSettle();
        final paragraph = t.renderObject<RenderParagraph>(
            find.byKey(const ValueKey('share-card-title')));
        expect(
            paragraph.getBoxesForSelection(
                const TextSelection(baseOffset: 0, extentOffset: 12)),
            hasLength(1),
            reason: '${style.label}, pip=$pip');
        if (style == RatingCardStyle.circleStamp) {
          final circle = t.renderObject<RenderBox>(find.byType(ClipOval));
          final radius = circle.size.width / 2;
          final texts = find.descendant(
              of: find.byType(ClipOval), matching: find.byType(RichText));
          for (final element in texts.evaluate()) {
            final render = element.renderObject! as RenderParagraph;
            final length = render.text.toPlainText().length;
            for (final box in render.getBoxesForSelection(
                TextSelection(baseOffset: 0, extentOffset: length))) {
              for (final point in [
                box.toRect().topLeft,
                box.toRect().topRight,
                box.toRect().bottomLeft,
                box.toRect().bottomRight
              ]) {
                final local = circle.globalToLocal(render.localToGlobal(point));
                expect((local - Offset(radius, radius)).distance,
                    lessThanOrEqualTo(radius + .1),
                    reason:
                        '${render.text.toPlainText()} inside circle, pip=$pip');
              }
            }
          }
        }
        expect(t.takeException(), isNull);
      }
    }
  });

  testWidgets(
      'long titles wrap at words and longer circle quotes reflow below the circle',
      (t) async {
    t.view.physicalSize = const Size(430, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    const title = 'The Lord of the Rings: The Return of the King';
    const note =
        'An extraordinary evening at the cinema. The performances, the scale and the ending stayed with me for days afterwards, and I would happily watch the entire film again.';
    const user = User(
        id: 'fictional-viewer',
        username: 'a_very_long_movie_club_username',
        email: 'viewer@example.test',
        iconColorId: 0,
        completedSetup: true,
        darkMode: true);
    for (final style in RatingCardStyle.values) {
      await t.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
              body: Center(
                  child: RatingShareCard(
                      data: fixtureData(
                          title: title, note: note, user: user, rating: 10),
                      style: style,
                      pip: 'classic')))));
      await t.pumpAndSettle();
      final titleFinder = find.byKey(const ValueKey('share-card-title'));
      final paragraph = t.renderObject<RenderParagraph>(titleFinder);
      var offset = 0;
      for (final word in title.split(' ')) {
        expect(
            paragraph.getBoxesForSelection(TextSelection(
                baseOffset: offset, extentOffset: offset + word.length)),
            hasLength(1),
            reason: '$word in ${style.label}');
        offset += word.length + 1;
      }
      expect(t.widget<Text>(titleFinder).style!.fontSize,
          greaterThanOrEqualTo(16));
      expect(find.text(note), findsOneWidget);
      if (style == RatingCardStyle.circleStamp) {
        expect(
            find.ancestor(of: find.text(note), matching: find.byType(ClipOval)),
            findsNothing);
      }
      expect(t.takeException(), isNull, reason: style.label);
    }
  });

  testWidgets(
      'long diary notes use an explicit editable excerpt without changing the original',
      (t) async {
    final data = fixtureData(
        note: List.filled(30, 'A thoughtful film with a memorable ending.')
            .join(' '));
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: ShareCardSheet(data: data))));
    await t.pumpAndSettle();
    await openEditorTab(t, 3);
    final field = find.byType(TextField);
    await t.ensureVisible(field);
    await t.pumpAndSettle();
    expect(
        find.text(
            'An excerpt of your longer note. Edit this quote; your diary note stays unchanged.'),
        findsOneWidget);
    expect(t.widget<TextField>(field).controller!.text.characters.length,
        lessThanOrEqualTo(shareCardQuoteLimit));
    await t.enterText(field, 'The ending stayed with me.');
    await t.pumpAndSettle();
    expect(t.widget<RatingShareCard>(find.byType(RatingShareCard)).quote,
        'The ending stayed with me.');
    expect(
        data.note,
        contains(
            'A thoughtful film with a memorable ending. A thoughtful film'));
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'the full-screen editor keeps the quote editor above the keyboard',
      (t) async {
    t.view.physicalSize = const Size(430, 932);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetViewInsets);
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => showShareCardSheet(context, fixtureData()),
                    child: const Text('Open rating share'))))));
    await t.tap(find.text('Open rating share'));
    await t.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(t.getSize(find.byType(ShareCardSheet)), const Size(430, 932));
    t.view.viewInsets = const FakeViewPadding(bottom: 320);
    await t.pumpAndSettle();
    await openEditorTab(t, 3);
    final field = find.byType(TextField);
    await t.ensureVisible(field);
    await t.pumpAndSettle();
    expect(t.getRect(field).bottom, lessThanOrEqualTo(932 - 320));
    expect(t.takeException(), isNull);
  });

  testWidgets('neutral and negative verdicts never become recommendations',
      (t) async {
    for (final neutral in [false, true]) {
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: RatingShareCard(
                  data: fixtureData(recommended: false, neutral: neutral)))));
      expect(
          find.text(
              neutral ? 'has no recommendation' : "doesn't recommend this"),
          findsOneWidget);
      expect(find.text('@casey'), findsNWidgets(2));
    }
  });
}

Future<void> openEditorTab(WidgetTester t, int index) async {
  final tab = find.byKey(ValueKey('share-tab-$index'));
  await t.ensureVisible(tab);
  await t.tap(tab);
  await t.pumpAndSettle();
}
