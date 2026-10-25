// Preview only: fictional diary, local calendar and companion examples.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_wordmark.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'diary_options.dart' show movies, ink, mutedInk;

const diaryPaper = Color(0xfff4edf9);
final anchorWeek = DateTime(2026, 10, 12);
final fixtureWatches = <({DateTime date, int movie, List<String> people})>[
  (date: DateTime(2026, 10, 6), movie: 0, people: []),
  (date: DateTime(2026, 10, 12), movie: 0, people: ['Sophie']),
  (date: DateTime(2026, 10, 14), movie: 1, people: []),
  (date: DateTime(2026, 10, 16), movie: 2, people: ['Sophie', 'Robin']),
  (date: DateTime(2026, 10, 23), movie: 2, people: ['Robin']),
];
const monthNames = ['January','February','March','April','May','June','July','August','September','October','November','December'];
DateTime mondayOf(DateTime day) => DateTime(day.year, day.month, day.day - day.weekday + 1);
String weekLabel(DateTime monday) {
  final end = monday.add(const Duration(days: 6));
  return monday.month == end.month ? '${monday.day}–${end.day} ${monthNames[end.month-1]}' : '${monday.day} ${monthNames[monday.month-1]}–${end.day} ${monthNames[end.month-1]}';
}
Text copy(String s, double size, {Color color=ink, FontWeight weight=FontWeight.w500, String? font}) => Text(s, style: TextStyle(fontSize:size, height:1.35, color:color, fontWeight:weight, fontFamily:font));
Widget plannerRefinementApp({double scale=1}) => MaterialApp(debugShowCheckedModeBanner:false, theme:AppTheme.darkTheme, builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:TextScaler.linear(scale)),child:child!),home:const RefinedPlanner());

