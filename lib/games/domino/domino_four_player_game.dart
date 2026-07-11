import 'dart:math';
import 'package:flutter/material.dart';
import 'domino_turn_order.dart';

class DominoFourPlayerScreen extends StatefulWidget {
  const DominoFourPlayerScreen({super.key});
  @override
  State<DominoFourPlayerScreen> createState() => _DominoFourPlayerScreenState();
}

class _DominoFourPlayerScreenState extends State<DominoFourPlayerScreen> {
  final turns = DominoTurnOrder(playerCount: 4);
  List<List<_Tile>> hands = [];
  final List<_Tile> board = [];
  int? left, right;
  int consecutivePasses = 0;
  bool gameFinished = false;
  String message = '';

  @override
  void initState() { super.initState(); _newGame(); }

  void _newGame() {
    final deck = <_Tile>[for (var a=0;a<=6;a++) for(var b=a;b<=6;b++) _Tile(a,b)]..shuffle(Random());
    hands = List.generate(4, (p) => deck.sublist(p*7, p*7+7));
    board.clear(); left=null; right=null; turns.reset(); consecutivePasses=0; gameFinished=false; message='دور اللاعب 1';
    if (mounted) setState(() {});
  }

  bool _legal(_Tile t) => board.isEmpty || t.a==left || t.b==left || t.a==right || t.b==right;
  int _handPoints(List<_Tile> hand) => hand.fold(0, (sum, tile) => sum + tile.a + tile.b);

  void _finishBlockedGame() {
    final points = hands.map(_handPoints).toList();
    final bestScore = points.reduce(min);
    final winners = <int>[for (var i=0;i<points.length;i++) if (points[i]==bestScore) i+1];
    gameFinished = true;
    final scores = List.generate(points.length, (i) => 'اللاعب ${i+1}: ${points[i]}').join('، ');
    message = winners.length==1
        ? 'أُغلقت اللعبة — فاز اللاعب ${winners.first} بأقل مجموع ($bestScore). $scores'
        : 'أُغلقت اللعبة — تعادل اللاعبون ${winners.join(' و ')} بأقل مجموع ($bestScore). $scores';
  }

  void _play(_Tile t) {
    if (gameFinished) return;
    if (!_legal(t)) { setState(()=>message='هذه القطعة لا تناسب طرفي السلسلة'); return; }
    setState(() {
      hands[turns.currentPlayer].remove(t);
      if (board.isEmpty) { board.add(t); left=t.a; right=t.b; }
      else if (t.a==left) { board.insert(0, _Tile(t.b,t.a)); left=t.b; }
      else if (t.b==left) { board.insert(0,t); left=t.a; }
      else if (t.a==right) { board.add(t); right=t.b; }
      else { board.add(_Tile(t.b,t.a)); right=t.a; }
      consecutivePasses=0;
      if (hands[turns.currentPlayer].isEmpty) { gameFinished=true; message='فاز اللاعب ${turns.currentPlayer+1}!'; return; }
      turns.next(); message='دور اللاعب ${turns.currentPlayer+1}';
    });
  }

  void _pass() {
    if (gameFinished) return;
    if (hands[turns.currentPlayer].any(_legal)) { setState(()=>message='لديك قطعة صالحة، لا يمكنك التمرير'); return; }
    setState(() {
      consecutivePasses++;
      if (consecutivePasses>=4) { _finishBlockedGame(); return; }
      turns.next();
      message='تم التمرير — دور اللاعب ${turns.currentPlayer+1}';
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('دومينو — 4 لاعبين محليًا'), actions:[IconButton(onPressed:_newGame,icon:const Icon(Icons.refresh))]),
    body: SafeArea(child: Column(children:[
      const Padding(padding:EdgeInsets.all(8),child:Text('مرّر الهاتف للاعب صاحب الدور. القطع المخفية للاعبين الآخرين.',textAlign:TextAlign.center)),
      Wrap(spacing:8,children:List.generate(4,(i)=>Chip(avatar:CircleAvatar(child:Text('${i+1}')),label:Text('${hands[i].length} قطع'),backgroundColor:!gameFinished&&i==turns.currentPlayer?Colors.amber:null))),
      Padding(padding:const EdgeInsets.all(10),child:Text(message,style:Theme.of(context).textTheme.titleMedium,textAlign:TextAlign.center)),
      Expanded(child:SingleChildScrollView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.all(12),child:Row(children:board.map((t)=>_tile(t,false)).toList()))),
      const Divider(),
      Text(gameFinished?'انتهت اللعبة':'قطع اللاعب ${turns.currentPlayer+1}'),
      SizedBox(height:96,child:ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.all(8),children:hands[turns.currentPlayer].map((t)=>_tile(t,!gameFinished)).toList())),
      Padding(padding:const EdgeInsets.all(12),child:Row(children:[Expanded(child:OutlinedButton.icon(onPressed:gameFinished?null:_pass,icon:const Icon(Icons.skip_next),label:const Text('تمرير الدور'))),const SizedBox(width:8),Expanded(child:FilledButton.icon(onPressed:_newGame,icon:const Icon(Icons.restart_alt),label:const Text('لعبة جديدة')))]))
    ])),
  );

  Widget _tile(_Tile t, bool playable) => Padding(padding:const EdgeInsets.all(4),child:InkWell(onTap:playable?()=>_play(t):null,child:Container(width:54,height:76,decoration:BoxDecoration(color:playable&&_legal(t)?Colors.white:Colors.grey.shade300,border:Border.all(color:playable&&_legal(t)?Colors.green:Colors.black54,width:2),borderRadius:BorderRadius.circular(8)),child:Column(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[Text('${t.a}',style:const TextStyle(fontSize:22,color:Colors.black)),const Divider(height:2,color:Colors.black),Text('${t.b}',style:const TextStyle(fontSize:22,color:Colors.black))]))));
}

class _Tile { final int a,b; const _Tile(this.a,this.b); }
