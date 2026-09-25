import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/app_settings.dart';
import '../../core/audio_feedback.dart';
import '../../core/network/local_network_core.dart';

class Hand51GameScreen extends StatefulWidget {
  const Hand51GameScreen({super.key, this.networkCore});
  final LocalNetworkCore? networkCore;
  @override State<Hand51GameScreen> createState() => _Hand51GameScreenState();
}

class _Hand51GameScreenState extends State<Hand51GameScreen> {
  final rnd = Random();
  final settings = AppSettingsController.instance;
  List<_C> deck=[], me=[], bot=[], discard=[];
  List<List<_C>> melds=[];
  final Set<String> selected={};
  int round=1, myPenalty=0, botPenalty=0;
  bool myOpened=false, botOpened=false, myTurn=true, drew=false, finished=false;
  String message='دورك: اسحب ورقة';

  @override void initState(){super.initState(); _deal(reset:true);}

  int value(_C c)=>c.joker||c.rank==1?11:(c.rank>=10?10:c.rank);
  int penalty(List<_C> h,bool opened)=>opened?h.fold(0,(s,c)=>s+value(c)):100;

  void _deal({bool reset=false}){
    if(reset){round=1;myPenalty=0;botPenalty=0;}
    final all=<_C>[];
    for(final s in ['♠','♥','♦','♣']) for(int r=1;r<=13;r++) all.add(_C(s,r));
    all.add(const _C('★',0,joker:true,copy:1));
    all.add(const _C('★',0,joker:true,copy:2));
    all.shuffle(rnd);
    me=all.take(13).toList(); bot=all.skip(13).take(13).toList(); deck=all.skip(26).toList();
    discard=[deck.removeLast()]; melds=[]; selected.clear();
    myOpened=false;botOpened=false;myTurn=true;drew=false;finished=false;
    message='الجولة $round: اسحب من الرزمة أو آخر ورقة';
    setState((){});
  }

  void drawDeck(){
    if(!myTurn||drew||finished||deck.isEmpty)return;
    me.add(deck.removeLast());drew=true;GameFeedback.tap(GameAudioTheme.cards);
    setState(()=>message='اختر مجموعة للنزول أو ورقة للرمي');
  }
  void drawDiscard(){
    if(!myTurn||drew||finished||discard.isEmpty)return;
    me.add(discard.removeLast());drew=true;GameFeedback.capture(GameAudioTheme.cards);
    setState(()=>message='أخذت آخر ورقة مرمية');
  }
  void toggle(_C c){
    if(!myTurn||!drew||finished)return;
    setState(()=>selected.add(c.id)?null:selected.remove(c.id));
  }
  List<_C> get picks=>me.where((c)=>selected.contains(c.id)).toList();

  bool sameRank(List<_C> x){
    if(x.length<3)return false;
    final n=x.where((c)=>!c.joker).toList();
    if(n.isEmpty)return true;
    return n.every((c)=>c.rank==n.first.rank);
  }
  bool sequence(List<_C> x){
    if(x.length<3)return false;
    final n=x.where((c)=>!c.joker).toList();
    if(n.isEmpty)return true;
    if(n.map((c)=>c.suit).toSet().length!=1)return false;
    final jok=x.where((c)=>c.joker).length;
    bool fits(List<int> r){
      r.sort(); if(r.toSet().length!=r.length)return false;
      int gaps=0; for(int i=1;i<r.length;i++) gaps+=r[i]-r[i-1]-1;
      return gaps<=jok;
    }
    if(fits(n.map((c)=>c.rank).toList()))return true;
    return fits(n.map((c)=>c.rank==1?14:c.rank).toList()); // A after K
  }
  bool valid(List<_C> x)=>sameRank(x)||sequence(x);

  void meld(){
    final x=picks;
    if(!myTurn||!drew||finished||x.length<3)return;
    if(!valid(x)){GameFeedback.error(GameAudioTheme.cards);setState(()=>message='المجموعة غير صحيحة');return;}
    final pts=x.fold(0,(s,c)=>s+value(c));
    if(!myOpened&&pts<51){GameFeedback.error(GameAudioTheme.cards);setState(()=>message='أول نزول يجب أن يكون 51 أو أكثر');return;}
    me.removeWhere((c)=>selected.contains(c.id));melds.add(List.of(x));selected.clear();myOpened=true;
    GameFeedback.capture(GameAudioTheme.cards);message='نزول صحيح بقيمة $pts';
    if(me.isEmpty){finish(true);return;} setState((){});
  }

