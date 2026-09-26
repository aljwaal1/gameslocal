import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/audio_feedback.dart';
import '../../core/network/local_network_core.dart';
import '../../core/network/network_message.dart';

class RetroRoadGameScreen extends StatefulWidget{
  const RetroRoadGameScreen({super.key,this.networkCore});
  final LocalNetworkCore? networkCore;
  @override State<RetroRoadGameScreen> createState()=>_RetroRoadGameScreenState();
}

enum _Weather{day,sunset,night,fog,snow,rain}
extension on _Weather{
  String get label=>switch(this){
    _Weather.day=>'نهار',_Weather.sunset=>'غروب',_Weather.night=>'ليل',_Weather.fog=>'ضباب',_Weather.snow=>'ثلج',_Weather.rain=>'مطر'
  };
  double get steering=>switch(this){_Weather.snow=>1.45,_Weather.rain=>1.22,_=>1.0};
}
class _Traffic{_Traffic(this.x,this.y,this.lane,this.factor);double x,y;final int lane;final double factor;}

class _RetroRoadGameScreenState extends State<RetroRoadGameScreen>{
  final Random rnd=Random();
  Timer? timer;
  double playerX=.5,remoteX=.5,speed=.0068;
  int score=0,distance=0,day=1,passed=0,best=0,scoreTick=0;
  bool running=false,gameOver=false,localCrashed=false,remoteCrashed=false;
  String resultText='';
  String effectText='';
  bool effectVisible=false;
  StreamSubscription<NetworkMessage>? networkSub;
  int syncTick=0;

  bool get isNetworkGame=>widget.networkCore!=null;
  bool get isHost=>widget.networkCore?.state.mode==LocalNetworkMode.host;
  String get localPlayerId=>widget.networkCore?.localPlayerId??'local';
  _Weather weather=_Weather.day,lastWeather=_Weather.day;
  final List<_Traffic> cars=[];

  @override void initState(){super.initState();if(isNetworkGame)networkSub=widget.networkCore!.messages.listen(_onNetworkMessage);}
  @override void dispose(){networkSub?.cancel();timer?.cancel();super.dispose();}

  void start(){
    if(isNetworkGame&&!isHost){widget.networkCore?.sendMove(<String,dynamic>{'action':'road_start_request'},senderId:localPlayerId);return;}
    timer?.cancel();
    setState((){
      playerX=.5;remoteX=.5;speed=.0068;score=0;distance=0;day=1;passed=0;scoreTick=0;running=true;gameOver=false;localCrashed=false;remoteCrashed=false;resultText='';
      weather=_Weather.day;lastWeather=_Weather.day;cars.clear();
    });
    timer=Timer.periodic(const Duration(milliseconds:30),(_)=>tick());
    if(isNetworkGame&&isHost)_sendState('road_start');
  }

  void tick(){
    if(!running)return;
    if(isNetworkGame&&!isHost)return;
    var event=0;
    distance++;scoreTick++;
    if(scoreTick>=10){score++;scoreTick=0;}
    speed=min(.020,.0068+day*.0008+distance/220000);
    updateWeather();
    if(weather!=lastWeather){event=2;lastWeather=weather;}

    final spawn=.018+min(.014,day*.0022);
    if(rnd.nextDouble()<spawn){
      const lanes=[.28,.40,.52,.64,.76];
      final lane=rnd.nextInt(lanes.length);
      cars.add(_Traffic(lanes[lane]+(rnd.nextDouble()-.5)*.020,-.10,lane,.70+rnd.nextDouble()*.42));
    }

    for(final car in cars){car.y+=speed*car.factor;}
    final before=cars.length;
    cars.removeWhere((c)=>c.y>1.15);
    final removed=before-cars.length;
    if(removed>0){passed+=removed;score+=removed*100;event=1;}

    if(passed>=40){
      day++;passed=0;cars.clear();score+=750;event=3;
    }

    if(isNetworkGame){
      if(!localCrashed&&hasCrashAt(playerX)){localCrashed=true;event=4;}
      if(!remoteCrashed&&hasCrashAt(remoteX)){remoteCrashed=true;event=4;}
      if(localCrashed||remoteCrashed){
        running=false;gameOver=true;timer?.cancel();
        resultText=localCrashed&&remoteCrashed?'تعادل — اصطدمتما معًا':(localCrashed?'فاز اللاعب الآخر':'فزت بالسباق');
      }
    }else if(hasCrashAt(playerX)){
      running=false;gameOver=true;best=max(best,score);timer?.cancel();event=4;
    }

    if(event==4){_showEffect('💥 حادث!');GameFeedback.lose(GameAudioTheme.road);}
    else if(event==3){_showEffect('🏁 يوم جديد!');GameFeedback.win(GameAudioTheme.road);}
    else if(event==2){_showEffect('🌦 '+weather.label);GameFeedback.tap(GameAudioTheme.road);}
    else if(event==1&&passed%5==0){GameFeedback.capture(GameAudioTheme.road);}
    if(isNetworkGame&&isHost&&++syncTick%2==0)_sendState('road_state');
    if(mounted)setState((){});
  }

