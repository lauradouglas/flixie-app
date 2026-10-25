import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'diary_options.dart';
void main() {
 testWidgets('render three fictional diary concepts', (tester) async {
  for (final family in ['Manrope','Roboto','.SF Pro Display']) {
   await (FontLoader(family)..addFont(rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'))).load();
  }
  await (FontLoader('Georgia')..addFont(Future.value(ByteData.sublistView(File('/System/Library/Fonts/Supplemental/Georgia.ttf').readAsBytesSync())))).load();
  await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  for (final movie in movies) {
   final info = await tester.runAsync(() async {final codec = await ui.instantiateImageCodec(await File(movie.$5).readAsBytes()); return ImageInfo(image: (await codec.getNextFrame()).image);});
   PaintingBinding.instance.imageCache.putIfAbsent(FileImage(File(movie.$5)), () => OneFrameImageStreamCompleter(Future.value(info!)));
  }
  tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  for (final viewport in [(name:'phone', size:const Size(390,844), scale:1.0),(name:'small-large-text',size:const Size(360,780),scale:1.5),(name:'tablet',size:const Size(820,1000),scale:1.0)]) {
   tester.view.physicalSize=viewport.size;
   await tester.binding.setSurfaceSize(viewport.size);
   for (final option in ['scrapbook','journal','planner']) {
    final key=GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key:key,child:diaryApp(option,scale:viewport.scale)));
    await tester.pumpAndSettle();
    expect(tester.takeException(),isNull,reason:'${viewport.name} $option');
    final boundary=key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async { final image=await boundary.toImage(pixelRatio:2); final bytes=await image.toByteData(format:ui.ImageByteFormat.png); await File('output/diary-mockups/$option-${viewport.name}.png').writeAsBytes(bytes!.buffer.asUint8List()); image.dispose(); });
    if(viewport.name=='phone') {
     await tester.drag(find.byType(PageView),const Offset(-320,0)); await tester.pumpAndSettle();
     expect(find.textContaining('A fresh page.'),findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox.shrink()); await tester.pumpAndSettle();
   }
  }
 });
}
