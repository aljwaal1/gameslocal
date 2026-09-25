import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/audio_feedback.dart';
import '../../core/network/local_network_core.dart';

class FuelPlaneGameScreen extends StatefulWidget{
  const FuelPlaneGameScreen({super.key,this.networkCore});
  final LocalNetworkCore? networkCore;
  @override State<FuelPlaneGameScreen> createState()=>_FuelPlaneGameScreenState();
}
class _FuelPlaneGameScreenState extends State<FuelPlaneGameScreen> with SingleTickerProviderStateMixin{
  late final AnimationController ticker;
  final Random rnd=Random();
  double planeX=.5,fuel=100,score=0,speed=.004;
  final List<_Obj> objs=[];
  int tick=0;
  bool over=false;
  @override void initState(){super.initState();ticker=AnimationController(vsync:this,duration:const Duration(days:1))..addListener(step)..repeat();}
  @override void dispose(){ticker.dispose();super.dispose();}
  void reset(){setState((){planeX=.5;fuel=100;score=0;speed=.004;objs.clear();tick=0;over=false;});}
  void step(){
    if(over)return;
    tick++;score+=.08;fuel-=.025;speed=min(.009,.004+score/300000);
    if(tick%85==0)objs.add(_Obj(rnd.nextDouble()*.75+.12,-.08,rnd.nextInt(5)==0));
    for(final o in objs)o.y+=speed;
    for(final o in List<_Obj>.of(objs)){
      if(o.y>.82&&o.y<.94&&(o.x-planeX).abs()<.11){
        if(o.fuel){fuel=min(100,fuel+30);GameFeedback.capture();objs.remove(o);}
        else{fuel-=28;GameFeedback.error();objs.remove(o);}
      }else if(o.y>1.1)objs.remove(o);
    }
    if(fuel<=0){fuel=0;over=true;GameFeedback.lose();}
    if(mounted)setState((){});
  }
  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:const Color(0xFF06233D),
    appBar:AppBar(title:const Text('طائرة الوقود'),backgroundColor:const Color(0xFF06233D),foregroundColor:Colors.white,
      actions:[Padding(padding:const EdgeInsets.all(12),child:Text('${score.floor()} م',style:const TextStyle(fontWeight:FontWeight.w900))) ]),
    body:SafeArea(child:Column(children:[
      Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:6),child:Row(children:[
        const Icon(Icons.local_gas_station,color:Colors.amber),const SizedBox(width:7),
        Expanded(child:LinearProgressIndicator(value:fuel/100,minHeight:10,borderRadius:BorderRadius.circular(8))),
        const SizedBox(width:8),Text('${fuel.floor()}%',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900))
      ])),
      Expanded(child:Padding(padding:const EdgeInsets.all(10),child:LayoutBuilder(builder:(context,c)=>GestureDetector(
        onPanUpdate:(d)=>setState(()=>planeX=(planeX+d.delta.dx/c.maxWidth).clamp(.08,.92)),
        onTapDown:(d)=>setState(()=>planeX=(d.localPosition.dx/c.maxWidth).clamp(.08,.92)),
        child:CustomPaint(size:Size.infinite,painter:_PlanePainter(planeX:planeX,objs:objs,score:score,over:over))
      )))),
      if(over) Padding(padding:const EdgeInsets.all(10),child:SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:reset,icon:const Icon(Icons.refresh),label:const Text('إعادة المحاولة'))))
    ]))
  );
}
class _Obj{_Obj(this.x,this.y,this.fuel);final double x;double y;final bool fuel;}
class _PlanePainter extends CustomPainter{
  const _PlanePainter({required this.planeX,required this.objs,required this.score,required this.over});
  final double planeX,score;final List<_Obj> objs;final bool over;
  @override void paint(Canvas c,Size s){
    final sky=Paint()..shader=const LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Color(0xFF4FC3F7),Color(0xFFB3E5FC),Color(0xFF0D7E53)]).createShader(Offset.zero&s);
    c.drawRect(Offset.zero&s,sky);
    for(int i=0;i<8;i++){final y=((i*130+score*6)%s.height);c.drawOval(Rect.fromCenter(center:Offset((i%2==0?.18:.78)*s.width,y),width:90,height:28),Paint()..color=Colors.white.withOpacity(.55));}
    for(final o in objs){
      final p=Offset(o.x*s.width,o.y*s.height);
      if(o.fuel){c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center:p,width:38,height:52),const Radius.circular(8)),Paint()..color=Colors.amber);c.drawRect(Rect.fromCenter(center:p,width:10,height:25),Paint()..color=Colors.black54);}
      else{c.drawCircle(p,26,Paint()..color=const Color(0xFF5D4037));c.drawCircle(p-const Offset(7,5),6,Paint()..color=Colors.white12);}
    }
    final p=Offset(planeX*s.width,s.height*.88);
    final body=Path()..moveTo(p.dx,p.dy-36)..lineTo(p.dx+18,p.dy+26)..lineTo(p.dx,p.dy+17)..lineTo(p.dx-18,p.dy+26)..close();
    c.drawPath(body,Paint()..color=const Color(0xFFE53935));
    c.drawRect(Rect.fromCenter(center:Offset(p.dx,p.dy+4),width:72,height:11),Paint()..color=const Color(0xFFFFCDD2));
    c.drawCircle(Offset(p.dx,p.dy-10),7,Paint()..color=const Color(0xFF90CAF9));
    if(over){c.drawRect(Offset.zero&s,Paint()..color=Colors.black54);final t=TextPainter(text:const TextSpan(text:'انتهى الوقود',style:TextStyle(color:Colors.white,fontSize:28,fontWeight:FontWeight.w900)),textDirection:TextDirection.rtl)..layout();t.paint(c,Offset((s.width-t.width)/2,s.height*.45));}
  }
  @override bool shouldRepaint(covariant _PlanePainter old)=>true;
}