class RefinedPlanner extends StatefulWidget {
  const RefinedPlanner({super.key});
  @override State<RefinedPlanner> createState()=>_RefinedPlannerState();
}
class _RefinedPlannerState extends State<RefinedPlanner> {
  final controller=PageController(initialPage:1000);
  int index=1000;
  final settings=<DateTime,String?>{DateTime(2026,10,12):'Cinema',DateTime(2026,10,14):'TV'};
  Future<void> editSetting(DateTime date, int movie, List<String> people) async {
    final result=await showModalBottomSheet<({String? setting})>(context:context,useRootNavigator:true,useSafeArea:true,isScrollControlled:true,backgroundColor:diaryPaper,builder:(_)=>ViewingSettingSheet(movie:movie,date:date,people:people,initialSetting:settings[date]));
    if(mounted && result!=null)setState(()=>settings[date]=result.setting);
  }
  DateTime get week=>anchorWeek.add(Duration(days:(index-1000)*7));
  @override void dispose(){controller.dispose();super.dispose();}
  Future<void> chooseWeek() async {
    final selected=await showModalBottomSheet<DateTime>(context:context,useRootNavigator:true,useSafeArea:true,isScrollControlled:true,backgroundColor:diaryPaper,builder:(_)=>WeekPicker(initialWeek:week));
    if(!mounted || selected==null)return;
    controller.jumpToPage(1000+selected.difference(anchorWeek).inDays~/7);
  }
  Widget weekControls(DateTime date)=>Row(children:[IconButton(tooltip:'Previous week',onPressed:()=>controller.previousPage(duration:const Duration(milliseconds:220),curve:Curves.easeOut),icon:const Icon(Icons.chevron_left,color:ink)),Expanded(child:TextButton(onPressed:chooseWeek,style:TextButton.styleFrom(foregroundColor:ink,minimumSize:const Size(48,48),padding:const EdgeInsets.symmetric(horizontal:4)),child:Wrap(alignment:WrapAlignment.center,crossAxisAlignment:WrapCrossAlignment.center,spacing:5,children:[const Icon(Icons.calendar_month_outlined,size:18),copy(weekLabel(date),16,weight:FontWeight.w800),const Icon(Icons.expand_more,size:18)]))),IconButton(tooltip:'Next week',onPressed:()=>controller.nextPage(duration:const Duration(milliseconds:220),curve:Curves.easeOut),icon:const Icon(Icons.chevron_right,color:ink))]);
  Widget companions(List<String> names)=>Padding(padding:const EdgeInsets.only(top:10),child:names.isEmpty?copy('Solo movie night',11,color:mutedInk):Column(crossAxisAlignment:CrossAxisAlignment.start,children:[copy('Watched with',11,color:mutedInk),const SizedBox(height:6),Wrap(spacing:10,runSpacing:8,children:[for(final name in names)Row(mainAxisSize:MainAxisSize.min,children:[ProfileAvatarView(avatar:null,fallbackText:name[0],fallbackColor:name=='Sophie'?const Color(0xff65418b):const Color(0xff28665d),profileBadges:name=='Sophie'?const ['EARLY_ADOPTER']:const ['FOUNDER'],size:26),const SizedBox(width:6),copy(name,11,weight:FontWeight.w700)])])]));
  Widget page(DateTime date) {
    final watches=fixtureWatches.where((e)=>mondayOf(e.date)==date).toList();
    return Container(margin:const EdgeInsets.fromLTRB(16,4,16,8),decoration:BoxDecoration(color:diaryPaper,borderRadius:BorderRadius.circular(14)),child:SingleChildScrollView(padding:const EdgeInsets.fromLTRB(18,22,18,22),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[copy('Dear film diary,',28,font:'Georgia',weight:FontWeight.w800),const SizedBox(height:4),copy('The films. The people. The little memories.',12,color:mutedInk),const SizedBox(height:16),weekControls(date),Center(child:copy('${watches.length} ${watches.length==1?'film':'films'}${date==anchorWeek?' · 1 rewatch':''}',12,color:mutedInk)),const SizedBox(height:22),Row(children:[for(int day=0;day<7;day++)Expanded(child:Column(children:[copy(['M','T','W','T','F','S','S'][day],11,color:mutedInk),const SizedBox(height:7),Container(width:32,height:32,alignment:Alignment.center,decoration:BoxDecoration(shape:BoxShape.circle,color:watches.any((e)=>e.date.day==date.add(Duration(days:day)).day)?ink:const Color(0xffe7ddf0)),child:copy('${date.add(Duration(days:day)).day}',12,color:watches.any((e)=>e.date.day==date.add(Duration(days:day)).day)?Colors.white:mutedInk,weight:FontWeight.w800))]))]),const SizedBox(height:24),if(watches.isEmpty)...[const SizedBox(height:30),copy('A quiet page.',25,font:'Georgia'),const SizedBox(height:8),copy('No films logged this week. Your next movie night will find a home here.',14,color:mutedInk),const SizedBox(height:40)],for(int n=0;n<watches.length;n++)...[entry(watches[n]),if(n<watches.length-1)Padding(padding:const EdgeInsets.symmetric(vertical:18),child:Divider(height:1,color:ink.withValues(alpha:.12)))] ])));
  }
  Widget entry(({DateTime date,int movie,List<String> people}) watch) {
    final i=watch.movie;
    return InkWell(onTap:()=>editSetting(watch.date,i,watch.people),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[SizedBox(width:30 * MediaQuery.textScalerOf(context).scale(1),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[copy('${watch.date.day}',23,font:'Georgia',weight:FontWeight.w800),copy(['MON','TUE','WED','THU','FRI','SAT','SUN'][watch.date.weekday-1],9,color:mutedInk,weight:FontWeight.w800),if(settings[watch.date]!=null)...[const SizedBox(height:8),Tooltip(message:settings[watch.date]!,child:Icon(settings[watch.date]=='Cinema'?Icons.theaters_outlined:Icons.tv_outlined,size:17,color:mutedInk,semanticLabel:'Watched ${settings[watch.date]=='Cinema'?'at the cinema':'on TV'}'))]])),const SizedBox(width:9),ClipRRect(borderRadius:BorderRadius.circular(5),child:Image.file(File(movies[i].$5),width:52,height:78,fit:BoxFit.cover)),const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[copy(movies[i].$1,17,weight:FontWeight.w800),const SizedBox(height:4),Row(children:[const Icon(Icons.star_rounded,size:17,color:Color(0xff8b5b13)),const SizedBox(width:4),copy('${movies[i].$3}/10${i==1?' · Rewatch':''}',12,weight:FontWeight.w700)]),const SizedBox(height:5),copy(movies[i].$4,12,color:mutedInk),companions(watch.people)]))]));
  }
  @override Widget build(BuildContext context)=>Scaffold(backgroundColor:const Color(0xff110b1f),body:SafeArea(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:550),child:Column(children:[const Padding(padding:EdgeInsets.fromLTRB(22,16,22,14),child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text('9:41',style:TextStyle(fontSize:13,fontWeight:FontWeight.w800)),FlixieWordmark(fontSize:24),Icon(Icons.battery_full_rounded,size:19)])),const Padding(padding:EdgeInsets.fromLTRB(16,0,22,14),child:Row(children:[Icon(Icons.chevron_left,size:28,color:Color(0xffc9b3f1)),Text('Profile',style:TextStyle(fontSize:14,color:Color(0xffc9b3f1))),Spacer(),Text('Your film diary',style:TextStyle(fontSize:15,fontWeight:FontWeight.w700))])),Expanded(child:PageView.builder(controller:controller,itemCount:2000,onPageChanged:(value)=>setState(()=>index=value),itemBuilder:(_,i)=>page(anchorWeek.add(Duration(days:(i-1000)*7))))),const Padding(padding:EdgeInsets.symmetric(vertical:10),child:Column(children:[Text('Swipe weeks · Tap the date to jump',style:TextStyle(color:Color(0xffd0bee5),fontSize:12)),SizedBox(height:5),Text('Illustrative diary · Fictional watches & people',style:TextStyle(color:Color(0xffa18fb5),fontSize:10))])),Container(width:110,height:4,margin:const EdgeInsets.only(bottom:8),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(5)))])))));
}