  void addToMeld(int index){
    if(!myOpened||picks.length!=1||!myTurn||!drew)return;
    final c=picks.first, test=[...melds[index],c];
    if(!valid(test)){GameFeedback.error(GameAudioTheme.cards);return;}
    melds[index]=test;me.remove(c);selected.clear();GameFeedback.move(GameAudioTheme.cards);
    if(me.isEmpty){finish(true);return;} setState((){});
  }

  void throwSelected(){
    if(!myTurn||!drew||picks.length!=1||finished)return;
    final c=picks.first;me.remove(c);discard.add(c);selected.clear();GameFeedback.move(GameAudioTheme.cards);
    if(me.isEmpty){finish(true);return;}
    myTurn=false;drew=false;setState(()=>message='الروبوت يلعب...');
    Future.delayed(const Duration(milliseconds:550),botMove);
  }

  List<_C>? findMeld(){
    for(int r=1;r<=13;r++){
      final x=bot.where((c)=>c.joker||c.rank==r).toList();
      if(x.length>=3){
        for(int k=min(5,x.length);k>=3;k--){final p=x.take(k).toList();if(valid(p))return p;}
      }
    }
    for(final s in ['♠','♥','♦','♣']){
      final n=bot.where((c)=>c.joker||c.suit==s).toList();
      for(int a=0;a<n.length;a++)for(int b=a+2;b<n.length;b++){final p=n.sublist(a,b+1);if(valid(p))return p;}
    }
    return null;
  }

  void botMove(){
    if(!mounted||finished)return;
    if(discard.isNotEmpty&&bot.any((c)=>!c.joker&&c.rank==discard.last.rank)){bot.add(discard.removeLast());}
    else if(deck.isNotEmpty)bot.add(deck.removeLast());
    int tries=switch(settings.botDifficultyFor('hand51')){BotDifficulty.easy=>1,BotDifficulty.normal=>2,BotDifficulty.hard=>4};
    while(tries-->0){
      final x=findMeld();if(x==null)break;
      final pts=x.fold(0,(s,c)=>s+value(c));
      if(!botOpened&&pts<51)break;
      bot.removeWhere(x.contains);melds.add(x);botOpened=true;
      if(bot.isEmpty){finish(false);return;}
    }
    if(botOpened){
      for(final c in List<_C>.of(bot)){
        bool placed=false;
        for(int i=0;i<melds.length;i++){
          final t=[...melds[i],c];
          if(valid(t)){melds[i]=t;bot.remove(c);placed=true;break;}
        }
        if(placed)break;
      }
    }
    if(bot.isEmpty){finish(false);return;}
    bot.sort((a,b)=>value(b).compareTo(value(a)));
    final c=bot.firstWhere((x)=>!x.joker,orElse:()=>bot.first);
    bot.remove(c);discard.add(c);myTurn=true;drew=false;message='دورك: اسحب ورقة';setState((){});
  }

  void finish(bool iWon){
    finished=true;
    final p=iWon?0:penalty(me,myOpened), b=iWon?penalty(bot,botOpened):0;
    myPenalty+=p;botPenalty+=b;
    message=iWon?'فزت بالجولة — الروبوت عليه $b نقطة':'الروبوت أنهى أوراقه — عليك $p نقطة';
    iWon?GameFeedback.win(GameAudioTheme.cards):GameFeedback.lose(GameAudioTheme.cards);
    setState((){});
  }

