import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/audio_feedback.dart';
import '../../core/network/local_network_core.dart';
import '../../core/network/network_message.dart';
import '../../core/graphics/retro_pixels.dart';

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

    // Exact traffic generation from the tested carsgame Retro Road.
    final spawn=.018+min(.014,day*.0022);
    if(rnd.nextDouble()<spawn){
      const lanes=[.28,.40,.52,.64,.76];
      final lane=rnd.nextInt(lanes.length);
      cars.add(_Traffic(
        lanes[lane]+(rnd.nextDouble()-.5)*.020,
        -.10,
        lane,
        .70+rnd.nextDouble()*.42,
      ));
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
    _sendRoadControl();
  }

  void dragRoad(double dx,double width){
    if(!running||localCrashed||width<=0)return;
    setState(()=>playerX=(dx/width).clamp(.16,.84).toDouble());
    _sendRoadControl();
  }

  void _sendRoadControl(){
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
      final oldWeather=weather;
      final oldDay=day;
      final wasCrashed=localCrashed;
      final wasGameOver=gameOver;
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
      if(!wasCrashed&&localCrashed){_showEffect('💥 حادث!');GameFeedback.lose(GameAudioTheme.road);}
      else if(!wasGameOver&&gameOver){
        _showEffect(resultText);
        if(resultText=='فزت بالسباق'){GameFeedback.win(GameAudioTheme.road);}
        else if(resultText.startsWith('تعادل')){GameFeedback.tap(GameAudioTheme.road);}
        else{GameFeedback.lose(GameAudioTheme.road);}
      }
      else if(day>oldDay){_showEffect('🏁 يوم جديد!');GameFeedback.win(GameAudioTheme.road);}
      else if(weather!=oldWeather){_showEffect('🌦 '+weather.label);GameFeedback.tap(GameAudioTheme.road);}
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
          child:LayoutBuilder(builder:(context,roadBox)=>Stack(children:[
            Positioned.fill(child:GestureDetector(
              behavior:HitTestBehavior.opaque,
              onPanDown:(d)=>dragRoad(d.localPosition.dx,roadBox.maxWidth),
              onPanUpdate:(d)=>dragRoad(d.localPosition.dx,roadBox.maxWidth),
              child:CustomPaint(size:Size.infinite,painter:_RoadPainter(playerX:playerX,opponentX:isNetworkGame?remoteX:null,cars:cars,weather:weather,day:day,score:score)),
            )),
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
          ]))
        )),
        Padding(padding:const EdgeInsets.all(12),child:Row(children:[
          Expanded(child:FilledButton.icon(onPressed:running?()=>move(1):null,icon:const Icon(Icons.arrow_forward_rounded),label:const Text('يمين'))),
          const SizedBox(width:10),
          Expanded(child:FilledButton.icon(onPressed:running?()=>move(-1):null,icon:const Icon(Icons.arrow_back_rounded),label:const Text('يسار')))
        ]))
      ]))
    );
  }
}

class _RoadPainter extends CustomPainter{
  const _RoadPainter({required this.playerX,this.opponentX,required this.cars,required this.weather,required this.day,required this.score});
  final double playerX;final double? opponentX;final List<_Traffic> cars;final _Weather weather;final int day,score;

  @override
  void paint(Canvas canvas,Size size){
    final w=size.width,h=size.height,bg=Offset.zero&size;
    canvas.drawRect(bg,Paint()..shader=LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:_skyColors(),stops:const[0,.42,1]).createShader(bg));
    _sunMoon(canvas,size);
    _horizon(canvas,size);
    _road(canvas,size);
    _roadSideDetails(canvas,size);
    _laneMarks(canvas,size);

    for(final car in cars){
      final p=Offset(car.x*w,car.y*h);
      _car(canvas,p,_scaleForY(car.y,w),enemy:true,lane:car.lane);
    }

    final pc=Offset(playerX*w,h*.84);
    if(weather==_Weather.night||weather==_Weather.fog||weather==_Weather.rain)_headLights(canvas,size,pc);
    _car(canvas,pc,max(5.2,w*.018),enemy:false,lane:0);

    if(opponentX!=null){
      final op=Offset(opponentX!*w,h*.84);
      _car(canvas,op,max(5.2,w*.018),enemy:false,lane:4,overrideBody:const Color(0xffff8a3d));
    }