class WeekPicker extends StatefulWidget {
 const WeekPicker({super.key,required this.initialWeek});
 final DateTime initialWeek;
 @override State<WeekPicker> createState()=>_WeekPickerState();
}
class _WeekPickerState extends State<WeekPicker> {
 late DateTime selected=widget.initialWeek;
 late DateTime month=DateTime(selected.year,selected.month);
 int count(DateTime date)=>fixtureWatches.where((e)=>e.date==date).length;
 @override Widget build(BuildContext context)=>SizedBox(height:MediaQuery.sizeOf(context).height*.82,child:Column(children:[Container(width:36,height:4,margin:const EdgeInsets.only(top:12,bottom:8),decoration:BoxDecoration(color:const Color(0xffb4a3c7),borderRadius:BorderRadius.circular(3))),Expanded(child:SingleChildScrollView(padding:const EdgeInsets.fromLTRB(22,0,22,14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:copy('Find a week',27,font:'Georgia',weight:FontWeight.w800)),IconButton(tooltip:'Close calendar',onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close,color:ink))]),const SizedBox(height:5),copy('A little dot, a movie memory.',13,color:mutedInk),const SizedBox(height:18),Row(children:[IconButton(tooltip:'Previous month',onPressed:()=>setState(()=>month=DateTime(month.year,month.month-1)),icon:const Icon(Icons.chevron_left,color:ink)),Expanded(child:Center(child:copy('${monthNames[month.month-1]} ${month.year}',18,weight:FontWeight.w800))),IconButton(tooltip:'Next month',onPressed:()=>setState(()=>month=DateTime(month.year,month.month+1)),icon:const Icon(Icons.chevron_right,color:ink))]),const SizedBox(height:12),Row(children:[for(final d in ['M','T','W','T','F','S','S'])Expanded(child:Center(child:copy(d,12,color:mutedInk,weight:FontWeight.w700)))]),const SizedBox(height:10),calendar(),const SizedBox(height:14),Row(children:[Container(width:5,height:5,decoration:const BoxDecoration(color:Color(0xff8247ce),shape:BoxShape.circle)),const SizedBox(width:8),Expanded(child:copy('Film logged · Tap any day to select its week',12,color:mutedInk))]),const SizedBox(height:22),Container(width:double.infinity,padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:const Color(0xffe8dcf5),borderRadius:BorderRadius.circular(12)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[copy(weekLabel(selected),17,weight:FontWeight.w800),const SizedBox(height:5),copy('${fixtureWatches.where((e)=>mondayOf(e.date)==selected).length} films in this week',13,color:mutedInk)])),const SizedBox(height:12),copy('Illustrative dates · Your diary stays yours.',11,color:mutedInk)]))),Padding(padding:const EdgeInsets.fromLTRB(22,10,22,20),child:SizedBox(width:double.infinity,child:FilledButton(onPressed:()=>Navigator.pop(context,selected),style:FilledButton.styleFrom(backgroundColor:ink,foregroundColor:Colors.white,minimumSize:const Size.fromHeight(50)),child:Text('Show ${weekLabel(selected)}',textAlign:TextAlign.center,style:const TextStyle(fontSize:15,fontWeight:FontWeight.w700)))))]));
 Widget calendar(){
  final offset=month.weekday-1;
  final days=DateTime(month.year,month.month+1,0).day;
  final rows=((offset+days)/7).ceil();
  return Column(children:[for(int r=0;r<rows;r++)Row(children:[for(int c=0;c<7;c++)Expanded(child:cell(r*7+c-offset+1,days))])]);
 }
 Widget cell(int day,int days){
  if(day<1||day>days)return const SizedBox(height:51);
  final date=DateTime(month.year,month.month,day);
  final inWeek=mondayOf(date)==selected;
  final films=count(date);
  return Semantics(label:'${monthNames[month.month-1]} $day, $films films${inWeek?', selected week':''}',button:true,selected:inWeek,child:InkWell(key:ValueKey('calendar-${month.year}-${month.month}-$day'),onTap:()=>setState(()=>selected=mondayOf(date)),child:Container(height:51,margin:const EdgeInsets.symmetric(horizontal:1),decoration:BoxDecoration(color:inWeek?const Color(0xffe2cff5):Colors.transparent,borderRadius:BorderRadius.circular(day==selected.day||date.weekday==1||date.weekday==7?9:0)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[copy('$day',14,weight:inWeek?FontWeight.w800:FontWeight.w500),const SizedBox(height:5),Container(width:5,height:5,decoration:BoxDecoration(shape:BoxShape.circle,color:films>0?const Color(0xff8247ce):Colors.transparent))]))));
 }
}

