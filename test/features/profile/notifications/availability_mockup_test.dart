// Deterministic Flutter-rendered mockup, separate from native device verification.
// WRITE_AVAILABILITY_MOCKUPS=1 flutter test --update-goldens test/features/profile/notifications/availability_mockup_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../tool/preview_availability_alerts.dart';

void main() {
  testWidgets('render fictional availability inbox and push preview', (tester) async {
    await (FontLoader('Manrope')..addFont(rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'))).load();
    await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for(final family in ['Roboto','.SF Pro Display']) {
      await (FontLoader(family)..addFont(rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'))).load();
    }
    final write=Platform.environment['WRITE_AVAILABILITY_MOCKUPS']=='1';
    if(write) {
      for(final item in [
        ('/vfrQk5IPloGg1v9Rzbh2Eg3VGyM.jpg','/tmp/flixie-availability-alien.jpg'),
        ('/2s6IPLtfw0GiMxlJznb1TkA6KXk.jpg','/tmp/flixie-availability-newsroom.jpg')]) {
        final info=await tester.runAsync(()async {
          final codec=await ui.instantiateImageCodec(await File(item.$2).readAsBytes());
          return ImageInfo(image:(await codec.getNextFrame()).image);
        });
        PaintingBinding.instance.imageCache.putIfAbsent(CachedNetworkImageProvider('https://image.tmdb.org/t/p/w185${item.$1}'),
          ()=>OneFrameImageStreamCompleter(Future.value(info!)));
      }
    }
    addTearDown(()=>tester.binding.setSurfaceSize(null));
    for(final viewport in [(name:'phone-widget',size:const Size(390,844)),(name:'tablet-widget',size:const Size(1100,820))]) {
      await tester.binding.setSurfaceSize(viewport.size);
      final boundary=GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key:boundary,child:availabilityPreview()));
      await tester.runAsync(() => precacheImage(const AssetImage('assets/icon/flixie_icon_1024.png'), boundary.currentContext!));
      await tester.pumpAndSettle();
      expect(tester.takeException(),isNull);
      expect(find.text('Alien'),findsOneWidget);
      if(write) {
        final render=boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image=await render.toImage(pixelRatio:2);
          final bytes=await image.toByteData(format:ui.ImageByteFormat.png);
          await File('${Directory.current.path}/design/availability-alerts/review/${viewport.name}.png').writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
  });
}
