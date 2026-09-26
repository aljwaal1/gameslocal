import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/audio_feedback.dart';
import '../../core/network/local_network_core.dart';
import '../../core/network/network_message.dart';
import '../../core/graphics/retro_pixels.dart';

class FuelPlaneGameScreen extends StatefulWidget {
  const FuelPlaneGameScreen({super.key, this.networkCore});
  final LocalNetworkCore? networkCore;
  @override State<FuelPlaneGameScreen> createState()=>_FuelPlaneGameScreenState();
}

enum _ObjType{fuel,rock,enemy}
class _Obj{_Obj({required this.x,required this.y,required this.type,required this.size});double x,y;final _ObjType type;final double size;}
class _Bullet{_Bullet(this.x,this.y,{this.remote=false});double x,y;final bool remote;}

class _FuelPlaneGameScreenState extends State<FuelPlaneGameScreen>{
  final Random rnd=Random();
  Timer? timer;
  double planeX=.42,remoteX=.58,fuel=100,remoteFuel=100,speed=.0065;
  int score=0,remoteScore=0,distance=0,level=1,best=0,fireCooldown=0,remoteFireCooldown=0,scoreTick=0;
  bool running=false,gameOver=false,alive=true,remoteAlive=true;
  int networkMode=0; // 0 مواجهة، 1 تعاون
  String resultText='';
  String effectText='';
  bool effectVisible=false;
  StreamSubscription<NetworkMessage>? networkSub;
  int syncTick=0;

  bool get isNetworkGame=>widget.networkCore!=null;
  bool get isHost=>widget.networkCore?.state.mode==LocalNetworkMode.host;
  String get localPlayerId=>widget.networkCore?.localPlayerId??'local';
  final List<_Obj> objects=[];
  final List<_Bullet> bullets=[];

  @override void initState(){super.initState();if(isNetworkGame)networkSub=widget.networkCore!.messages.listen(_onNetworkMessage);}
  @override void dispose(){networkSub?.cancel();timer?.cancel();super.dispose();}

  void start(){
    if(isNetworkGame&&!isHost){widget.networkCore?.sendMove(<String,dynamic>{'action':'plane_start_request'},senderId:localPlayerId);return;}
    timer?.cancel();
    setState((){
      planeX=.42;remoteX=.58;fuel=100;remoteFuel=100;speed=.0065;score=0;remoteScore=0;distance=0;level=1;fireCooldown=0;remoteFireCooldown=0;scoreTick=0;
      running=true;gameOver=false;alive=true;remoteAlive=true;resultText='';objects.clear();bullets.clear();
    });
    timer=Timer.periodic(const Duration(milliseconds:30),(_)=>tick());
    if(isNetworkGame&&isHost)_sendState('plane_start');
  }

