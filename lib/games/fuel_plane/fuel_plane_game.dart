import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/audio_feedback.dart';
import '../../core/network/local_network_core.dart';

class FuelPlaneGameScreen extends StatefulWidget {
  const FuelPlaneGameScreen({super.key, this.networkCore});
  final LocalNetworkCore? networkCore;
  @override State<FuelPlaneGameScreen> createState()=>_FuelPlaneGameScreenState();
}

enum _ObjType{fuel,rock,enemy}
class _Obj{_Obj({required this.x,required this.y,required this.type,required this.size});double x,y;final _ObjType type;final double size;}
class _Bullet{_Bullet(this.x,this.y);double x,y;}

class _FuelPlaneGameScreenState extends State<FuelPlaneGameScreen>{
  final Random rnd=Random();
  Timer? timer;
  double planeX=.5,fuel=100,speed=.0065;
  int score=0,distance=0,level=1,best=0,fireCooldown=0,scoreTick=0;
  bool running=false,gameOver=false;
  final List<_Obj> objects=[];
  final List<_Bullet> bullets=[];

  @override void dispose(){timer?.cancel();super.dispose();}

  void start(){
    timer?.cancel();
    setState((){
      planeX=.5;fuel=100;speed=.0065;score=0;distance=0;level=1;fireCooldown=0;scoreTick=0;
      running=true;gameOver=false;objects.clear();bullets.clear();
    });
    timer=Timer.periodic(const Duration(milliseconds:30),(_)=>tick());
  }

  void tick(){
    if(!running)return;
    var event=0;
    distance++;scoreTick++;
    if(scoreTick>=12){score++;scoreTick=0;}
    fuel-=.045;
    level=1+distance~/1500;
    speed=min(.018,.0065+level*.0009);

    if(fireCooldown<=0){
      bullets.add(_Bullet(planeX,.745));
      fireCooldown=max(7,14-min(5,level~/2));
      event=1;
    }else{fireCooldown--;}

    final spawn=.018+min(.018,level*.002);
    if(rnd.nextDouble()<spawn){
      final roll=rnd.nextDouble();
      final type=roll<.25?_ObjType.fuel:(roll<.78?_ObjType.rock:_ObjType.enemy);
      objects.add(_Obj(x:.12+rnd.nextDouble()*.76,y:-.08,type:type,size:type==_ObjType.fuel?.052:.066));
    }

    for(final o in objects){o.y+=speed;}
    for(final b in bullets){b.y-=.040;}
    objects.removeWhere((o)=>o.y>1.12);
    bullets.removeWhere((b)=>b.y<-.08);

    final hitObjects=<_Obj>[],hitBullets=<_Bullet>[];
    for(final b in bullets){
      for(final o in objects){
        if(o.type!=_ObjType.fuel&&(b.x-o.x).abs()<o.size&&(b.y-o.y).abs()<o.size){
          hitObjects.add(o);hitBullets.add(b);score+=75;event=2;break;
        }
      }
    }
    objects.removeWhere(hitObjects.contains);bullets.removeWhere(hitBullets.contains);

    for(final o in List<_Obj>.of(objects)){
      if((planeX-o.x).abs()<o.size*.92&&(.82-o.y).abs()<o.size*.92){
        if(o.type==_ObjType.fuel){
          fuel=min(100,fuel+22);score+=120;objects.remove(o);event=3;
        }else{
          fuel=0;event=4;
        }
      }
    }

    if(fuel<=0){
      fuel=0;running=false;gameOver=true;best=max(best,score);timer?.cancel();GameFeedback.lose();
    }else if(event==2){
      GameFeedback.capture();
    }else if(event==3){
      GameFeedback.win();
    }else if(event==1&&distance%90==0){
      GameFeedback.move();
    }
    if(mounted)setState((){});
  }

  void setPlane(double dx,double width){
    if(!running||width<=0)return;
    setState(()=>planeX=(dx/width).clamp(.08,.92));
  }

