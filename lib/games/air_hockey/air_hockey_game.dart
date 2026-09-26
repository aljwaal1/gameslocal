import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/audio_feedback.dart';
import '../../core/network/local_network_core.dart';
import '../../core/network/network_message.dart';

class AirHockeyGameScreen extends StatefulWidget {
  const AirHockeyGameScreen({super.key, this.networkCore});
  final LocalNetworkCore? networkCore;
  @override State<AirHockeyGameScreen> createState()=>_AirHockeyGameScreenState();
}

class _AirHockeyGameScreenState extends State<AirHockeyGameScreen> with SingleTickerProviderStateMixin {
  late final AnimationController clock;
  final Stopwatch physicsClock=Stopwatch();
  final Map<int,_PointerSample> pointerSamples={};
  final Map<int,bool> pointerLower={};

  Offset puck=const Offset(.5,.5), velocity=const Offset(.24,.34);
  Offset bottom=const Offset(.5,.84), top=const Offset(.5,.16);
  Offset bottomVelocity=Offset.zero, topVelocity=Offset.zero;
  int bottomScore=0, topScore=0, lastMicros=0;
  double slowTime=0;
  bool botMode=true, playing=true, bottomContact=false, topContact=false;
  bool goalFlash=false;
  String goalEffect='';
  StreamSubscription<NetworkMessage>? networkSub;
  int syncTick=0;

  bool get isNetworkGame=>widget.networkCore!=null;
  bool get isHost=>widget.networkCore?.state.mode==LocalNetworkMode.host;
  String get localPlayerId=>widget.networkCore?.localPlayerId??'local';

  @override void initState(){
    super.initState();
    if(isNetworkGame){botMode=false;networkSub=widget.networkCore!.messages.listen(_onNetworkMessage);}
    physicsClock.start();
    clock=AnimationController(vsync:this,duration:const Duration(seconds:1))..addListener(_tick)..repeat();
  }
  @override void dispose(){networkSub?.cancel();clock.dispose();physicsClock.stop();super.dispose();}

  Offset _limit(Offset v,double max)=>v.distance>max?v/v.distance*max:v;

  void _tick(){
    if(!mounted||!playing)return;
    if(isNetworkGame&&!isHost)return;
    final now=physicsClock.elapsedMicroseconds;
    if(lastMicros==0){lastMicros=now;return;}
    final dt=((now-lastMicros)/1000000).clamp(.001,.034).toDouble();lastMicros=now;
    var p=puck+velocity*dt;
    var v=velocity*pow(.985,dt*60).toDouble();

    if(botMode&&p.dy<.64){
      final attacking=p.dy<.46;
      final targetX=(p.dx+v.dx*(attacking ? .10 : .18)).clamp(.10,.90).toDouble();
      final targetY=(attacking?(p.dy+.045).clamp(.10,.39):.16).toDouble();
      final delta=Offset(targetX-top.dx,targetY-top.dy);
      final maxStep=(attacking?1.15:.72)*dt;
      final step=delta.distance>maxStep?delta/delta.distance*maxStep:delta;
      final old=top;
      top=Offset((top.dx+step.dx).clamp(.10,.90),(top.dy+step.dy).clamp(.08,.43));
      topVelocity=(top-old)/dt;
    }else if(botMode){
      topVelocity*=pow(.20,dt).toDouble();
    }

    const radius=.042;
    if(p.dx<radius||p.dx>1-radius){
      v=Offset(-v.dx*.94,v.dy);p=Offset(p.dx.clamp(radius,1-radius),p.dy);GameFeedback.move(GameAudioTheme.hockey);
    }
    final inGoal=p.dx>.31&&p.dx<.69;
    if(!inGoal&&p.dy<radius){v=Offset(v.dx,-v.dy*.94);p=Offset(p.dx,radius);GameFeedback.move(GameAudioTheme.hockey);}
    if(!inGoal&&p.dy>1-radius){v=Offset(v.dx,-v.dy*.94);p=Offset(p.dx,1-radius);GameFeedback.move(GameAudioTheme.hockey);}

    final lower=_collide(bottom,p,bottomVelocity,bottomContact,v,false);p=lower.position;v=lower.velocity;bottomContact=lower.contact;
    final upper=_collide(top,p,topVelocity,topContact,v,true);p=upper.position;v=upper.velocity;topContact=upper.contact;
    bottomVelocity*=pow(.08,dt).toDouble();topVelocity*=pow(.08,dt).toDouble();

    if(p.dy<-.05&&inGoal){bottomScore++;_goal(true);return;}
    if(p.dy>1.05&&inGoal){topScore++;_goal(false);return;}

    if(v.distance<.075){slowTime+=dt;}else{slowTime=0;}
    if(slowTime>.85){final dir=p.dy<.5?1.0:-1.0;v=Offset((.5-p.dx)*.45,dir*.30);slowTime=0;}
    setState((){puck=p;velocity=v;});
    if(isNetworkGame&&isHost&&++syncTick%2==0)_sendState();
  }

