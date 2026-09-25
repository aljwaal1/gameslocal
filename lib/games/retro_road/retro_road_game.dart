import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/audio_feedback.dart';
import '../../core/network/local_network_core.dart';

class RetroRoadGameScreen extends StatefulWidget{
  const RetroRoadGameScreen({super.key,this.networkCore});
  final LocalNetworkCore? networkCore;
  @override State<RetroRoadGameScreen> createState()=>_RetroRoadGameScreenState();
}
class _RetroRoadGameScreenState extends State<RetroRoadGameScreen> with SingleTickerProviderStateMixin{
  late final AnimationController ticker;
  final Random rnd=Random();
  int lane=1,score=0,lives=3,tick=0;
  double speed=.006;
  bool over=false;
  final List<_RoadObj> traffic=[];
  @override void initState(){super.initState();ticker=AnimationController(vsync:this,duration:const Duration(days:1))..addListener(step)..repeat();}
  @override void dispose(){ticker.dispose();super.dispose();}
  void step(){
    if(over)return;
    tick++;score++;speed=min(.014,.006+score/90000);
    if(tick%72==0)traffic.add(_RoadObj(rnd.nextInt(3),-.12));
    for(final o in traffic)o.y+=speed;
    for(final o in List<_RoadObj>.of(traffic)){
      if(o.y>.77&&o.y<.96&&o.lane==lane){
        traffic.remove(o);lives--;GameFeedback.error(GameAudioTheme.football);
        if(lives<=0){over=true;GameFeedback.lose(GameAudioTheme.football);}
      }else if(o.y>1.1){traffic.remove(o);}
    }
    if(mounted)setState((){});
  }
  void move(int d){if(over)return;final n=(lane+d).clamp(0,2);if(n!=lane){lane=n;GameFeedback.move(GameAudioTheme.football);setState((){});}}
  void reset(){setState((){lane=1;score=0;lives=3;tick=0;speed=.006;traffic.clear();over=false;});}
  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:const Color(0xFF18130E),
    appBar:AppBar(title:const Text('طريق التحمل'),backgroundColor:const Color(0xFF18130E),foregroundColor:Colors.white,
      actions:[Padding(padding:const EdgeInsets.all(12),child:Text('$score',style:const TextStyle(fontSize:19,fontWeight:FontWeight.w900))) ]),
    body:SafeArea(child:Column(children:[
      Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),child:Row(children:[
        Text('❤️ $lives',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900)),
        const Spacer(),Text('السرعة ×${(speed/.006).toStringAsFixed(1)}',style:const TextStyle(color:Colors.amber,fontWeight:FontWeight.w800))
      ])),
      Expanded(child:Padding(padding:const EdgeInsets.all(10),child:GestureDetector(
        onHorizontalDragEnd:(d){if((d.primaryVelocity??0)<0)move(-1);else if((d.primaryVelocity??0)>0)move(1);},
        child:CustomPaint(size:Size.infinite,painter:_RoadPainter(lane:lane,traffic:traffic,score:score,over:over))
      ))),
      Padding(padding:const EdgeInsets.fromLTRB(10,0,10,10),child:Row(children:[
        Expanded(child:FilledButton.icon(onPressed:()=>move(-1),icon:const Icon(Icons.arrow_left),label:const Text('يسار'))),
        const SizedBox(width:10),
        Expanded(child:FilledButton.icon(onPressed:()=>move(1),icon:const Icon(Icons.arrow_right),label:const Text('يمين')))
      ])),
      if(over) Padding(padding:const EdgeInsets.fromLTRB(10,0,10,10),child:SizedBox(width:double.infinity,child:OutlinedButton.icon(onPressed:reset,icon:const Icon(Icons.refresh),label:const Text('إعادة اللعب'))))
    ]))
  );
}
class _RoadObj{_RoadObj(this.lane,this.y);final int lane;double y;}
class _RoadPainter extends CustomPainter{
  const _RoadPainter({required this.lane,required this.traffic,required this.score,required this.over});
  final int lane,score;final List<_RoadObj> traffic;final bool over;
  @override void paint(Canvas c,Size s){
    c.drawRect(Offset.zero&s,Paint()..color=const Color(0xFF7A9A4A));
    final road=Rect.fromLTWH(s.width*.12,0,s.width*.76,s.height);c.drawRect(road,Paint()..color=const Color(0xFF383838));
    c.drawRect(Rect.fromLTWH(road.left,0,5,s.height),Paint()..color=Colors.white70);c.drawRect(Rect.fromLTWH(road.right-5,0,5,s.height),Paint()..color=Colors.white70);
    final laneW=road.width/3;
    for(int k=1;k<3;k++)for(double y=-60+(score%90);y<s.height;y+=90)c.drawRect(Rect.fromLTWH(road.left+laneW*k-2,y,4,46),Paint()..color=Colors.white54);
    Offset carPos(int l,double y)=>Offset(road.left+laneW*(l+.5),s.height*y);
    void drawCar(Offset p,Color col,double scale){
      final r=Rect.fromCenter(center:p,width:laneW*.52*scale,height:82*scale);
      c.drawRRect(RRect.fromRectAndRadius(r,const Radius.circular(12)),Paint()..color=col);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center:Offset(p.dx,p.dy-13*scale),width:r.width*.66,height:24*scale),const Radius.circular(6)),Paint()..color=const Color(0xFF90CAF9));
      c.drawCircle(Offset(r.left,p.dy-20*scale),7*scale,Paint()..color=Colors.black);c.drawCircle(Offset(r.right,p.dy-20*scale),7*scale,Paint()..color=Colors.black);
      c.drawCircle(Offset(r.left,p.dy+22*scale),7*scale,Paint()..color=Colors.black);c.drawCircle(Offset(r.right,p.dy+22*scale),7*scale,Paint()..color=Colors.black);
    }
    for(final o in traffic)drawCar(carPos(o.lane,o.y),const Color(0xFFFF7043),.85);
    drawCar(carPos(lane,.88),const Color(0xFF42A5F5),1);
    if(over){c.drawRect(Offset.zero&s,Paint()..color=Colors.black54);final tp=TextPainter(text:const TextSpan(text:'انتهت الجولة',style:TextStyle(color:Colors.white,fontSize:30,fontWeight:FontWeight.w900)),textDirection:TextDirection.rtl)..layout();tp.paint(c,Offset((s.width-tp.width)/2,s.height*.43));}
  }
  @override bool shouldRepaint(covariant _RoadPainter old)=>true;
}
