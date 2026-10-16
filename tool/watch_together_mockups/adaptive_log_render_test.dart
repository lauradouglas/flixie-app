import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'adaptive_log.dart';
void main(){testWidgets('render responsive watch log concepts',(tester)async{
 for(final family in ['Manrope','Roboto','.SF Pro Display']){await(FontLoader(family)..addFont(rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'))).load();}
 await(FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
 final info=await tester.runAsync(()async{final codec=await ui.instantiateImageCodec(await File('output/watch-together-mockups/alien.jpg').readAsBytes());return ImageInfo(image:(await codec.getNextFrame()).image);});
 PaintingBinding.instance.imageCache.putIfAbsent(FileImage(File('output/watch-together-mockups/alien.jpg')),()=>OneFrameImageStreamCompleter(Future.value(info!)));
 tester.view.devicePixelRatio=1;addTearDown(tester.view.resetDevicePixelRatio);addTearDown(tester.view.resetPhysicalSize);addTearDown(()=>tester.binding.setSurfaceSize(null));
 for(final v in [
 (name:'short',size:const Size(375,667),scale:1.0,keyboard:0.0,omit:false),
 (name:'standard',size:const Size(390,844),scale:1.0,keyboard:0.0,omit:false),
 (name:'large',size:const Size(430,932),scale:1.0,keyboard:0.0,omit:false),
 (name:'large-title-only',size:const Size(430,932),scale:1.0,keyboard:0.0,omit:true),
 (name:'tablet',size:const Size(820,1180),scale:1.0,keyboard:0.0,omit:false),
 (name:'tablet-landscape',size:const Size(1180,820),scale:1.0,keyboard:0.0,omit:false),
 (name:'tablet-split',size:const Size(600,900),scale:1.0,keyboard:0.0,omit:false),
 (name:'large-text',size:const Size(390,844),scale:1.5,keyboard:0.0,omit:false),
 (name:'landscape',size:const Size(844,390),scale:1.0,keyboard:0.0,omit:false),
 (name:'keyboard',size:const Size(390,844),scale:1.0,keyboard:300.0,omit:false),
 ]){
  tester.view.physicalSize=v.size;await tester.binding.setSurfaceSize(v.size);
  final key=GlobalKey();await tester.pumpWidget(RepaintBoundary(key:key,child:adaptiveLogPreview(omitPoster:v.omit,scale:v.scale,keyboard:v.keyboard)));await tester.pumpAndSettle();
  expect(tester.takeException(),isNull,reason:v.name);
  if(v.name=='large')expect(find.byType(Image),findsOneWidget);
  if(['short','standard','large-title-only','large-text','keyboard','landscape'].contains(v.name))expect(find.byType(Image),findsNothing);
  final button=tester.getRect(find.widgetWithText(FilledButton,'Save watch'));
  expect(button.bottom,lessThanOrEqualTo(v.size.height-v.keyboard),reason:'Save stays above keyboard on ${v.name}');
  final render=key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(()async{final img=await render.toImage(pixelRatio:2);final bytes=await img.toByteData(format:ui.ImageByteFormat.png);await File('output/watch-together-mockups/adaptive-${v.name}.png').writeAsBytes(bytes!.buffer.asUint8List());img.dispose();});
  await tester.pumpWidget(const SizedBox.shrink());await tester.pumpAndSettle();
 }
});}