  ({Offset position,Offset velocity,bool contact}) _collide(Offset paddle,Offset p,Offset paddleSpeed,bool wasTouching,Offset current,bool upper){
    final d=p-paddle, distance=d.distance;
    if(distance>=.108||distance==0)return(position:p,velocity:current,contact:false);
    final n=d/distance;
    if(wasTouching)return(position:p,velocity:current,contact:true);
    final relative=current-paddleSpeed;
    final approach=relative.dx*n.dx+relative.dy*n.dy;
    if(approach>=0&&paddleSpeed.distance<.08)return(position:p,velocity:current,contact:true);
    var result=relative-n*(1.96*approach)+paddleSpeed*1.42;
    final minimum=upper && botMode ? .48 : .25;
    if(result.distance<minimum)result=n*minimum+paddleSpeed*.72;
    result=_limit(result,2.65);GameFeedback.capture(GameAudioTheme.hockey);
    return(position:paddle+n*.109,velocity:result,contact:true);
  }

  void _sendState(){
    widget.networkCore?.sendMove(<String,dynamic>{
      'action':'hockey_state',
      'puckX':puck.dx,'puckY':puck.dy,
      'bottomX':bottom.dx,'bottomY':bottom.dy,
      'topX':top.dx,'topY':top.dy,
      'bottomScore':bottomScore,'topScore':topScore,
      'playing':playing,
    },senderId:localPlayerId);
  }

  void _onNetworkMessage(NetworkMessage m){
    if(!mounted||m.senderId==localPlayerId||m.type!=NetworkMessageType.move)return;
    final action=m.payload['action']?.toString();
    if(action=='hockey_control'&&isHost){
      final x=(m.payload['x'] as num?)?.toDouble();
      final y=(m.payload['y'] as num?)?.toDouble();
      if(x==null||y==null)return;
      final old=top;
      top=Offset(x.clamp(.10,.90),(1-y).clamp(.08,.44));
      topVelocity=(top-old)*18;
      setState((){});
      return;
    }
    if(action=='hockey_reset'){
      if(isHost){_reset(send:false);_sendState();}
      return;
    }
    if(action=='hockey_state'&&!isHost){
      final px=(m.payload['puckX'] as num?)?.toDouble()??.5;
      final py=(m.payload['puckY'] as num?)?.toDouble()??.5;
      final bx=(m.payload['bottomX'] as num?)?.toDouble()??.5;
      final by=(m.payload['bottomY'] as num?)?.toDouble()??.84;
      final tx=(m.payload['topX'] as num?)?.toDouble()??.5;
      final ty=(m.payload['topY'] as num?)?.toDouble()??.16;
      final nextBottom=(m.payload['topScore'] as num?)?.toInt()??bottomScore;
      final nextTop=(m.payload['bottomScore'] as num?)?.toInt()??topScore;
      final scored=nextBottom!=bottomScore||nextTop!=topScore;
      final localScored=nextBottom>bottomScore;
      setState((){
        puck=Offset(px,1-py);
        bottom=Offset(tx,1-ty);
        top=Offset(bx,1-by);
        bottomScore=nextBottom;
        topScore=nextTop;
        playing=m.payload['playing']!=false;
        if(scored){
          goalEffect=localScored?'هدف لك!':'هدف للخصم!';
          goalFlash=true;
        }
      });
      if(scored){
        GameFeedback.goal(GameAudioTheme.hockey);
        Future<void>.delayed(const Duration(milliseconds:420),(){if(mounted)setState(()=>goalFlash=false);});
      }
    }
  }

  void _goal(bool human){
    GameFeedback.goal(GameAudioTheme.hockey);
    goalEffect=human?'هدف لك!':'هدف للخصم!';
    goalFlash=true;
    Future<void>.delayed(const Duration(milliseconds:420),(){if(mounted)setState(()=>goalFlash=false);});
    if(bottomScore>=5||topScore>=5)playing=false;
    setState((){
      puck=const Offset(.5,.5);
      velocity=Offset((Random().nextDouble()-.5)*.32,human ? .34 : -.34);
      bottomContact=false;topContact=false;slowTime=0;
    });
  }