  void updateWeather(){
    final p=passed/40;
    weather=p<.16?_Weather.day:p<.31?_Weather.sunset:p<.47?_Weather.night:p<.63?_Weather.fog:p<.81?_Weather.snow:_Weather.rain;
  }

  bool hasCrashAt(double x){
    for(final c in cars){
      if((x-c.x).abs()<.050&&(.82-c.y).abs()<.066)return true;
    }
    return false;
  }

  void move(double dir){
    if(!running||localCrashed)return;
    setState(()=>playerX=(playerX+dir*.034*weather.steering).clamp(.16,.84));
    if(isNetworkGame&&!isHost){
      widget.networkCore?.sendMove(<String,dynamic>{'action':'road_control','x':playerX},senderId:localPlayerId);
    }
  }

  void _sendState(String action){
    widget.networkCore?.sendMove(<String,dynamic>{
      'action':action,'playerX':playerX,'remoteX':remoteX,'score':score,'distance':distance,
      'day':day,'passed':passed,'weather':weather.index,'running':running,'gameOver':gameOver,
      'localCrashed':localCrashed,'remoteCrashed':remoteCrashed,'resultText':resultText,
      'cars':cars.map((e)=><String,dynamic>{'x':e.x,'y':e.y,'lane':e.lane,'factor':e.factor}).toList(),
    },senderId:localPlayerId);
  }

  void _onNetworkMessage(NetworkMessage m){
    if(!mounted||m.senderId==localPlayerId||m.type!=NetworkMessageType.move)return;
    final action=m.payload['action']?.toString();
    if(action=='road_start_request'&&isHost){start();return;}
    if(action=='road_control'&&isHost){
      final x=(m.payload['x'] as num?)?.toDouble();
      if(x!=null){remoteX=x.clamp(.16,.84);setState((){});}
      return;
    }
    if((action=='road_state'||action=='road_start')&&!isHost){
      final rawCars=m.payload['cars'] as List<dynamic>? ?? const [];
      setState((){
        playerX=((m.payload['remoteX'] as num?)?.toDouble()??playerX).clamp(.16,.84);
        remoteX=((m.payload['playerX'] as num?)?.toDouble()??remoteX).clamp(.16,.84);
        score=(m.payload['score'] as num?)?.toInt()??score;
        distance=(m.payload['distance'] as num?)?.toInt()??distance;
        day=(m.payload['day'] as num?)?.toInt()??day;
        passed=(m.payload['passed'] as num?)?.toInt()??passed;
        final wi=(m.payload['weather'] as num?)?.toInt()??0;
        weather=_Weather.values[wi.clamp(0,_Weather.values.length-1)];
        running=m.payload['running']==true;
        gameOver=m.payload['gameOver']==true;
        localCrashed=m.payload['remoteCrashed']==true;
        remoteCrashed=m.payload['localCrashed']==true;
        final hostText=(m.payload['resultText']??'').toString();
        resultText=hostText=='فزت بالسباق'?'فاز اللاعب الآخر':hostText=='فاز اللاعب الآخر'?'فزت بالسباق':hostText;
        cars
          ..clear()
          ..addAll(rawCars.whereType<Map>().map((e)=>_Traffic(
            (e['x'] as num).toDouble(),(e['y'] as num).toDouble(),
            (e['lane'] as num).toInt(),(e['factor'] as num).toDouble())));
      });
    }
  }

