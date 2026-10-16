import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'log_options.dart';
void main(){
 testWidgets('render logging options and companion selection',(tester)async{
  for(final family in ['Manrope','Roboto','.SF Pro Display']){await(FontLoader(family)..addFont(rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'))).load();}
  await(FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  final info = await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(await File('output/watch-together-mockups/alien.jpg').readAsBytes());
    return ImageInfo(image:(await codec.getNextFrame()).image);
  });
  PaintingBinding.instance.imageCache.putIfAbsent(FileImage(File('output/watch-together-mockups/alien.jpg')), () => OneFrameImageStreamCompleter(Future.value(info!)));
  tester.view.devicePixelRatio=1;addTearDown(tester.view.resetDevicePixelRatio);addTearDown(tester.view.resetPhysicalSize);addTearDown(()=>tester.binding.setSurfaceSize(null));
  for(final viewport in [(name:'phone',size:const Size(390,844),scale:1.0),(name:'small-large-text',size:const Size(360,780),scale:1.4),(name:'tablet',size:const Size(820,1000),scale:1.0)]){
   tester.view.physicalSize=viewport.size;await tester.binding.setSurfaceSize(viewport.size);
   for(final option in ['quick','diary','guided','guided-rating']){
    final key=GlobalKey();await tester.pumpWidget(RepaintBoundary(key:key,child:logOptionApp(option,textScale:viewport.scale)));await tester.pumpAndSettle();
    expect(tester.takeException(),isNull,reason:'${viewport.name} $option');
    if(viewport.name=='phone'){
     final render=key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
     await tester.runAsync(()async{final image=await render.toImage(pixelRatio:2);final bytes=await image.toByteData(format:ui.ImageByteFormat.png);await File('output/watch-together-mockups/option-$option.png').writeAsBytes(bytes!.buffer.asUint8List());image.dispose();});
     if(option=='diary'){
      await tester.drag(find.byType(SingleChildScrollView).first,const Offset(0,-380));await tester.pumpAndSettle();
      await tester.runAsync(()async{final image=await render.toImage(pixelRatio:2);final bytes=await image.toByteData(format:ui.ImageByteFormat.png);await File('output/watch-together-mockups/option-diary-review.png').writeAsBytes(bytes!.buffer.asUint8List());image.dispose();});
     }
     if(option=='quick'){
      await tester.tap(find.text('Change').last);await tester.pumpAndSettle();expect(find.text('Choose a friend'),findsOneWidget);
      await tester.runAsync(()async{final image=await render.toImage(pixelRatio:2);final bytes=await image.toByteData(format:ui.ImageByteFormat.png);await File('output/watch-together-mockups/option-picker.png').writeAsBytes(bytes!.buffer.asUint8List());image.dispose();});
     }
    }
    await tester.pumpWidget(const SizedBox.shrink());await tester.pumpAndSettle();
   }
  }
 });
}