  void _reset({bool send=true}){
    if(isNetworkGame&&!isHost&&send){
      widget.networkCore?.sendMove(<String,dynamic>{'action':'hockey_reset'},senderId:localPlayerId);
      return;
    }
    setState((){
      bottomScore=0;topScore=0;playing=true;puck=const Offset(.5,.5);velocity=const Offset(.24,.34);
      bottom=const Offset(.5,.84);top=const Offset(.5,.16);bottomVelocity=Offset.zero;topVelocity=Offset.zero;
      bottomContact=false;topContact=false;slowTime=0;lastMicros=physicsClock.elapsedMicroseconds;pointerSamples.clear();pointerLower.clear();
    });
    if(isNetworkGame&&isHost&&send)_sendState();
  }

  Offset _norm(PointerEvent e,BoxConstraints c)=>Offset((e.localPosition.dx/c.maxWidth).clamp(.10,.90),(e.localPosition.dy/c.maxHeight).clamp(.08,.92));
  void _down(PointerDownEvent e,BoxConstraints c){
    final pos=_norm(e,c), lower=pos.dy>=.5;
    if(isNetworkGame&&!lower)return;
    if(!lower&&botMode)return;
    pointerLower[e.pointer]=lower;pointerSamples[e.pointer]=_PointerSample(pos,e.timeStamp);
    if(lower){bottom=Offset(pos.dx,pos.dy.clamp(.56,.92));bottomVelocity=Offset.zero;}
    else{top=Offset(pos.dx,pos.dy.clamp(.08,.44));topVelocity=Offset.zero;}
    setState((){});
  }
  void _move(PointerMoveEvent e,BoxConstraints c){
    final lower=pointerLower[e.pointer], sample=pointerSamples[e.pointer];if(lower==null||sample==null)return;
    final raw=_norm(e,c);final next=lower?Offset(raw.dx,raw.dy.clamp(.56,.92)):Offset(raw.dx,raw.dy.clamp(.08,.44));
    final dt=(e.timeStamp-sample.time).inMicroseconds/1000000;if(dt<=0)return;
    final instant=_limit((next-sample.position)/dt,3.2);
    if(lower){
      bottomVelocity=bottomVelocity*.28+instant*.72;bottom=next;
      if(isNetworkGame&&!isHost){widget.networkCore?.sendMove(<String,dynamic>{'action':'hockey_control','x':bottom.dx,'y':bottom.dy},senderId:localPlayerId);}
    }else{topVelocity=topVelocity*.28+instant*.72;top=next;}
    pointerSamples[e.pointer]=_PointerSample(next,e.timeStamp);setState((){});
  }
  void _up(PointerEvent e){pointerSamples.remove(e.pointer);pointerLower.remove(e.pointer);}

  @override Widget build(BuildContext context){
    final subtitle=playing?'الأول الذي يسجل 5 أهداف يفوز':(bottomScore>topScore?'فاز اللاعب 1 🎉':'فاز '+(botMode?'الروبوت':'اللاعب 2')+' 🎉');
    return Scaffold(
      backgroundColor:const Color(0xFF061321),
      appBar:AppBar(title:const Text('الهوكي الهوائي'),backgroundColor:const Color(0xFF061321),foregroundColor:Colors.white,actions:[IconButton(onPressed:_reset,icon:const Icon(Icons.refresh_rounded))]),
      body:SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(12,8,12,12),child:Column(children:[
        Text(subtitle,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:16)),
        const SizedBox(height:8),
        Row(children:[
          if(!isNetworkGame)Expanded(child:ChoiceChip(label:const Text('ضد الروبوت'),selected:botMode,onSelected:(_){botMode=true;_reset();})),
          if(!isNetworkGame)const SizedBox(width:8),
          Expanded(child:ChoiceChip(label:Text(isNetworkGame?'عبر الشبكة':'مع صديق'),selected:isNetworkGame||!botMode,onSelected:isNetworkGame?null:(_){botMode=false;_reset();}))
        ]),
        const SizedBox(height:8),
        Row(mainAxisAlignment:MainAxisAlignment.center,children:[
          _Score(name:'اللاعب 1',score:bottomScore,color:const Color(0xFF22D3EE)),
          const SizedBox(width:14),
          _Score(name:botMode?'الروبوت':'اللاعب 2',score:topScore,color:const Color(0xFFF472B6))
        ]),
        const SizedBox(height:8),
        Expanded(child:Stack(children:[
          Positioned.fill(child:LayoutBuilder(builder:(context,c)=>Listener(onPointerDown:(e)=>_down(e,c),onPointerMove:(e)=>_move(e,c),onPointerUp:_up,onPointerCancel:_up,child:CustomPaint(size:Size(c.maxWidth,c.maxHeight),painter:_HockeyPainter(puck,bottom,top))))),
          Positioned.fill(child:IgnorePointer(child:AnimatedOpacity(
            opacity:goalFlash?1:0,
            duration:const Duration(milliseconds:120),
            child:Container(
              decoration:BoxDecoration(borderRadius:BorderRadius.circular(30),color:Colors.white.withAlpha(32)),
              alignment:Alignment.center,
              child:Text(goalEffect,style:const TextStyle(color:Colors.white,fontSize:34,fontWeight:FontWeight.w900,shadows:[Shadow(color:Colors.black54,blurRadius:12)])),
            ),
          )))
        ])),
        if(!playing)Padding(padding:const EdgeInsets.only(top:8),child:SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:_reset,icon:const Icon(Icons.replay_rounded),label:const Text('مباراة جديدة'))))
      ])))
    );
  }
}

