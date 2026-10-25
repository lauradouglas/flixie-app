import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/guest/presentation/widgets/cinema_account_sheet.dart';

void main() {
  setUpAll(() async {
    for (final family in ['Manrope', '.SF Pro Display', 'Roboto', 'Ahem']) {
      await (FontLoader(family)..addFont(rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'))).load();
    }
    await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  const fallback = 'Create an account to save your favourites and connect with others.';
  final scenes = [
    ('01-film-bookmark','Keep Alien on your watchlist','Create an account and we’ll save it for your next watch.',true,true),
    ('02-tv-bookmark','Keep Succession on your watchlist','Create an account and we’ll save it for your next watch.',true,true),
    ('03-log-film','Log your movie entry','Create an account to log when you watched this film, add a rating and keep your movie diary.',false,true),
    ('04-rate-tv','Rate this show',fallback,false,true),
    ('05-review','Share your thoughts','Create an account to write your review and discuss it with other film fans.',false,true),
    ('06-favourites','Save your favourites',fallback,false,true),
    ('07-lists','Build your film lists',fallback,false,true),
    ('08-tv-progress','Keep track of what you watch',fallback,false,false),
    ('10-comments','Join the conversation','Create an account to read and write comments, and connect with film people.',false,false),
    ('11-watch-plan','Plan a watch with friends',fallback,false,true),
    ('09-community','Join Horror','Create an account to explore conversations and share your favourites with this community.',false,false),
  ];
  for (final scene in scenes) {
    testWidgets(scene.$1,(tester) async {
      tester.view.physicalSize=const Size(390,700);
      tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key=GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key:key,child:MaterialApp(
        debugShowCheckedModeBanner:false,theme:AppTheme.darkTheme,
        home:Scaffold(backgroundColor:const Color(0xff080810),body:Align(alignment:Alignment.bottomCenter,
          child:CinemaAccountSheet(title:scene.$2,message:scene.$3,signupLabel:scene.$4?'Create account & save':'Create account',showReturnNote:scene.$5,onChoice:(_){}))),
      )));
      await tester.pumpAndSettle();
      // Labels with no explicit family use the platform font in the app.
      // Supply the loaded app font in this off-device rendering harness,
      // rather than Flutter tester's Ahem placeholder glyphs.
      for (final label in ['Already a member? Sign in', 'Keep exploring']) {
        final element = tester.element(find.text(label)) as StatelessElement;
        element.owner!.buildScope(element, () => element.update(Text(label, style: const TextStyle(fontFamily: 'Manrope'))));
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(),isNull);
      await tester.runAsync(() async {
        final image=await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage(pixelRatio:2);
        final data=await image.toByteData(format:ui.ImageByteFormat.png);
        await File('output/signup-sheets/${scene.$1}.png').writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}
