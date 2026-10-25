// Exact current production watch-entry widget versus isolated cinema addition.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_wordmark.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import 'package:flixie_app/models/friendship.dart';
import 'current_watch_entry_mockup.dart';
void main(){
 testWidgets('current watch entry with only a compact cinema checkbox', (tester) async {
  for(final family in ['Manrope','Roboto','.SF Pro Display']){await (FontLoader(family)..addFont(rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'))).load();}
  await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetDevicePixelRatio);addTearDown(tester.view.resetPhysicalSize);addTearDown(()=>tester.binding.setSurfaceSize(null));
  final sophie=FriendshipUser.fromJson({'id':'fixture-sophie','username':'sophie','firstName':'Sophie','profileBadges':['EARLY_ADOPTER']});
  for(final view in [(name:'phone',size:const Size(390,844),scale:1.0),(name:'small-large-text',size:const Size(360,780),scale:1.5),(name:'tablet',size:const Size(820,1000),scale:1.0)]){
   tester.view.physicalSize=view.size;await tester.binding.setSurfaceSize(view.size);
   for(final modified in [false,true]){
    final key=GlobalKey();
    Future<void> submit({required String? watchedAt,required double? rating,required bool? recommended,required String? notes})async{}
    final sheet=modified?CinemaWatchLogMockup(movieTitle:'Alien',movieYear:'1979',initialWatchedAt:'2026-10-12T18:00:00Z',companion:sophie,showReviewOption:true,loadFriends:()async=>[],onSubmit:submit):RewatchLogSheet(movieTitle:'Alien',movieYear:'1979',initialWatchedAt:'2026-10-12T18:00:00Z',companion:sophie,showReviewOption:true,loadFriends:()async=>[],onSubmit:submit);
    final content = Scaffold(
      body: SafeArea(
        child: Column(children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20,16,20,16),
            child: Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[
              FlixieWordmark(fontSize:26), Text('Design preview',style:TextStyle(fontSize:12)),
            ]),
          ),
          Expanded(child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth:view.name=='tablet'?560:double.infinity),
              child: sheet,
            ),
          )),
        ]),
      ),
    );
    await tester.pumpWidget(RepaintBoundary(
      key:key,
      child:MaterialApp(
        debugShowCheckedModeBanner:false,
        theme:AppTheme.darkTheme,
        builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:TextScaler.linear(view.scale)),child:child!),
        home:content,
      ),
    ));
    await tester.pumpAndSettle();expect(tester.takeException(),isNull,reason:'${view.name} $modified');
    Future<void> capture(String filename)async{final boundary=key.currentContext!.findRenderObject()! as RenderRepaintBoundary;await tester.runAsync(()async{final image=await boundary.toImage(pixelRatio:2);final bytes=await image.toByteData(format:ui.ImageByteFormat.png);await File('output/diary-mockups/$filename-${view.name}.png').writeAsBytes(bytes!.buffer.asUint8List());image.dispose();});}
    await capture(modified?'actual-watch-entry-inline':'actual-watch-entry-before');
    if(modified){
     final checkbox=find.byKey(const ValueKey('cinema-checkbox'));
     await tester.ensureVisible(checkbox);expect(tester.widget<CheckboxListTile>(checkbox).value,isFalse);
     await tester.tap(checkbox);await tester.pumpAndSettle();expect(tester.widget<CheckboxListTile>(checkbox).value,isTrue);
     await tester.drag(find.byType(SingleChildScrollView).first,const Offset(0,900));await tester.pumpAndSettle();
     await capture('actual-watch-entry-inline-checked');
     if(view.name=='phone')expect(tester.getTopLeft(find.text('Date unsure')).dy,tester.getTopLeft(find.text('At cinema')).dy);
     await tester.tap(find.byKey(const ValueKey('unknown-date-checkbox')));await tester.pumpAndSettle();expect(find.text('Date unknown'),findsOneWidget);
     await tester.tap(find.byKey(const ValueKey('unknown-date-checkbox')));await tester.pumpAndSettle();
     await tester.tap(checkbox);await tester.pumpAndSettle();expect(tester.widget<CheckboxListTile>(checkbox).value,isFalse);
    }
    await tester.pumpWidget(const SizedBox.shrink());await tester.pumpAndSettle();
   }
  }
 });
}
