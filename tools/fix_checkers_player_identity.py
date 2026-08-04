from pathlib import Path

path = Path('lib/games/checkers/checkers_game.dart')
text = path.read_text(encoding='utf-8')

old_identity = """  String _localPlayerId() {
    final LocalNetworkState? state = widget.networkCore?.state;
    if (state == null || state.players.isEmpty)
      return localPlayerIsRed ? 'host-checkers' : 'client-checkers';
    return state.players.first.id;
  }
"""
new_identity = """  String _localPlayerId() {
    final LocalNetworkCore? core = widget.networkCore;
    if (core == null || core.localPlayerId == 'system') {
      return localPlayerIsRed ? 'host-checkers' : 'client-checkers';
    }
    return core.localPlayerId;
  }
"""
if old_identity in text:
    text = text.replace(old_identity, new_identity, 1)
elif 'return core.localPlayerId;' not in text:
    raise SystemExit('Checkers local-player identity function not found')

android_guest_getter = """  bool get hasAndroidGuest => widget.networkCore?.state.players
          .any((LocalPlayer player) => !player.isHost) ??
      false;
"""
turn_anchor = """  bool get isMyNetworkTurn => !networkMode || redTurn == localPlayerIsRed;
"""
if 'bool get hasAndroidGuest =>' not in text:
    if turn_anchor not in text:
        raise SystemExit('Checkers turn getter anchor not found')
    text = text.replace(turn_anchor, turn_anchor + android_guest_getter, 1)

old_event_guard = """    _iphoneEventsSub = bridge.events.stream.listen((event) {
      if (event.type != 'tap' || redTurn || gameFinished) return;
"""
new_event_guard = """    _iphoneEventsSub = bridge.events.stream.listen((event) {
      if (event.type != 'tap' || redTurn || gameFinished || hasAndroidGuest) {
        return;
      }
"""
if old_event_guard in text:
    text = text.replace(old_event_guard, new_event_guard, 1)
elif 'gameFinished || hasAndroidGuest' not in text:
    raise SystemExit('Checkers Safari event guard not found')

text = text.replace(
    "'canPlay': !redTurn && !gameFinished,",
    "'canPlay': !redTurn && !gameFinished && !hasAndroidGuest,",
    1,
)

old_card_start = """  Widget _iphoneCard() {
    if (!networkMode || !localPlayerIsRed) return const SizedBox.shrink();
    return Card(
"""
new_card_start = """  Widget _iphoneCard() {
    if (!networkMode || !localPlayerIsRed) return const SizedBox.shrink();
    if (hasAndroidGuest) {
      return const Card(
        color: Color(0xFFFFF4D8),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'تم اتصال لاعب أندرويد؛ تم تعطيل دخول Safari لأن الضامة مخصصة للاعبين فقط.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );
    }
    return Card(
"""
if old_card_start in text:
    text = text.replace(old_card_start, new_card_start, 1)
elif 'تم تعطيل دخول Safari' not in text:
    raise SystemExit('Checkers iPhone card anchor not found')

path.write_text(text, encoding='utf-8')