  @override Widget build(BuildContext context){
    final fuelColor=fuel>50?Colors.greenAccent:(fuel>25?Colors.orangeAccent:Colors.redAccent);
    return Scaffold(
      backgroundColor:const Color(0xFF050D1A),
      appBar:AppBar(title:const Text('طائرة الوقود'),backgroundColor:const Color(0xFF050D1A),foregroundColor:Colors.white),
      body:SafeArea(child:Column(children:[
        Padding(padding:const EdgeInsets.symmetric(horizontal:14,vertical:8),child:Column(children:[
          Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[
            Text('النقاط: '+score.toString(),style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),
            Text('المرحلة: '+level.toString(),style:const TextStyle(color:Colors.white70)),
            Text('الأفضل: '+best.toString(),style:const TextStyle(color:Colors.amber,fontWeight:FontWeight.bold))
          ]),
          const SizedBox(height:8),
          ClipRRect(borderRadius:BorderRadius.circular(20),child:LinearProgressIndicator(value:(fuel.clamp(0,100))/100,minHeight:12,valueColor:AlwaysStoppedAnimation(fuelColor),backgroundColor:Colors.white12))
        ])),
        Expanded(child:Container(
          margin:const EdgeInsets.symmetric(horizontal:12),clipBehavior:Clip.antiAlias,
          decoration:BoxDecoration(borderRadius:BorderRadius.circular(22),border:Border.all(color:Colors.white12)),
          child:LayoutBuilder(builder:(context,c)=>GestureDetector(
            behavior:HitTestBehavior.opaque,
            onPanDown:(d)=>setPlane(d.localPosition.dx,c.maxWidth),
            onPanUpdate:(d)=>setPlane(d.localPosition.dx,c.maxWidth),
            child:Stack(children:[
              CustomPaint(size:Size.infinite,painter:_PlanePainter(planeX:planeX,objects:objects,bullets:bullets,level:level,distance:distance)),
              if(!running)Center(child:Container(
                padding:const EdgeInsets.all(22),
                decoration:BoxDecoration(color:Colors.black.withAlpha(180),borderRadius:BorderRadius.circular(22)),
                child:Column(mainAxisSize:MainAxisSize.min,children:[
                  Text(gameOver?'انتهت الجولة':'جاهز للطيران؟',style:const TextStyle(color:Colors.white,fontSize:27,fontWeight:FontWeight.w900)),
                  const SizedBox(height:7),
                  Text(gameOver?'نقاطك: '+score.toString():'حرّك الطائرة بإصبعك — الإطلاق تلقائي',textAlign:TextAlign.center,style:const TextStyle(color:Colors.white70)),
                  const SizedBox(height:14),
                  FilledButton.icon(onPressed:start,icon:const Icon(Icons.play_arrow_rounded),label:Text(gameOver?'إعادة اللعب':'ابدأ'))
                ])
              ))
            ])
          ))
        )),
        Container(
          margin:const EdgeInsets.fromLTRB(14,10,14,12),padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),
          decoration:BoxDecoration(color:Colors.white.withAlpha(12),borderRadius:BorderRadius.circular(18),border:Border.all(color:Colors.white12)),
          child:Row(children:[
            const Icon(Icons.touch_app_rounded,color:Colors.lightBlueAccent),
            const SizedBox(width:8),
            Expanded(child:Text(running?'اسحب الطائرة يمينًا ويسارًا • اجمع الوقود • دمّر العوائق':'اضغط ابدأ لبدء الجولة',style:const TextStyle(color:Colors.white70,fontWeight:FontWeight.w700,fontSize:12)))
          ])
        )
      ]))
    );
  }
}