  void _showEffect(String text){
    if(!mounted)return;
    setState((){effectText=text;effectVisible=true;});
    Future<void>.delayed(const Duration(milliseconds:460),(){
      if(mounted)setState(()=>effectVisible=false);
    });
  }

  @override Widget build(BuildContext context){
    final progress=(passed/40).clamp(0.0,1.0);
    return Scaffold(
      backgroundColor:const Color(0xFF090D13),
      appBar:AppBar(title:const Text('طريق التحمل'),backgroundColor:const Color(0xFF090D13),foregroundColor:Colors.white),
      body:SafeArea(child:Column(children:[
        Padding(padding:const EdgeInsets.symmetric(horizontal:14,vertical:8),child:Column(children:[
          Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[
            Text('النقاط: '+score.toString(),style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),
            Text('اليوم: '+day.toString(),style:const TextStyle(color:Colors.white70)),
            Text('الأفضل: '+best.toString(),style:const TextStyle(color:Colors.amber,fontWeight:FontWeight.bold))
          ]),
          const SizedBox(height:7),
          Row(children:[
            Expanded(child:ClipRRect(borderRadius:BorderRadius.circular(18),child:LinearProgressIndicator(value:progress,minHeight:11,backgroundColor:Colors.white12))),
            const SizedBox(width:9),
            Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),decoration:BoxDecoration(color:Colors.white10,borderRadius:BorderRadius.circular(12)),child:Text(weather.label,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800)))
          ])
        ])),
        Expanded(child:Container(
          margin:const EdgeInsets.symmetric(horizontal:12),clipBehavior:Clip.antiAlias,
          decoration:BoxDecoration(borderRadius:BorderRadius.circular(22),border:Border.all(color:Colors.white12)),
          child:Stack(children:[
            CustomPaint(size:Size.infinite,painter:_RoadPainter(playerX:playerX,opponentX:isNetworkGame?remoteX:null,cars:cars,weather:weather,day:day,score:score)),
            Positioned.fill(child:IgnorePointer(child:AnimatedOpacity(
              opacity:effectVisible?1:0,
              duration:const Duration(milliseconds:120),
              child:Container(
                alignment:Alignment.center,
                color:effectText.contains('حادث')?Colors.red.withAlpha(42):Colors.transparent,
                child:Container(
                  padding:const EdgeInsets.symmetric(horizontal:18,vertical:10),
                  decoration:BoxDecoration(color:Colors.black.withAlpha(150),borderRadius:BorderRadius.circular(18),border:Border.all(color:Colors.white24)),
                  child:Text(effectText,style:const TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.w900,shadows:[Shadow(color:Colors.black,blurRadius:10)])),
                ),
              ),
            ))),
            if(!running)Center(child:Container(
              padding:const EdgeInsets.all(22),
              decoration:BoxDecoration(color:Colors.black.withAlpha(180),borderRadius:BorderRadius.circular(22)),
              child:Column(mainAxisSize:MainAxisSize.min,children:[
                Text(gameOver?'انتهى السباق':'جاهز للطريق؟',style:const TextStyle(color:Colors.white,fontSize:27,fontWeight:FontWeight.w900)),
                const SizedBox(height:7),
                Text(gameOver?(isNetworkGame?resultText:'نقاطك: '+score.toString()):(isNetworkGame?'سباق مباشر: تجنب السيارات وابقَ آخر سيارة':'تجاوز 40 سيارة لتنتقل إلى يوم جديد'),textAlign:TextAlign.center,style:const TextStyle(color:Colors.white70)),
                const SizedBox(height:14),
                FilledButton.icon(onPressed:start,icon:const Icon(Icons.play_arrow_rounded),label:Text(gameOver?'إعادة اللعب':'ابدأ'))
              ])
            ))
          ])
        )),
        Padding(padding:const EdgeInsets.all(12),child:Row(children:[
          Expanded(child:FilledButton.icon(onPressed:running?()=>move(-1):null,icon:const Icon(Icons.arrow_back_rounded),label:const Text('يسار'))),
          const SizedBox(width:10),
          Expanded(child:FilledButton.icon(onPressed:running?()=>move(1):null,icon:const Icon(Icons.arrow_forward_rounded),label:const Text('يمين')))
        ]))
      ]))
    );
  }
}

