// Isolated design options. All people and interactions are fictional and local.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_wordmark.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';

Widget logOptionApp(String option, {double textScale = 1}) => MaterialApp(
  theme: AppTheme.darkTheme, debugShowCheckedModeBanner: false,
  builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)), child: child!),
  home: LogOption(option:option),
);
class LogOption extends StatefulWidget {
  const LogOption({super.key,required this.option});
  final String option;
  @override State<LogOption> createState()=>_LogOptionState();
}
class _LogOptionState extends State<LogOption> {
  int? rating;
  bool companion=true, review=false, spoilers=false, dateKnown=true, saved=false;
  int step=0;
  String recommendation='No opinion';
  String get option=>widget.option;
  bool get guided=>option.startsWith('guided');
  bool get full=>option=='diary';
  @override void initState(){super.initState();rating=option=='diary'?8:null;review=full;step=option=='guided-rating'?1:0;}
  Widget small(String text)=>Text(text,style:TextStyle(fontSize:12,color:context.colors.medium,height:1.45));
  Widget label(String text)=>Text(text,style:const TextStyle(fontSize:15,fontWeight:FontWeight.w700));
  Widget avatar(String name,{bool sophie=true})=>ProfileAvatarView(avatar:null,fallbackText:name.substring(0,1),fallbackColor:sophie?const Color(0xff65418b):const Color(0xff28665d),profileBadges:sophie?const['EARLY_ADOPTER']:const['FOUNDER'],size:40);
  Widget movie()=>Row(children:[ClipRRect(borderRadius:BorderRadius.circular(7),child:Image.file(File('output/watch-together-mockups/alien.jpg'),width:48,height:70,fit:BoxFit.cover)),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Alien',style:TextStyle(fontSize:21,fontWeight:FontWeight.w800)),const SizedBox(height:4),small('1979 · 1h 57m')]))]);
  Widget dateRow()=>InkWell(onTap:()=>setState(()=>dateKnown=!dateKnown),borderRadius:BorderRadius.circular(12),child:Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Row(children:[Icon(Icons.calendar_today_outlined,size:21,color:context.colors.primaryText),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[label(dateKnown?'Today':'Date unknown'),small(dateKnown?'16 October 2026':'Add a date whenever you remember')])),Text('Change',style:TextStyle(color:context.colors.primaryText,fontWeight:FontWeight.w600))])));
  Future<void> pick() async {
    final selected=await showModalBottomSheet<bool>(context:context,useRootNavigator:true,useSafeArea:true,isScrollControlled:true,backgroundColor:Colors.transparent,builder:(_)=>SizedBox(height:MediaQuery.sizeOf(context).height*.72,child:_Picker(onSelect:()=>Navigator.of(context,rootNavigator:true).pop(true))));
    if(mounted&&selected==true)setState(()=>companion=true);
  }
  Widget companionRow()=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Expanded(child:label('Watched with')),TextButton(onPressed:pick,child:Text(companion?'Change':'Add someone'))]),
    if(companion) Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:context.colors.surfaceElevated,borderRadius:BorderRadius.circular(12)),child:Row(crossAxisAlignment:CrossAxisAlignment.center,children:[avatar('Sophie'),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[label('Sophie'),const SizedBox(height:3),small('She’ll be prompted to log her watch.')])),IconButton(tooltip:'Remove Sophie',onPressed:()=>setState(()=>companion=false),icon:const Icon(Icons.close_rounded,size:19))]))
    else small('Just you for now. Add a friend if you watched together.'),
  ]);
  Widget ratings()=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Expanded(child:label(guided?'How was it?':'Your rating')),if(rating!=null)TextButton(onPressed:()=>setState(()=>rating=null),child:const Text('Clear')) else small('Optional')]),
    const SizedBox(height:10),
    LayoutBuilder(builder:(context,box){final width=(box.maxWidth-32)/5;return Wrap(spacing:8,runSpacing:8,children:List.generate(10,(index){final n=index+1;return SizedBox(width:width,height:44,child:OutlinedButton(onPressed:()=>setState(()=>rating=rating==n?null:n),style:OutlinedButton.styleFrom(padding:EdgeInsets.zero,backgroundColor:rating==n?FlixieColors.primary:context.colors.surfaceElevated,foregroundColor:rating==n?Colors.white:context.colors.primaryText,side:BorderSide(color:rating==n?FlixieColors.primary:context.colors.tabBarBorder),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))),child:Text('$n',style:const TextStyle(fontWeight:FontWeight.w700,fontSize:16))));}));}),
    const SizedBox(height:8),small(rating==null?'Out of 10 · You can rate it later.':'$rating / 10'),
  ]);
  Widget recommendations()=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[label('Would you recommend it?'),const SizedBox(height:10),Wrap(spacing:8,runSpacing:8,children:[for(final item in [('Yes',Icons.thumb_up_alt_outlined),('No opinion',Icons.remove_rounded),('No',Icons.thumb_down_alt_outlined)])ChoiceChip(label:Text(item.$1),avatar:Icon(item.$2,size:16),selected:recommendation==item.$1,onSelected:(_)=>setState(()=>recommendation=item.$1))])]);
  Widget reviewSection()=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    if(!review) TextButton.icon(onPressed:()=>setState(()=>review=true),icon:const Icon(Icons.edit_note_rounded),label:const Text('Add a review'))
    else ...[label('Your review'),const SizedBox(height:10),TextFormField(initialValue:full?'Still so tense, even when you know what’s coming.':'',minLines:2,maxLines:4,decoration:const InputDecoration(hintText:'What did you think?')),
      const SizedBox(height:6),small('Shared with friends, following your privacy settings.'),
      CheckboxListTile(contentPadding:EdgeInsets.zero,dense:true,controlAffinity:ListTileControlAffinity.leading,value:spoilers,onChanged:(v)=>setState(()=>spoilers=v!),title:const Text('Contains spoilers'))],
  ]);
  Widget mainBody()=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[movie(),const SizedBox(height:12),
    if(guided&&step==1) ...[
      small('Today${companion?' · With Sophie':''}'),const SizedBox(height:24),ratings(),const SizedBox(height:20),recommendations(),const SizedBox(height:14),reviewSection(),
    ] else ...[
      dateRow(),Divider(color:context.colors.tabBarBorder),companionRow(),
      if(guided) ...[const SizedBox(height:24),Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:context.colors.surfaceElevated,borderRadius:BorderRadius.circular(12)),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(Icons.info_outline,size:19,color:context.colors.primaryText),const SizedBox(width:10),Expanded(child:small('This saves your watch only. Sophie can add her own date, rating and review.'))]))]
      else ...[const SizedBox(height:24),ratings(),if(full)...[const SizedBox(height:18),recommendations()],const SizedBox(height:10),
        if(!full) ExpansionTile(tilePadding:EdgeInsets.zero,childrenPadding:const EdgeInsets.only(bottom:12),title:const Text('Recommendation & review',style:TextStyle(fontSize:14,fontWeight:FontWeight.w600)),children:[recommendations(),const SizedBox(height:12),reviewSection()]) else reviewSection()],
    ],
  ]);
  @override Widget build(BuildContext context)=>Scaffold(backgroundColor:context.colors.background,body:SafeArea(child:Column(children:[
    Padding(padding:const EdgeInsets.fromLTRB(24,12,24,10),child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text('9:41',style:TextStyle(fontSize:13,fontWeight:FontWeight.w700)),Row(children:[const FlixieWordmark(fontSize:22),const SizedBox(width:16),Icon(Icons.battery_full,size:19,color:context.colors.light)])])),
    const SizedBox(height:12),
    Expanded(child:Container(decoration:BoxDecoration(color:context.colors.surface,borderRadius:const BorderRadius.vertical(top:Radius.circular(24))),child:Column(children:[
      Container(width:36,height:4,margin:const EdgeInsets.only(top:12,bottom:12),decoration:BoxDecoration(color:context.colors.medium,borderRadius:BorderRadius.circular(4))),
      Padding(padding:const EdgeInsets.fromLTRB(20,0,12,8),child:Row(children:[if(guided&&step==1)IconButton(tooltip:'Back to watch details',onPressed:()=>setState(()=>step=0),icon:const Icon(Icons.arrow_back)),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(saved?'Watch saved':guided&&step==1?'Rate & review':'Log your watch',style:const TextStyle(fontSize:23,fontWeight:FontWeight.w800)),if(guided)...[const SizedBox(height:3),small(step==0?'Watch details · 1 of 2':'Your thoughts · 2 of 2')]])),IconButton(tooltip:'Close preview',onPressed:()=>setState(()=>saved=false),icon:const Icon(Icons.close_rounded))])),
      Expanded(child:SingleChildScrollView(padding:const EdgeInsets.fromLTRB(20,4,20,20),child:Material(color:Colors.transparent,child:saved?Column(children:[const SizedBox(height:80),Icon(Icons.check_circle_outline_rounded,color:context.colors.success,size:60),const SizedBox(height:16),label('Alien is in your watch history'),const SizedBox(height:10),small(companion?'Sophie will get a prompt to log hers.':'Saved just for you.')]):mainBody()))),
      Container(padding:const EdgeInsets.fromLTRB(20,12,20,14),decoration:BoxDecoration(color:context.colors.surface,border:Border(top:BorderSide(color:context.colors.tabBarBorder))),child:Column(children:[
        SizedBox(width:double.infinity,child:FilledButton(onPressed:()=>setState((){if(guided&&step==0){step=1;}else{saved=true;}}),style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(50)),child:Text(guided&&step==0?'Next · Rate & review':'Save watch',style:const TextStyle(fontWeight:FontWeight.w700,fontSize:16)))),
        if(guided&&step==0) TextButton(onPressed:()=>setState(()=>saved=true),child:const Text('Save without a rating')) else ...[const SizedBox(height:7),small(companion?'Sophie confirms her own watch.':'You can add more details later.')],
      ])),
    ]))),
    Container(width:116,height:4,margin:const EdgeInsets.symmetric(vertical:10),decoration:BoxDecoration(color:context.colors.white,borderRadius:BorderRadius.circular(3))),
  ])));
}
class _Picker extends StatelessWidget {
  const _Picker({required this.onSelect});final VoidCallback onSelect;
  @override Widget build(BuildContext context)=>Material(color:context.colors.surface,borderRadius:const BorderRadius.vertical(top:Radius.circular(24)),child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Center(child:Container(width:36,height:4,margin:const EdgeInsets.only(bottom:20),decoration:BoxDecoration(color:context.colors.medium,borderRadius:BorderRadius.circular(3)))),
    Row(children:[const Expanded(child:Text('Watched with…',style:TextStyle(fontSize:23,fontWeight:FontWeight.w800))),IconButton(tooltip:'Close',onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close))]),
    const SizedBox(height:12),const TextField(decoration:InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Search your friends')),
    const SizedBox(height:18),Text('Choose a friend',style:TextStyle(color:context.colors.medium)),const SizedBox(height:10),
    for(final (name,badges,color) in [('Sophie',const['EARLY_ADOPTER'],const Color(0xff65418b)),('Casey',const['FOUNDER'],const Color(0xff28665d)),('Robin',const['OG_USER'],const Color(0xff5f507e))]) ListTile(contentPadding:const EdgeInsets.symmetric(vertical:5),leading:ProfileAvatarView(avatar:null,fallbackText:name[0],fallbackColor:color,profileBadges:badges,size:44),title:Text(name),trailing:Icon(name=='Sophie'?Icons.check_circle:Icons.add_rounded,color:context.colors.primaryText),onTap:onSelect),
    const Spacer(),Text('They’ll get a prompt when you save. Their history stays theirs to confirm.',style:TextStyle(color:context.colors.medium,height:1.5)),const SizedBox(height:8),
  ])));
}