class _PlanePainter extends CustomPainter{
  const _PlanePainter({required this.planeX,required this.objects,required this.bullets,required this.level,required this.distance});
  final double planeX;final List<_Obj> objects;final List<_Bullet> bullets;final int level,distance;
  @override void paint(Canvas c,Size s){
    final rect=Offset.zero&s;
    c.drawRect(rect,Paint()..shader=const LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Color(0xFF061022),Color(0xFF0A2E4F),Color(0xFF061022)]).createShader(rect));
    final star=Paint()..color=Colors.white54;
    for(var i=0;i<42;i++){
      final x=((i*73+level*17)%s.width).toDouble();
      final y=((i*41+distance*.35)%(s.height*.46)).toDouble();
      c.drawCircle(Offset(x,y),i%7==0?1.8:1.0,star);
    }
    final river=Path()
      ..moveTo(s.width*.22,0)..quadraticBezierTo(s.width*.13,s.height*.26,s.width*.28,s.height*.50)
      ..quadraticBezierTo(s.width*.42,s.height*.72,s.width*.16,s.height)
      ..lineTo(s.width*.84,s.height)
      ..quadraticBezierTo(s.width*.58,s.height*.72,s.width*.72,s.height*.50)
      ..quadraticBezierTo(s.width*.87,s.height*.26,s.width*.78,0)..close();
    c.drawPath(river,Paint()..color=const Color(0xFF145D87));
    c.drawPath(river,Paint()..style=PaintingStyle.stroke..strokeWidth=3..color=const Color(0x557DD3FC));

    for(final b in bullets){
      final p=Offset(b.x*s.width,b.y*s.height);
      c.drawCircle(p,4,Paint()..color=const Color(0xFFFFF176));
      c.drawCircle(p,10,Paint()..color=const Color(0x33FFF176));
    }
    for(final o in objects){
      final p=Offset(o.x*s.width,o.y*s.height),r=max(14.0,o.size*s.width*.72);
      if(o.type==_ObjType.fuel){
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center:p,width:r*1.1,height:r*1.5),const Radius.circular(7)),Paint()..color=const Color(0xFFFFC107));
        c.drawRect(Rect.fromCenter(center:p,width:r*.24,height:r*.75),Paint()..color=const Color(0xFFE53935));
      }else if(o.type==_ObjType.enemy){
        final path=Path()..moveTo(p.dx,p.dy-r)..lineTo(p.dx+r*.8,p.dy+r*.75)..lineTo(p.dx,p.dy+r*.35)..lineTo(p.dx-r*.8,p.dy+r*.75)..close();
        c.drawPath(path,Paint()..color=const Color(0xFFEF4444));
        c.drawCircle(p.translate(0,-r*.15),r*.18,Paint()..color=const Color(0xFF90CAF9));
      }else{
        c.drawCircle(p,r,Paint()..color=const Color(0xFF94A3B8));
        c.drawCircle(p.translate(-r*.28,-r*.2),r*.18,Paint()..color=const Color(0xFF475569));
      }
    }

    final p=Offset(planeX*s.width,s.height*.82),scale=max(1.0,s.width/390);
    final body=Path()..moveTo(p.dx,p.dy-34*scale)..lineTo(p.dx+17*scale,p.dy+24*scale)..lineTo(p.dx,p.dy+16*scale)..lineTo(p.dx-17*scale,p.dy+24*scale)..close();
    c.drawPath(body,Paint()..color=const Color(0xFF38BDF8));
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center:p.translate(0,4*scale),width:72*scale,height:11*scale),const Radius.circular(4)),Paint()..color=const Color(0xFF2563EB));
    c.drawCircle(p.translate(0,-10*scale),7*scale,Paint()..color=const Color(0xFFE0F2FE));
    c.drawCircle(p.translate(0,34*scale),7*scale,Paint()..color=const Color(0xFFFF7A18));

    final scan=Paint()..color=Colors.black12;
    for(double y=0;y<s.height;y+=6){c.drawRect(Rect.fromLTWH(0,y,s.width,1),scan);}
  }
  @override bool shouldRepaint(covariant _PlanePainter old)=>true;
}