  void tick(){
    if(!running)return;
    if(isNetworkGame&&!isHost)return;
    var event=0;
    distance++;scoreTick++;
    if(scoreTick>=12){score++;scoreTick=0;}
    if(alive)fuel-=.045;
    if(isNetworkGame&&remoteAlive)remoteFuel-=.045;
    level=1+distance~/1500;
    speed=min(.018,.0065+level*.0009);

    if(alive){
      if(fireCooldown<=0){bullets.add(_Bullet(planeX,.745));fireCooldown=max(7,14-min(5,level~/2));event=1;}else{fireCooldown--;}
    }
    if(isNetworkGame&&remoteAlive){
      if(remoteFireCooldown<=0){bullets.add(_Bullet(remoteX,.745,remote:true));remoteFireCooldown=max(7,14-min(5,level~/2));}else{remoteFireCooldown--;}
    }

    final spawn=.018+min(.018,level*.002);
    if(rnd.nextDouble()<spawn){
      final roll=rnd.nextDouble();
      final type=roll<.25?_ObjType.fuel:(roll<.78?_ObjType.rock:_ObjType.enemy);
      objects.add(_Obj(x:.12+rnd.nextDouble()*.76,y:-.08,type:type,size:type == _ObjType.fuel ? .052 : .066));
    }

    for(final o in objects){o.y+=speed;}
    for(final b in bullets){b.y-=.040;}
    objects.removeWhere((o)=>o.y>1.12);
    bullets.removeWhere((b)=>b.y<-.08);

    final hitObjects=<_Obj>[],hitBullets=<_Bullet>[];
    for(final b in bullets){
      for(final o in objects){
        if(o.type!=_ObjType.fuel&&(b.x-o.x).abs()<o.size&&(b.y-o.y).abs()<o.size){
          hitObjects.add(o);hitBullets.add(b);if(b.remote){remoteScore+=75;}else{score+=75;}event=2;break;
        }
      }
    }
    objects.removeWhere(hitObjects.contains);bullets.removeWhere(hitBullets.contains);

    for(final o in List<_Obj>.of(objects)){
      if(alive&&(planeX-o.x).abs()<o.size*.92&&(.82-o.y).abs()<o.size*.92){
        if(o.type==_ObjType.fuel){fuel=min(100,fuel+22);score+=120;objects.remove(o);event=3;}
        else{fuel=0;alive=false;event=4;}
      }else if(isNetworkGame&&remoteAlive&&(remoteX-o.x).abs()<o.size*.92&&(.82-o.y).abs()<o.size*.92){
        if(o.type==_ObjType.fuel){remoteFuel=min(100,remoteFuel+22);remoteScore+=120;objects.remove(o);event=3;}
        else{remoteFuel=0;remoteAlive=false;event=4;}
      }
    }

    if(alive&&fuel<=0){fuel=0;alive=false;event=4;}
    if(isNetworkGame&&remoteAlive&&remoteFuel<=0){remoteFuel=0;remoteAlive=false;event=4;}

    final shouldEnd=isNetworkGame
        ? (networkMode==0?(!alive||!remoteAlive):(!alive&&!remoteAlive))
        : !alive;
    if(shouldEnd){
      running=false;gameOver=true;timer?.cancel();best=max(best,score);
      if(isNetworkGame){
        resultText=networkMode==1
            ? 'انتهت المهمة التعاونية • مجموع النقاط '+(score+remoteScore).toString()
            : (!alive&&!remoteAlive?'تعادل':(!alive?'فاز اللاعب الآخر':'فزت بالمواجهة'));
      }
      _showEffect('💥 انتهت الجولة');
      GameFeedback.lose(GameAudioTheme.plane);
    }else if(event==2){_showEffect('💥 إصابة!');GameFeedback.capture(GameAudioTheme.plane);}
    else if(event==3){_showEffect('⛽ + وقود');GameFeedback.win(GameAudioTheme.plane);}
    else if(event==1&&distance%90==0){GameFeedback.move(GameAudioTheme.plane);}

    if(isNetworkGame&&isHost&&++syncTick%2==0)_sendState('plane_state');
    if(mounted)setState((){});
  }

  void setPlane(double dx,double width){
    if(!running||width<=0||!alive)return;
    setState(()=>planeX=(dx/width).clamp(.08,.92));
    if(isNetworkGame&&!isHost){
      widget.networkCore?.sendMove(<String,dynamic>{'action':'plane_control','x':planeX},senderId:localPlayerId);
    }
  }

  void _sendState(String action){
    widget.networkCore?.sendMove(<String,dynamic>{
      'action':action,'mode':networkMode,
      'planeX':planeX,'remoteX':remoteX,'fuel':fuel,'remoteFuel':remoteFuel,
      'score':score,'remoteScore':remoteScore,'distance':distance,'level':level,
      'running':running,'gameOver':gameOver,'alive':alive,'remoteAlive':remoteAlive,'resultText':resultText,
      'objects':objects.map((o)=><String,dynamic>{'x':o.x,'y':o.y,'type':o.type.index,'size':o.size}).toList(),
      'bullets':bullets.map((b)=><String,dynamic>{'x':b.x,'y':b.y,'remote':b.remote}).toList(),
    },senderId:localPlayerId);
  }