class _RoadPainter extends CustomPainter{
  const _RoadPainter({required this.playerX,this.opponentX,required this.cars,required this.weather,required this.day,required this.score});
  final double playerX;final double? opponentX;final List<_Traffic> cars;final _Weather weather;final int day,score;

  List<Color> sky()=>switch(weather){
    _Weather.sunset=>const[Color(0xFF26113F),Color(0xFFD94679),Color(0xFFF59E0B)],
    _Weather.night=>const[Color(0xFF020617),Color(0xFF0A1025),Color(0xFF172033)],
    _Weather.fog=>const[Color(0xFF64748B),Color(0xFFA3B1C2),Color(0xFFD7DDE6)],
    _Weather.snow=>const[Color(0xFF9CC8F5),Color(0xFFDBEAFE),Colors.white],
    _Weather.rain=>const[Color(0xFF0F172A),Color(0xFF334155),Color(0xFF475569)],
    _=>const[Color(0xFF0EA5E9),Color(0xFF67E8F9),Color(0xFF86EFAC)]
  };

  @override void paint(Canvas c,Size s){
    final bg=Offset.zero&s;
    c.drawRect(bg,Paint()..shader=LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:sky(),stops:const[0,.42,1]).createShader(bg));
    drawSky(c,s);drawHorizon(c,s);drawRoad(c,s);drawMarks(c,s);drawRoadside(c,s);

    for(final car in cars){
      final p=Offset(car.x*s.width,car.y*s.height);
      drawCar(c,p,max(12.0,s.width*(.014+car.y.clamp(0.0,1.0)*.026)),true,car.lane);
    }
    final pc=Offset(playerX*s.width,s.height*.82);
    if(weather==_Weather.night||weather==_Weather.fog||weather==_Weather.rain)drawLights(c,s,pc);
    drawCar(c,pc,max(19.0,s.width*.045),false,0);
    if(opponentX!=null){
      final op=Offset(opponentX!*s.width,s.height*.82);
      drawCar(c,op,max(18.0,s.width*.042),false,4);
    }
    drawWeather(c,s);

