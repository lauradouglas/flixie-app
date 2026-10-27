// Offline marketing fixtures. No account or backend data is read or changed.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/data/profile_data_service.dart';
import 'package:flixie_app/features/profile/presentation/controllers/profile_diary_controller.dart';
import 'package:flixie_app/features/profile/presentation/pages/profile_diary_screen.dart';
import 'package:flixie_app/features/profile/presentation/diary/diary_watch_entry.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/models/watchlist_movie.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/profile_avatar.dart';
import '../../test/features/profile/profile_controller_test.dart' show ProfileAuth;
const out = 'design/marketing/instagram-diary-2026-10-26';
late ui.Image marketingWordmark;
class MarketingWordmark extends StatelessWidget { const MarketingWordmark({super.key}); @override Widget build(BuildContext context) => RawImage(image:marketingWordmark,width:73,height:26,fit:BoxFit.contain,filterQuality:FilterQuality.high); }
const ink = Color(0xff302044), paper = Color(0xffede3fb);
const people = [FriendshipUser(id:'fictional-jamie',username:'Jamie',avatar:ProfileAvatar(id:1,key:'astronaut',displayName:'Astronaut',storagePath:'offline/astronaut',imageUrl:'https://fixtures.flixie.invalid/astronaut.png'),profileBadges:['EARLY_ADOPTER']),FriendshipUser(id:'fictional-sophie',username:'Sophie',avatar:ProfileAvatar(id:2,key:'cat',displayName:'Black cat',storagePath:'offline/cat',imageUrl:'https://fixtures.flixie.invalid/cat.png'),profileBadges:['FOUNDER'])];
MovieWatchEntry entry(String id,int movie,String title,String date,double rating,String note,{bool cinema=false,List<FriendshipUser> withPeople=const []}) => MovieWatchEntry(id:id,userId:'viewer',movieId:movie,watchedAt:'${date}T19:00:00Z',rating:rating,notes:note,watchedAtCinema:cinema,companions:withPeople,removed:false,movie:WatchlistMovieDetails(id:movie,title:title,posterPath:'https://fixtures.flixie.invalid/$movie.jpg'));
final watches = [
 entry('old-film',999,'An earlier film','2026-09-05',7,'Earlier viewing.'),
 entry('old-spider',557,'Spider-Man','2026-09-12',8,'A comfort film.'),
 entry('old-interstellar',157336,'Interstellar','2026-09-20',10,'Straight into my favourites.'),
 entry('alien',348,'Alien','2026-10-20',9,'Jamie jumped. I pretended I didn’t.',cinema:true,withPeople:people),
 entry('spider',557,'Spider-Man','2026-10-22',8,'Rain outside. Comfort film on.'),
 entry('interstellar',157336,'Interstellar','2026-10-24',10,'Even better on the big screen.',cinema:true,withPeople:[people.first]),
 entry('se7en',807,'Se7en','2026-10-23',9,'Still thinking about it.'),
 entry('arrival',329865,'Arrival','2026-10-25',9,'Sophie was right about this one.'),
];
class MarketingDiaryData extends ProfileDataService { @override Future<List<MovieWatchEntry>> movieWatches(String userId) async => watches; }
Widget label(String s,double size,{Color color=Colors.white,FontWeight weight=FontWeight.w700}) => Text(s,style:TextStyle(fontFamily:'Manrope',fontSize:size,color:color,fontWeight:weight,height:1.12));
Widget memoryPage(List<MovieWatchEntry> entries) => Container(padding:const EdgeInsets.symmetric(horizontal:18,vertical:14),decoration:BoxDecoration(color:paper,borderRadius:BorderRadius.circular(14)),child:DefaultTextStyle(style:const TextStyle(fontFamily:'Manrope',color:ink),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[const Expanded(child:Text('Dear film diary,',style:TextStyle(fontFamily:'Georgia',fontSize:25,fontWeight:FontWeight.bold))),Image.asset('assets/icon/community_pips/pip-flixie-hoodie.png',width:48,height:48)]),const SizedBox(height:8),label('@elliesfilmclub',11,color:ink,weight:FontWeight.w600),const SizedBox(height:8),label('19–25 October 2026',11,color:const Color(0xff67547d),weight:FontWeight.w500),for(final e in entries)...[DiaryWatchEntry(entry:e,rewatch:const ['spider','interstellar'].contains(e.id)),if(e!=entries.last)const Divider(color:Color(0xffd7c7e6),height:1)]])));
void main(){testWidgets('render four offline diary carousel slides and source screenshot',(tester) async {

 for(final f in ['Manrope','Roboto','.SF Pro Display']) { await (FontLoader(f)..addFont(rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'))).load(); }
 await (FontLoader('Georgia')..addFont(Future.value(ByteData.sublistView(File('/System/Library/Fonts/Supplemental/Georgia.ttf').readAsBytesSync())))).load();
 await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();

 for(final item in [(348,'output/watch-together-mockups/alien.jpg'),(557,'output/diary-mockups/spider-man.jpg'),(157336,'output/diary-mockups/interstellar.jpg'),(807,'$out/fixtures/se7en.jpg'),(329865,'$out/fixtures/arrival.jpg')]) {
 final info=await tester.runAsync(()async{final codec=await ui.instantiateImageCodec(await File(item.$2).readAsBytes());return ImageInfo(image:(await codec.getNextFrame()).image);});
 final provider=CachedNetworkImageProvider('https://fixtures.flixie.invalid/${item.$1}.jpg');
 final cacheKey=provider;
 PaintingBinding.instance.imageCache.putIfAbsent(cacheKey,()=>OneFrameImageStreamCompleter(Future.value(info!)));
 }


 // Source rectangles are the existing Flixie avatar artwork in the saved picker capture.
 // Cache them as offline images; the production avatar widget retains each badge frame.
 for(final avatar in [('astronaut',742.0),('cat',984.0)]) {
 final info=await tester.runAsync(() async {
 final codec=await ui.instantiateImageCodec(await File('design/avatar-selection-2026-09-29/avatar-reference.png').readAsBytes());
 final source=(await codec.getNextFrame()).image;
 final recorder=ui.PictureRecorder();final canvas=Canvas(recorder);
 canvas.drawImageRect(source,Rect.fromLTWH(126,avatar.$2,184,184),const Rect.fromLTWH(0,0,184,184),Paint()..filterQuality=FilterQuality.high);
 final image=await recorder.endRecording().toImage(184,184);
 final bytes=await image.toByteData(format:ui.ImageByteFormat.png);
 await Directory('$out/fixtures').create(recursive:true);
 await File('$out/fixtures/${avatar.$1}.png').writeAsBytes(bytes!.buffer.asUint8List());
 source.dispose();return ImageInfo(image:image);
 });
 PaintingBinding.instance.imageCache.putIfAbsent(CachedNetworkImageProvider('https://fixtures.flixie.invalid/${avatar.$1}.png'),()=>OneFrameImageStreamCompleter(Future.value(info!)));
 }
 marketingWordmark=(await tester.runAsync(() async {
 final codec=await ui.instantiateImageCodec(await File('assets/icon/flixie_text_1024.png').readAsBytes());
 final source=(await codec.getNextFrame()).image;
 final recorder=ui.PictureRecorder();final canvas=Canvas(recorder);
 // Preserve the official letter shapes, with the project's required white x.
 canvas.drawImageRect(source,const Rect.fromLTWH(140,372,736,266),const Rect.fromLTWH(0,0,736,266),Paint()..filterQuality=FilterQuality.high);
 canvas.drawImageRect(source,const Rect.fromLTWH(430,372,169,266),const Rect.fromLTWH(290,0,169,266),Paint()..colorFilter=const ColorFilter.mode(Colors.white,BlendMode.srcIn)..filterQuality=FilterQuality.high);
 final result=await recorder.endRecording().toImage(736,266);source.dispose();return result;
 }))!;
 final pipKey=await tester.runAsync(() => const AssetImage('assets/icon/community_pips/pip-flixie-hoodie.png').obtainKey(ImageConfiguration.empty));
 final pipInfo=await tester.runAsync(() async { final codec=await ui.instantiateImageCodec(await File('assets/icon/community_pips/pip-flixie-hoodie.png').readAsBytes());return ImageInfo(image:(await codec.getNextFrame()).image); });
 PaintingBinding.instance.imageCache.putIfAbsent(pipKey!,()=>OneFrameImageStreamCompleter(Future.value(pipInfo!)));
 final auth=ProfileAuth(); final controller=ProfileDiaryController(auth:auth,service:MarketingDiaryData());
 await controller.load();
 await tester.runAsync(() => Directory(out).create(recursive:true));

 Future<void> capture(String name,Widget child,Size size) async {
 tester.view.physicalSize=size;tester.view.devicePixelRatio=1;await tester.binding.setSurfaceSize(size);
 final key=GlobalKey();await tester.pumpWidget(RepaintBoundary(key:key,child:MaterialApp(debugShowCheckedModeBanner:false,theme:AppTheme.darkTheme,home:child)));
 await tester.pumpAndSettle();expect(tester.takeException(),isNull,reason:name);
 await tester.runAsync(()async{final image=await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio:2.5);final bytes=await image.toByteData(format:ui.ImageByteFormat.png);await File('$out/$name.png').writeAsBytes(bytes!.buffer.asUint8List());image.dispose();});
 }
 await capture('diary-screenshot',Scaffold(body:Column(children:[const SizedBox(height:18),label('@elliesfilmclub',14),const SizedBox(height:10),Expanded(child:ProfileDiaryScreen(controller:controller,today:DateTime(2026,10,25)))])),const Size(430,1450));
 final specs=[
 ('01-film-diary','Some films deserve\na diary entry.','Keep your film nights in Flixie.',watches.sublist(3,5)),
 ('02-your-ratings','Your films.\nYour very honest ratings.','First impressions and old favourites.',[watches[7],watches[5]]),
 ('03-film-memories','Remember who\nyou watched with.','Cinema trips. Rewatches. Good company.',[watches[3],watches[5]]),
 ('04-start-your-diary','Start with\nyour last film.','Your next diary entry is one watch away.',[watches[4],watches[6],watches[7]])
 ];
 for(final s in specs){await capture(s.$1,Scaffold(backgroundColor:const Color(0xff151522),body:Padding(padding:const EdgeInsets.fromLTRB(26,22,26,20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const MarketingWordmark(),const SizedBox(height:18),label(s.$2,29),const SizedBox(height:9),label(s.$3,12,color:const Color(0xffcfc3e1),weight:FontWeight.w500),const SizedBox(height:20),Expanded(child:Center(child:FittedBox(fit:BoxFit.contain,child:SizedBox(width:380,child:memoryPage(s.$4))))),const SizedBox(height:14),Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[label('@flixie_co',11,color:const Color(0xffcfc3e1)),label(s.$1.startsWith('04')?'Download via the link in bio':'Your film diary, in Flixie',11)])]))),const Size(432,540));}
 await tester.pumpWidget(const SizedBox());controller.dispose();auth.dispose();tester.view.resetPhysicalSize();tester.view.resetDevicePixelRatio();await tester.binding.setSurfaceSize(null);
 });}