  void _onNetworkMessage(NetworkMessage m){
    if(!mounted||m.senderId==localPlayerId||m.type!=NetworkMessageType.move)return;
    final action=m.payload['action']?.toString();
    if(action=='plane_start_request'&&isHost){start();return;}
    if(action=='plane_control'&&isHost){
      final x=(m.payload['x'] as num?)?.toDouble();
      if(x!=null){remoteX=x.clamp(.08,.92);setState((){});}
      return;
    }
    if(action=='plane_mode'&&isHost&&!running){
      networkMode=((m.payload['mode'] as num?)?.toInt()??0).clamp(0,1);
      _sendState('plane_state');return;
    }
    if((action=='plane_state'||action=='plane_start')&&!isHost){
      final rawObjects=m.payload['objects'] as List<dynamic>? ?? const [];
      final rawBullets=m.payload['bullets'] as List<dynamic>? ?? const [];
      final oldScore=score;
      final oldFuel=fuel;
      final wasAlive=alive;
      final wasGameOver=gameOver;
      setState((){
        networkMode=((m.payload['mode'] as num?)?.toInt()??networkMode).clamp(0,1);
        planeX=((m.payload['remoteX'] as num?)?.toDouble()??planeX).clamp(.08,.92);
        remoteX=((m.payload['planeX'] as num?)?.toDouble()??remoteX).clamp(.08,.92);
        fuel=(m.payload['remoteFuel'] as num?)?.toDouble()??fuel;
        remoteFuel=(m.payload['fuel'] as num?)?.toDouble()??remoteFuel;
        score=(m.payload['remoteScore'] as num?)?.toInt()??score;
        remoteScore=(m.payload['score'] as num?)?.toInt()??remoteScore;
        distance=(m.payload['distance'] as num?)?.toInt()??distance;
        level=(m.payload['level'] as num?)?.toInt()??level;
        running=m.payload['running']==true;gameOver=m.payload['gameOver']==true;
        alive=m.payload['remoteAlive']!=false;remoteAlive=m.payload['alive']!=false;
        final hostText=(m.payload['resultText']??'').toString();
        resultText=hostText=='فزت بالمواجهة'?'فاز اللاعب الآخر':hostText=='فاز اللاعب الآخر'?'فزت بالمواجهة':hostText;
        objects
          ..clear()
          ..addAll(rawObjects.whereType<Map>().map((e)=>_Obj(
            x:(e['x'] as num).toDouble(),y:(e['y'] as num).toDouble(),
            type:_ObjType.values[(e['type'] as num).toInt().clamp(0,_ObjType.values.length-1)],
            size:(e['size'] as num).toDouble())));
        bullets
          ..clear()
          ..addAll(rawBullets.whereType<Map>().map((e)=>_Bullet(
            (e['x'] as num).toDouble(),(e['y'] as num).toDouble(),remote:e['remote']!=true)));
      });
      if(wasAlive&&!alive){_showEffect('💥 طائرتك تحطمت');GameFeedback.lose(GameAudioTheme.plane);}
      else if(!wasGameOver&&gameOver){_showEffect('🏁 انتهت الجولة');GameFeedback.lose(GameAudioTheme.plane);}
      else if(fuel>oldFuel+5){_showEffect('⛽ + وقود');GameFeedback.win(GameAudioTheme.plane);}
      else if(score>=oldScore+75){_showEffect('💥 إصابة!');GameFeedback.capture(GameAudioTheme.plane);}
    }
  }

  void setNetworkMode(int mode){
    if(running)return;
    setState(()=>networkMode=mode.clamp(0,1));
    if(isNetworkGame){
      widget.networkCore?.sendMove(<String,dynamic>{'action':'plane_mode','mode':networkMode},senderId:localPlayerId);
    }
  }

  void _showEffect(String text){
    if(!mounted)return;
    setState((){effectText=text;effectVisible=true;});
    Future<void>.delayed(const Duration(milliseconds:420),(){
      if(mounted)setState(()=>effectVisible=false);
    });
  }