    final scan=Paint()..color=Colors.black12;
    for(double y=0;y<s.height;y+=6){c.drawRect(Rect.fromLTWH(0,y,s.width,1),scan);}
  }

  void drawSky(Canvas c,Size s){
    if(weather==_Weather.night){
      c.drawCircle(Offset(s.width*.78,s.height*.13),24,Paint()..color=const Color(0xFFE5E7EB));
      for(final p in [const Offset(.22,.08),const Offset(.48,.17),const Offset(.67,.07)])c.drawCircle(Offset(p.dx*s.width,p.dy*s.height),2,Paint()..color=Colors.white70);
    }else if(weather==_Weather.sunset){
      c.drawCircle(Offset(s.width*.72,s.height*.19),32,Paint()..color=const Color(0xFFFFD166));
    }else if(weather==_Weather.day){
      c.drawCircle(Offset(s.width*.78,s.height*.16),30,Paint()..color=const Color(0xFFFFF3B0));
    }
  }

  void drawHorizon(Canvas c,Size s){
    final mountain=Path()..moveTo(0,s.height*.36)..lineTo(s.width*.15,s.height*.25)..lineTo(s.width*.31,s.height*.35)..lineTo(s.width*.47,s.height*.22)..lineTo(s.width*.67,s.height*.36)..lineTo(s.width*.83,s.height*.26)..lineTo(s.width,s.height*.34)..lineTo(s.width,s.height*.48)..lineTo(0,s.height*.48)..close();
    c.drawPath(mountain,Paint()..color=weather==_Weather.night?const Color(0xFF0B1220):const Color(0x551D4ED8));
    final ground=weather==_Weather.snow?const Color(0xFFF8FAFC):weather==_Weather.rain?const Color(0xFF1E3A2F):const Color(0xFF166534);
    c.drawRect(Rect.fromLTWH(0,s.height*.40,s.width,s.height*.60),Paint()..color=ground);
  }

  void drawRoad(Canvas c,Size s){
    final path=Path()..moveTo(s.width*.46,s.height*.37)..lineTo(s.width*.54,s.height*.37)..lineTo(s.width*.96,s.height)..lineTo(s.width*.04,s.height)..close();
    c.drawPath(path,Paint()..shader=const LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Color(0xFF111827),Color(0xFF1F2937),Color(0xFF020617)]).createShader(Rect.fromLTWH(0,s.height*.37,s.width,s.height*.63)));
    c.drawPath(path,Paint()..style=PaintingStyle.stroke..strokeWidth=4..color=Colors.white30);
  }

  void drawMarks(Canvas c,Size s){
    final p=Paint()..color=weather==_Weather.fog?Colors.white24:Colors.white70;
    for(var lane=1;lane<5;lane++){
      for(var i=0;i<10;i++){
        final y=((i*86+score*3)%(s.height+120)).toDouble()-60;
        if(y<s.height*.38)continue;
        final t=(y/s.height).clamp(0.0,1.0);
        final roadLeft=s.width*(.46-.42*t),roadRight=s.width*(.54+.42*t);
        final x=roadLeft+(roadRight-roadLeft)*lane/5;
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center:Offset(x,y),width:2+t*4,height:10+t*32),const Radius.circular(3)),p);
      }
    }
  }

  void drawRoadside(Canvas c,Size s){
    for(var i=0;i<10;i++){
      final y=((i*72+score*3)%(s.height+120)).toDouble()-60;if(y<s.height*.38)continue;
      final t=(y/s.height).clamp(0.0,1.0),left=s.width*(.43-.37*t),right=s.width*(.57+.37*t),h=6+t*16;
      for(final x in [left,right]){
        c.drawRect(Rect.fromCenter(center:Offset(x,y),width:h*.35,height:h),Paint()..color=Colors.white);
        c.drawRect(Rect.fromCenter(center:Offset(x,y-h*.32),width:h*.55,height:h*.22),Paint()..color=Colors.redAccent);
      }
    }
  }

  void drawLights(Canvas c,Size s,Offset p){
    final beam=Path()..moveTo(p.dx-20,p.dy-10)..lineTo(p.dx-s.width*.23,p.dy-s.height*.36)..lineTo(p.dx+s.width*.23,p.dy-s.height*.36)..lineTo(p.dx+20,p.dy-10)..close();
    c.drawPath(beam,Paint()..color=const Color(0x33FFF3B0));
  }

  void drawCar(Canvas c,Offset p,double k,bool enemy,int lane){
    final colors=[const Color(0xFFEF4444),const Color(0xFFFFD166),const Color(0xFF22C55E),const Color(0xFFA78BFA),const Color(0xFFF97316)];
    final body=enemy?colors[lane%colors.length]:(lane==4?const Color(0xFFFF8A3D):const Color(0xFF38BDF8));
    final r=Rect.fromCenter(center:p,width:k*1.45,height:k*2.15);
    c.drawRRect(RRect.fromRectAndRadius(r,Radius.circular(k*.32)),Paint()..color=body);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center:p.translate(0,-k*.35),width:k*.92,height:k*.55),Radius.circular(k*.18)),Paint()..color=const Color(0xFFDDEAFE));
    c.drawRect(Rect.fromCenter(center:p.translate(0,k*.55),width:k*.92,height:k*.18),Paint()..color=enemy?Colors.amberAccent:Colors.redAccent);
    for(final x in [r.left,r.right]){
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center:Offset(x,p.dy-k*.45),width:k*.22,height:k*.48),Radius.circular(k*.08)),Paint()..color=Colors.black87);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center:Offset(x,p.dy+k*.45),width:k*.22,height:k*.48),Radius.circular(k*.08)),Paint()..color=Colors.black87);
    }
  }

  void drawWeather(Canvas c,Size s){
    if(weather==_Weather.fog)c.drawRect(Offset.zero&s,Paint()..color=Colors.white30);
    if(weather==_Weather.rain||weather==_Weather.snow){
      for(var i=0;i<90;i++){
        final x=((i*61+score*2)%s.width).toDouble(),y=((i*47+score*5)%s.height).toDouble();
        if(weather==_Weather.rain)c.drawLine(Offset(x,y),Offset(x-6,y+18),Paint()..color=const Color(0xAA93C5FD)..strokeWidth=1.5);
        else c.drawCircle(Offset(x,y),i%3==0?2.4:1.4,Paint()..color=Colors.white);
      }
    }
    if(weather==_Weather.night)c.drawRect(Offset.zero&s,Paint()..color=Colors.black12);
  }

  @override bool shouldRepaint(covariant _RoadPainter old)=>true;
}