  void next(){
    if(round>=3){
      final win=myPenalty<botPenalty;
      showDialog(context:context,builder:(_)=>AlertDialog(
        title:Text(win?'فزت بالمباراة 🎉':'انتهت المباراة'),
        content:Text('مجموعك: $myPenalty\nالروبوت: $botPenalty\nالأقل نقاطًا يفوز.'),
        actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('إغلاق')),
          FilledButton(onPressed:(){Navigator.pop(context);_deal(reset:true);},child:const Text('مباراة جديدة'))],
      ));return;
    }
    round++;_deal();
  }

  @override Widget build(BuildContext context){
    final top=discard.isEmpty?null:discard.last;
    return Scaffold(
      backgroundColor:const Color(0xFF10251E),
      appBar:AppBar(title:const Text('Hand 51'),backgroundColor:const Color(0xFF173D31),foregroundColor:Colors.white),
      body:SafeArea(child:Column(children:[
        Padding(padding:const EdgeInsets.all(10),child:Container(
          padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:const Color(0xFF1D4E3F),borderRadius:BorderRadius.circular(18)),
          child:Column(children:[
            Row(children:[stat('الجولة','$round/3'),stat('نقاطك','$myPenalty'),stat('الروبوت','$botPenalty'),stat('يده','${bot.length}')]),
            const SizedBox(height:6),Text(message,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800))
          ]))),
        Expanded(child:Container(
          margin:const EdgeInsets.symmetric(horizontal:10),padding:const EdgeInsets.all(8),
          decoration:BoxDecoration(color:const Color(0xFF0B6B4F),borderRadius:BorderRadius.circular(22)),
          child:Column(children:[
            Row(mainAxisAlignment:MainAxisAlignment.center,children:[
              deckButton('الرزمة\n${deck.length}',drawDeck),const SizedBox(width:14),
              InkWell(onTap:drawDiscard,child:top==null?deckButton('الرمي',drawDiscard):card(top,small:true)),
            ]),
            const SizedBox(height:8),
            Expanded(child:melds.isEmpty?const Center(child:Text('لم ينزل أحد بعد',style:TextStyle(color:Colors.white70))):
              Wrap(alignment:WrapAlignment.center,spacing:8,runSpacing:8,children:[
                for(int i=0;i<melds.length;i++) InkWell(onTap:()=>addToMeld(i),child:Container(
                  padding:const EdgeInsets.all(5),decoration:BoxDecoration(color:Colors.black12,borderRadius:BorderRadius.circular(12)),
                  child:Row(mainAxisSize:MainAxisSize.min,children:[for(final c in melds[i]) Padding(padding:const EdgeInsets.all(1),child:card(c,small:true))])
                ))
              ]))
          ]))),
        Container(color:const Color(0xFF0B1713),padding:const EdgeInsets.all(8),child:Column(children:[
          Wrap(alignment:WrapAlignment.center,spacing:4,runSpacing:4,children:[for(final c in me) card(c,onTap:()=>toggle(c),picked:selected.contains(c.id))]),
          const SizedBox(height:7),
          Row(children:[
            Expanded(child:FilledButton.icon(onPressed:myTurn&&drew&&picks.length>=3?meld:null,icon:const Icon(Icons.call_merge),label:Text(myOpened?'نزول مجموعة':'فتح 51'))),
            const SizedBox(width:8),
            Expanded(child:OutlinedButton.icon(onPressed:myTurn&&drew&&picks.length==1?throwSelected:null,icon:const Icon(Icons.delete_sweep),label:const Text('ارمِ المحددة')))
          ]),
          if(finished) Padding(padding:const EdgeInsets.only(top:7),child:SizedBox(width:double.infinity,child:FilledButton(onPressed:next,child:Text(round>=3?'النتيجة النهائية':'الجولة التالية'))))
        ]))
      ]))
    );
  }

  Widget stat(String a,String b)=>Expanded(child:Column(children:[Text(b,style:const TextStyle(color:Colors.white,fontSize:17,fontWeight:FontWeight.w900)),Text(a,style:const TextStyle(color:Colors.white60,fontSize:10))]));
  Widget deckButton(String t,VoidCallback f)=>InkWell(onTap:f,child:Container(width:62,height:82,alignment:Alignment.center,decoration:BoxDecoration(color:const Color(0xFF173D31),borderRadius:BorderRadius.circular(13),border:Border.all(color:Colors.white24)),child:Text(t,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800))));
  Widget card(_C c,{bool small=false,bool picked=false,VoidCallback? onTap}){
    final red=c.suit=='♥'||c.suit=='♦';
    return GestureDetector(onTap:onTap,child:AnimatedContainer(duration:const Duration(milliseconds:140),width:small?36:43,height:small?53:65,
      transform:picked?(Matrix4.identity()..translate(0.0,-5.0)):Matrix4.identity(),
      decoration:BoxDecoration(color:c.joker?const Color(0xFFFFF3C4):Colors.white,borderRadius:BorderRadius.circular(9),border:Border.all(color:picked?const Color(0xFFFFD166):Colors.black26,width:picked?2.5:1)),
      alignment:Alignment.center,child:Text(c.joker?'J\n★':'${c.label}\n${c.suit}',textAlign:TextAlign.center,style:TextStyle(color:red?Colors.red.shade800:const Color(0xFF17212B),fontWeight:FontWeight.w900,fontSize:small?12:14,height:1))));
  }
}

class _C{
  const _C(this.suit,this.rank,{this.joker=false,this.copy=0});
  final String suit;final int rank;final bool joker;final int copy;
  String get id=>joker?'J$copy':'$suit-$rank';
  String get label=>rank==1?'A':rank==11?'J':rank==12?'Q':rank==13?'K':'$rank';
}