    _weatherParticles(canvas,size);
    _weatherOverlay(canvas,size);
    _hudGlow(canvas,size);
    _crt(canvas,size);
  }

  double _scaleForY(double y,double w){
    final t=y.clamp(0.0,1.0);
    return max(2.2,w*(.006+t*.014));
  }

  List<Color> _skyColors()=>switch(weather){
    _Weather.sunset=>const[Color(0xff26113f),Color(0xffd94679),Color(0xfff59e0b)],
    _Weather.night=>const[Color(0xff020617),Color(0xff0a1025),Color(0xff172033)],
    _Weather.fog=>const[Color(0xff64748b),Color(0xffa3b1c2),Color(0xffd7dde6)],
    _Weather.snow=>const[Color(0xff9cc8f5),Color(0xffdbeafe),Color(0xffffffff)],
    _Weather.rain=>const[Color(0xff0f172a),Color(0xff334155),Color(0xff475569)],
    _Weather.day=>const[Color(0xff0ea5e9),Color(0xff67e8f9),Color(0xff86efac)],
  };

  void _sunMoon(Canvas c,Size s){
    if(weather==_Weather.night){
      c.drawCircle(Offset(s.width*.78,s.height*.13),24,Paint()..color=const Color(0xffe5e7eb));
      c.drawCircle(Offset(s.width*.70,s.height*.11),2,Paint()..color=Colors.white70);
      c.drawCircle(Offset(s.width*.26,s.height*.08),2,Paint()..color=Colors.white60);
      c.drawCircle(Offset(s.width*.48,s.height*.17),1.6,Paint()..color=Colors.white60);
    }else if(weather==_Weather.sunset){
      c.drawCircle(Offset(s.width*.72,s.height*.19),32,Paint()..color=const Color(0xffffd166));
    }else if(weather==_Weather.day){
      c.drawCircle(Offset(s.width*.78,s.height*.16),30,Paint()..color=const Color(0xfffff3b0));
    }
  }

  void _horizon(Canvas c,Size s){
    final mountain=Paint()..color=weather==_Weather.night?const Color(0xff0b1220):const Color(0xff1d4ed8).withOpacity(.32);
    final far=Path()
      ..moveTo(0,s.height*.36)
      ..lineTo(s.width*.15,s.height*.25)
      ..lineTo(s.width*.31,s.height*.35)
      ..lineTo(s.width*.47,s.height*.22)
      ..lineTo(s.width*.67,s.height*.36)
      ..lineTo(s.width*.83,s.height*.26)
      ..lineTo(s.width,s.height*.34)
      ..lineTo(s.width,s.height*.48)
      ..lineTo(0,s.height*.48)
      ..close();
    c.drawPath(far,mountain);
    final groundColor=weather==_Weather.snow?const Color(0xfff8fafc):weather==_Weather.rain?const Color(0xff1e3a2f):const Color(0xff166534);
    c.drawRect(Rect.fromLTWH(0,s.height*.40,s.width,s.height*.60),Paint()..color=groundColor);
  }

  void _road(Canvas c,Size s){
    final w=s.width,h=s.height;
    final road=Path()..moveTo(w*.46,h*.37)..lineTo(w*.54,h*.37)..lineTo(w*.96,h)..lineTo(w*.04,h)..close();
    c.drawPath(road,Paint()..shader=const LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Color(0xff111827),Color(0xff1f2937),Color(0xff020617)]).createShader(Rect.fromLTWH(0,h*.37,w,h*.63)));
    c.drawPath(road,Paint()..style=PaintingStyle.stroke..strokeWidth=5..color=Colors.white.withOpacity(.35));

    final shoulderLeft=Path()..moveTo(w*.43,h*.37)..lineTo(w*.46,h*.37)..lineTo(w*.04,h)..lineTo(0,h)..close();
    final shoulderRight=Path()..moveTo(w*.54,h*.37)..lineTo(w*.57,h*.37)..lineTo(w,h)..lineTo(w*.96,h)..close();
    final shoulderPaint=Paint()..color=weather==_Weather.snow?const Color(0xffdbeafe):const Color(0xff0f5132);
    c.drawPath(shoulderLeft,shoulderPaint);c.drawPath(shoulderRight,shoulderPaint);
  }

  void _roadSideDetails(Canvas c,Size s){
    final w=s.width,h=s.height;
    for(var i=0;i<10;i++){
      final y=((i*72+score*3)%(h+120)).toDouble()-60;
      if(y<h*.38)continue;
      final t=(y/h).clamp(0.0,1.0);
      final leftX=w*(.43-.37*t),rightX=w*(.57+.37*t);
      _post(c,Offset(leftX,y),4+t*7);
      _post(c,Offset(rightX,y+28),4+t*7);
    }
  }

  void _post(Canvas c,Offset o,double s){
    c.drawRect(Rect.fromCenter(center:o,width:s,height:s*3.2),Paint()..color=const Color(0xfff8fafc));
    c.drawRect(Rect.fromCenter(center:o.translate(0,-s),width:s*1.4,height:s*.7),Paint()..color=const Color(0xffef4444));
  }

  void _laneMarks(Canvas c,Size s){
    final p=Paint()..color=Colors.white.withOpacity(weather == _Weather.fog ? .28 : .70);
    for(var i=0;i<11;i++){
      final y=((i*78+score*3)%(s.height+110)).toDouble()-55;
      if(y<s.height*.38)continue;
      final t=(y/s.height).clamp(0.0,1.0);
      final len=16+t*48,width=3+t*7;
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center:Offset(s.width*.5,y),width:width,height:len),const Radius.circular(4)),p);
    }
  }

  void _headLights(Canvas c,Size s,Offset pc){
    final light=Path()..moveTo(pc.dx-22,pc.dy-12)..lineTo(pc.dx-s.width*.23,pc.dy-s.height*.37)..lineTo(pc.dx+s.width*.23,pc.dy-s.height*.37)..lineTo(pc.dx+22,pc.dy-12)..close();
    c.drawPath(light,Paint()..color=const Color(0xfffff3b0).withOpacity(weather == _Weather.fog ? .22 : .16));
  }

  void _weatherParticles(Canvas c,Size s){
    if(weather!=_Weather.snow&&weather!=_Weather.rain)return;
    for(var i=0;i<90;i++){
      final x=((i*61+score*2)%s.width).toDouble(),y=((i*47+score*5)%s.height).toDouble();
      if(weather==_Weather.rain)c.drawLine(Offset(x,y),Offset(x-6,y+18),Paint()..color=const Color(0xff93c5fd).withOpacity(.70)..strokeWidth=1.5);
      else c.drawCircle(Offset(x,y),i%3==0?2.4:1.4,Paint()..color=Colors.white.withOpacity(.90));
    }
  }

  void _car(Canvas c,Offset center,double px,{required bool enemy,required int lane,Color? overrideBody}){
    final colors=[const Color(0xffef4444),const Color(0xffffd166),const Color(0xff22c55e),const Color(0xffa78bfa),const Color(0xfff97316)];
    final body=overrideBody??(enemy?colors[lane.abs()%colors.length]:const Color(0xff38bdf8));
    final glass=enemy?const Color(0xffdbeafe):const Color(0xffe0f2fe);
    RetroPixels.draw(c,center,px,const[
      '...WW...',
      '..WBBW..',
      '.WBBBBW.',
      'RBBBBBBR',
      'BBBBBBBB',
      'KBBBBBBK',
      'KBB..BBK',
      '.BB..BB.',
    ],{'W':glass,'B':body,'R':enemy?const Color(0xfffff176):const Color(0xffef4444),'K':const Color(0xff020617)},shadow:4);
  }

  void _weatherOverlay(Canvas c,Size s){
    if(weather==_Weather.fog)c.drawRect(Offset.zero&s,Paint()..color=Colors.white.withOpacity(.30));
    if(weather==_Weather.night)c.drawRect(Offset.zero&s,Paint()..color=Colors.black.withOpacity(.18));
    if(weather==_Weather.rain)c.drawRect(Offset.zero&s,Paint()..color=Colors.blueGrey.withOpacity(.12));
  }

  void _hudGlow(Canvas c,Size s)=>c.drawRect(Rect.fromLTWH(0,0,s.width,s.height),Paint()..style=PaintingStyle.stroke..strokeWidth=10..color=Colors.black.withOpacity(.20));
  void _crt(Canvas c,Size s){final p=Paint()..color=Colors.black.withOpacity(.10);for(double y=0;y<s.height;y+=5)c.drawRect(Rect.fromLTWH(0,y,s.width,1),p);}
  @override bool shouldRepaint(covariant _RoadPainter old)=>true;
}
