import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/audio_feedback.dart';
import '../../core/network/local_network_core.dart';

class AirHockeyGameScreen extends StatefulWidget {
  const AirHockeyGameScreen({super.key,this.networkCore});
  final LocalNetworkCore? networkCore;
  @override State<AirHockeyGameScreen> createState()=>_AirHockeyGameScreenState();
}
class _AirHockeyGameScreenState extends State<AirHockeyGameScreen> with SingleTickerProviderStateMixin{
  late final AnimationController ticker;
  Offset puck=const Offset(.5,.5), vel=const Offset(.004,.0055);
  Offset me=const Offset(.5,.84), bot=const Offset(.5,.16);
  int myScore=0,botScore=0;
  final Random rnd=Random();
  @override void initState(){super.initState();ticker=AnimationController(vsync:this,duration:const Duration(days:1))..addListener(step)..repeat();}
  @override void dispose(){ticker.dispose();super.dispose();}
  void reset(bool toMe){puck=Offset(.5,.5);vel=Offset((rnd.nextBool()?1:-1)*.0045,toMe?.0055:-.0055);}
  void step(){
    var x=puck.dx+vel.dx,y=puck.dy+vel.dy;var vx=vel.dx,vy=vel.dy;
    if(x<.035||x>.965){vx=-vx;x=x.clamp(.035,.965);}
    final target=(x-bot.dx).clamp(-.012,.012);bot=Offset((bot.dx+target).clamp(.08,.92),.16);
    bool hit(Offset p)=> (Offset(x,y)-p).distance<.085;
    if(vy>0&&hit(me)){vy=-vel.dy.abs()*1.04;y=me.dy-.09;GameFeedback.move();}
    if(vy<0&&hit(bot)){vy=vel.dy.abs()*1.04;y=bot.dy+.09;GameFeedback.move();}
    if(y<-.03){myScore++;GameFeedback.win();reset(true);}
    if(y>1.03){botScore++;GameFeedback.lose();reset(false);}
    puck=Offset(x,y);vel=Offset(vx,vy);
    if(mounted)setState((){});
  }
  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:const Color(0xFF071827),
    appBar:AppBar(title:const Text('الهوكي الهوائي'),backgroundColor:const Color(0xFF071827),foregroundColor:Colors.white,
      actions:[Padding(padding:const EdgeInsets.all(12),child:Text('$myScore : $botScore',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900))) ]),
    body:SafeArea(child:Padding(padding:const EdgeInsets.all(10),child:LayoutBuilder(builder:(context,c){
      return GestureDetector(
        onPanUpdate:(d)=>setState(()=>me=Offset((me.dx+d.delta.dx/c.maxWidth).clamp(.08,.92),(me.dy+d.delta.dy/c.maxHeight).clamp(.57,.92))),
        child:CustomPaint(size:Size.infinite,painter:_HockeyPainter(puck:puck,me:me,bot:bot,myScore:myScore,botScore:botScore))
      );
    })))
  );
}
class _HockeyPainter extends CustomPainter{
  const _HockeyPainter({required this.puck,required this.me,required this.bot,required this.myScore,required this.botScore});
  final Offset puck,me,bot;final int myScore,botScore;
  @override void paint(Canvas c,Size s){
    final bg=Paint()..color=const Color(0xFF0C3552);c.drawRRect(RRect.fromRectAndRadius(Offset.zero&s,const Radius.circular(28)),bg);
    final line=Paint()..color=Colors.white24..style=PaintingStyle.stroke..strokeWidth=3;
    c.drawLine(Offset(0,s.height/2),Offset(s.width,s.height/2),line);c.drawCircle(Offset(s.width/2,s.height/2),55,line);
    c.drawLine(Offset(s.width*.3,6),Offset(s.width*.7,6),Paint()..color=Colors.redAccent..strokeWidth=8);
    c.drawLine(Offset(s.width*.3,s.height-6),Offset(s.width*.7,s.height-6),Paint()..color=Colors.lightBlueAccent..strokeWidth=8);
    Offset p(Offset o)=>Offset(o.dx*s.width,o.dy*s.height);
    c.drawCircle(p(bot),38,Paint()..color=const Color(0xFFFF5252));c.drawCircle(p(bot),23,Paint()..color=const Color(0xFFFF8A80));
    c.drawCircle(p(me),38,Paint()..color=const Color(0xFF40C4FF));c.drawCircle(p(me),23,Paint()..color=const Color(0xFF80D8FF));
    c.drawCircle(p(puck),18,Paint()..color=const Color(0xFF111111));c.drawCircle(p(puck)-const Offset(4,4),6,Paint()..color=Colors.white38);
  }
  @override bool shouldRepaint(covariant _HockeyPainter old)=>true;
}