class ViewingSettingSheet extends StatefulWidget {
 const ViewingSettingSheet({super.key,required this.movie,required this.date,required this.people,this.initialSetting});
 final int movie;
 final DateTime date;
 final List<String> people;
 final String? initialSetting;
 @override State<ViewingSettingSheet> createState()=>_ViewingSettingSheetState();
}
class _ViewingSettingSheetState extends State<ViewingSettingSheet> {
 late String? selected=widget.initialSetting;
 @override Widget build(BuildContext context)=>SizedBox(height:MediaQuery.sizeOf(context).height*.76,child:Column(children:[Container(width:36,height:4,margin:const EdgeInsets.only(top:12,bottom:10),decoration:BoxDecoration(color:const Color(0xffb4a3c7),borderRadius:BorderRadius.circular(3))),Expanded(child:SingleChildScrollView(padding:const EdgeInsets.fromLTRB(22,0,22,22),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:copy('Your watch entry',26,font:'Georgia',weight:FontWeight.w800)),IconButton(tooltip:'Close entry preview',onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close,color:ink))]),const SizedBox(height:20),Row(children:[ClipRRect(borderRadius:BorderRadius.circular(5),child:Image.file(File(movies[widget.movie].$5),width:54,height:80,fit:BoxFit.cover)),const SizedBox(width:16),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[copy(movies[widget.movie].$1,22,weight:FontWeight.w800),const SizedBox(height:6),copy('${widget.date.day} ${monthNames[widget.date.month-1]} ${widget.date.year}',13,color:mutedInk)]))]),const SizedBox(height:12),CheckboxListTile(contentPadding:EdgeInsets.zero,controlAffinity:ListTileControlAffinity.leading,dense:true,activeColor:ink,checkColor:Colors.white,side:const BorderSide(color:mutedInk),value:selected=='Cinema',onChanged:(value)=>setState(()=>selected=value==true?'Cinema':null),title:copy('Watched at the cinema',14)),const SizedBox(height:18),copy('Watched with',15,weight:FontWeight.w800),const SizedBox(height:10),widget.people.isEmpty?copy('Solo movie night',14,color:mutedInk):Wrap(spacing:14,runSpacing:10,children:[for(final person in widget.people)Row(mainAxisSize:MainAxisSize.min,children:[ProfileAvatarView(avatar:null,fallbackText:person[0],fallbackColor:person=='Sophie'?const Color(0xff65418b):const Color(0xff28665d),profileBadges:person=='Sophie'?const ['EARLY_ADOPTER']:const ['FOUNDER'],size:32),const SizedBox(width:10),copy(person,14,weight:FontWeight.w700)])]),const SizedBox(height:24),Row(children:[const Icon(Icons.star_rounded,color:Color(0xff8b5b13),size:21),const SizedBox(width:8),copy('${movies[widget.movie].$3}/10',16,weight:FontWeight.w800)]),const SizedBox(height:18),copy(movies[widget.movie].$4,16,font:'Georgia'),]))),Padding(padding:const EdgeInsets.fromLTRB(22,10,22,20),child:Column(children:[SizedBox(width:double.infinity,child:FilledButton(onPressed:()=>Navigator.pop(context,(setting:selected)),style:FilledButton.styleFrom(backgroundColor:ink,foregroundColor:Colors.white,minimumSize:const Size.fromHeight(50)),child:const Text('Save preview',style:TextStyle(fontSize:15,fontWeight:FontWeight.w700)))),const SizedBox(height:9),copy('Mockup only · No watch history is changed',11,color:mutedInk)]))]));
}