  @override Widget build(BuildContext context){
    final fuelColor=fuel>50?Colors.greenAccent:(fuel>25?Colors.orangeAccent:Colors.redAccent);
    return Scaffold(
      backgroundColor:const Color(0xFF050D1A),
      appBar:AppBar(title:const Text('طائرة الوقود'),backgroundColor:const Color(0xFF050D1A),foregroundColor:Colors.white),
      body:SafeArea(child:Column(children:[
        Padding(padding:const EdgeInsets.symmetric(horizontal:14,vertical:8),child:Column(children:[
          Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[
            Text('نقاطك: '+score.toString(),style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),
            if(isNetworkGame)Text('الآخر: '+remoteScore.toString(),style:const TextStyle(color:Color(0xFFFF8A3D),fontWeight:FontWeight.bold)),
            Text('المرحلة: '+level.toString(),style:const TextStyle(color:Colors.white70)),
            if(!isNetworkGame)Text('الأفضل: '+best.toString(),style:const TextStyle(color:Colors.amber,fontWeight:FontWeight.bold))
          ]),
          if(isNetworkGame&&!running)Padding(padding:const EdgeInsets.only(top:7),child:SegmentedButton<int>(segments:const [ButtonSegment(value:0,label:Text('مواجهة')),ButtonSegment(value:1,label:Text('تعاون'))],selected:{networkMode},onSelectionChanged:(v)=>setNetworkMode(v.first))),
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
              CustomPaint(size:Size.infinite,painter:_PlanePainter(planeX:planeX,remoteX:isNetworkGame?remoteX:null,objects:objects,bullets:bullets,level:level,distance:distance)),
              Positioned.fill(child:IgnorePointer(child:AnimatedOpacity(
                opacity:effectVisible?1:0,
                duration:const Duration(milliseconds:120),
                child:Center(child:Container(
                  padding:const EdgeInsets.symmetric(horizontal:18,vertical:10),
                  decoration:BoxDecoration(color:Colors.black.withAlpha(150),borderRadius:BorderRadius.circular(18),border:Border.all(color:Colors.white24)),
                  child:Text(effectText,style:const TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.w900,shadows:[Shadow(color:Colors.black,blurRadius:10)])),
                )),
              ))),
              if(!running)Center(child:Container(
                padding:const EdgeInsets.all(22),
                decoration:BoxDecoration(color:Colors.black.withAlpha(180),borderRadius:BorderRadius.circular(22)),
                child:Column(mainAxisSize:MainAxisSize.min,children:[
                  Text(gameOver?'انتهت الجولة':'جاهز للطيران؟',style:const TextStyle(color:Colors.white,fontSize:27,fontWeight:FontWeight.w900)),
                  const SizedBox(height:7),
                  Text(gameOver?(isNetworkGame?resultText:'نقاطك: '+score.toString()):(isNetworkGame?(networkMode==0?'مواجهة: آخر طائرة تبقى تفوز':'تعاون: اجمعا النقاط وابقيا معًا'):'حرّك الطائرة بإصبعك — الإطلاق تلقائي'),textAlign:TextAlign.center,style:const TextStyle(color:Colors.white70)),
                  const SizedBox(height:14),
                  FilledButton.icon(onPressed:start,icon:const Icon(Icons.play_arrow_rounded),label:Text(gameOver?'إعادة اللعب':'ابدأ'))
                ])
              ))
            ])
          ))
        )),
        Container(
          margin:const EdgeInsets.fromLTRB(14,10,14,12),padding:const EdgeInsets.fromLTRB(14,10,14,12),
          decoration:BoxDecoration(color:Colors.black.withAlpha(55),borderRadius:BorderRadius.circular(22),border:Border.all(color:Colors.white12)),
          child:Column(children:[
            Row(children:[
              const Icon(Icons.mouse_rounded,size:20,color:Colors.white70),
              const SizedBox(width:8),
              Expanded(child:Text(running?'حرّك المقبض مثل الماوس':'اضغط ابدأ ثم استخدم شريط التحكم',style:const TextStyle(color:Colors.white70,fontWeight:FontWeight.bold)))
            ]),
            SliderTheme(
              data:SliderTheme.of(context).copyWith(trackHeight:12,thumbShape:const RoundSliderThumbShape(enabledThumbRadius:18),overlayShape:const RoundSliderOverlayShape(overlayRadius:26),activeTrackColor:Colors.lightBlueAccent,inactiveTrackColor:Colors.white24,thumbColor:Colors.white,overlayColor:Colors.lightBlueAccent.withAlpha(45)),
              child:Slider(value:planeX.clamp(.08,.92),min:.08,max:.92,onChanged:running?(v){setState(()=>planeX=v);if(isNetworkGame&&!isHost)widget.networkCore?.sendMove(<String,dynamic>{'action':'plane_control','x':planeX},senderId:localPlayerId);}:null),
            )
          ])
        )
      ]))
    );
  }
}