class _PointerSample{const _PointerSample(this.position,this.time);final Offset position;final Duration time;}
class _Score extends StatelessWidget{
  const _Score({required this.name,required this.score,required this.color});
  final String name;final int score;final Color color;
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:14,vertical:7),decoration:BoxDecoration(color:color.withAlpha(25),border:Border.all(color:color),borderRadius:BorderRadius.circular(16)),child:Text(name+'  '+score.toString(),style:TextStyle(color:color,fontWeight:FontWeight.w900,fontSize:16)));
}

class _HockeyPainter extends CustomPainter{
  const _HockeyPainter(this.puck,this.bottom,this.top);
  final Offset puck,bottom,top;
  Offset p(Offset x,Size s)=>Offset(x.dx*s.width,x.dy*s.height);
  @override void paint(Canvas c,Size s){
    final rect=Offset.zero&s;
    c.drawRRect(RRect.fromRectAndRadius(rect,const Radius.circular(30)),Paint()..shader=const LinearGradient(colors:[Color(0xFF071B33),Color(0xFF0B3556),Color(0xFF071B33)],begin:Alignment.topCenter,end:Alignment.bottomCenter).createShader(rect));
    final line=Paint()..color=const Color(0x8838BDF8)..style=PaintingStyle.stroke..strokeWidth=3;
    c.drawLine(Offset(0,s.height/2),Offset(s.width,s.height/2),line);c.drawCircle(Offset(s.width/2,s.height/2),s.width*.14,line);
    _goal(c,s,true,const Color(0xFFF472B6));_goal(c,s,false,const Color(0xFF22D3EE));
    _disc(c,p(top,s),s.width*.065,const Color(0xFFF472B6));_disc(c,p(bottom,s),s.width*.065,const Color(0xFF22D3EE));_disc(c,p(puck,s),s.width*.035,Colors.white);
  }
  void _goal(Canvas c,Size s,bool topGoal,Color color){
    final y=topGoal?0.0:s.height,inward=topGoal?1.0:-1.0,width=s.width*.38,left=(s.width-width)/2;
    final frame=Paint()..color=color..style=PaintingStyle.stroke..strokeWidth=6..strokeCap=StrokeCap.round;
    c.drawLine(Offset(left,y),Offset(left,y+inward*24),frame);c.drawLine(Offset(left+width,y),Offset(left+width,y+inward*24),frame);c.drawLine(Offset(left,y+inward*24),Offset(left+width,y+inward*24),frame);
    final net=Paint()..color=color.withAlpha(95)..strokeWidth=1.2;
    for(var i=1;i<6;i++){final x=left+width*i/6;c.drawLine(Offset(x,y),Offset(x,y+inward*24),net);}
    for(var i=1;i<3;i++){final ny=y+inward*24*i/3;c.drawLine(Offset(left,ny),Offset(left+width,ny),net);}
  }
  void _disc(Canvas c,Offset center,double r,Color color){
    c.drawCircle(center,r,Paint()..color=const Color(0x55000000)..maskFilter=const MaskFilter.blur(BlurStyle.normal,8));
    c.drawCircle(center,r,Paint()..shader=RadialGradient(colors:[Colors.white,color]).createShader(Rect.fromCircle(center:center,radius:r)));
  }
  @override bool shouldRepaint(covariant _HockeyPainter old)=>true;
}