class _PlanePainter extends CustomPainter{
  const _PlanePainter({required this.planeX,this.remoteX,required this.objects,required this.bullets,required this.level,required this.distance});
  final double planeX;final double? remoteX;final List<_Obj> objects;final List<_Bullet> bullets;final int level,distance;

  @override void paint(Canvas canvas,Size size){
    final w=size.width,h=size.height,bg=Offset.zero&size;
    canvas.drawRect(bg,Paint()..shader=const LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Color(0xff061022),Color(0xff0a2e4f),Color(0xff061022)]).createShader(bg));
    final star=Paint()..color=Colors.white.withOpacity(.55);
    for(var i=0;i<48;i++){
      final x=((i*73+level*17)%w).toDouble();
      final y=((i*41+level*13)%(h*.45)).toDouble();
      canvas.drawRect(Rect.fromLTWH(x,y,i%6==0?3:2,i%6==0?3:2),star);
    }
    final river=Path()..moveTo(w*.22,0)..quadraticBezierTo(w*.13,h*.26,w*.28,h*.50)..quadraticBezierTo(w*.42,h*.72,w*.16,h)..lineTo(w*.84,h)..quadraticBezierTo(w*.58,h*.72,w*.72,h*.50)..quadraticBezierTo(w*.87,h*.26,w*.78,0)..close();
    canvas.drawPath(river,Paint()..color=const Color(0xff145d87));
    canvas.drawPath(river,Paint()..style=PaintingStyle.stroke..strokeWidth=3..color=const Color(0xff7dd3fc).withOpacity(.35));
    final bank=Paint()..color=const Color(0xff0f3b1d);
    for(var i=0;i<14;i++){
      final y=((i*64+level*9)%(h+80)).toDouble()-40;
      canvas.drawRect(Rect.fromLTWH(0,y,w*.12,18),bank);
      canvas.drawRect(Rect.fromLTWH(w*.88,y+28,w*.12,18),bank);
    }
    for(final b in bullets){
      canvas.drawCircle(Offset(b.x*w,b.y*h),5,Paint()..color=const Color(0xfffff176));
      canvas.drawCircle(Offset(b.x*w,b.y*h),11,Paint()..color=const Color(0x2AFFF176));
    }
    for(final o in objects){
      final p=Offset(o.x*w,o.y*h),px=max(2.2,o.size*w/9);
      if(o.type==_ObjType.fuel){
        RetroPixels.draw(canvas,p,px,const ['..GG..','..YY..','.YYYY.','.YRR.','.YRR.','.YYYY.','..GG..'],{'G':const Color(0xff22c55e),'Y':const Color(0xffffd166),'R':const Color(0xffef4444)},shadow:3);
      }else if(o.type==_ObjType.enemy){
        RetroPixels.draw(canvas,p,px,const ['...R...','..RRR..','.RBRBR.','RRBBB.R','..BBB..','.B...B.'],{'R':const Color(0xffef4444),'B':const Color(0xff374151)},shadow:3);
      }else{
        RetroPixels.draw(canvas,p,px,const ['..SS..','.SSSS.','SSSSSS','SDSDSS','.SSSS.','..SS..'],{'S':const Color(0xff94a3b8),'D':const Color(0xff334155)},shadow:3);
      }
    }
    _plane(canvas,Offset(planeX*w,h*.82),max(3,w*.012),const Color(0xff38bdf8));
    if(remoteX!=null)_plane(canvas,Offset(remoteX!*w,h*.82),max(3,w*.012),const Color(0xffff8a3d));
    final scan=Paint()..color=Colors.black.withOpacity(.12);
    for(double y=0;y<h;y+=5)canvas.drawRect(Rect.fromLTWH(0,y,w,1),scan);
  }

  void _plane(Canvas c,Offset p,double px,Color color){
    RetroPixels.draw(c,p,px,const ['.....C.....','....CCC....','....YYY....','B..YYYYY..B','BBYYYYYYYBB','..RYYYR...','...Y.Y....','..B...B...'],{'C':const Color(0xffe0f2fe),'Y':color,'B':const Color(0xff2563eb),'R':const Color(0xffef4444)},shadow:4);
    c.drawCircle(p.translate(0,38),8+(level%3).toDouble(),Paint()..color=const Color(0xbfff7a18));
  }

  @override bool shouldRepaint(covariant _PlanePainter old)=>true;
}
