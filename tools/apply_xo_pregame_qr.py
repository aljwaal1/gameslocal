from pathlib import Path

# XO: show a real, large browser QR lobby before the board for network-host play.
p = Path('lib/games/xo/xo_game.dart')
s = p.read_text(encoding='utf-8')

old = "  String _iphoneUrl = '';\n"
new = "  String _iphoneUrl = '';\n  bool _showNetworkQrLobby = true;\n"
if s.count(old) != 1:
    raise SystemExit(f'XO url field anchor count={s.count(old)}')
s = s.replace(old, new, 1)

anchor = "  Future<void> _showBrowserQr() async {\n"
if s.count(anchor) != 1:
    raise SystemExit('XO _showBrowserQr anchor missing')
helper = r'''  Widget _buildNetworkQrLobby(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إكس أو • دعوة لاعب'),
        leading: IconButton(
          tooltip: 'رجوع',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final qrSize = min(
              constraints.maxWidth * .78,
              constraints.maxHeight * .46,
            ).clamp(220.0, 380.0).toDouble();
            final ready = _iphoneUrl.startsWith('http');
            final joined = _iphonePlayers.isNotEmpty;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: <Color>[Color(0xFF0F766E), Color(0xFF6D28D9)],
                          ),
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x330F172A),
                              blurRadius: 18,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: <Widget>[
                            const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 38),
                            const SizedBox(height: 8),
                            const Text(
                              'امسح الكود قبل بدء اللعبة',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'افتح الكاميرا من iPhone أو Android، ثم افتح الرابط الظاهر بعد المسح.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0x160F172A)),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(color: Color(0x220F172A), blurRadius: 16, offset: Offset(0, 6)),
                          ],
                        ),
                        child: ready
                            ? QrImageView(
                                data: _iphoneUrl,
                                size: qrSize,
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.all(6),
                              )
                            : SizedBox(
                                width: qrSize,
                                height: qrSize,
                                child: const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      CircularProgressIndicator(),
                                      SizedBox(height: 12),
                                      Text('جاري تجهيز QR الحقيقي...'),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: joined ? const Color(0xFFE6FFFA) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: joined ? const Color(0xFF5EEAD4) : const Color(0x180F172A),
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              joined ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                              color: joined ? const Color(0xFF0F766E) : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                joined
                                    ? 'تم اتصال اللاعب عبر QR • جاهز للبدء'
                                    : 'بانتظار أن يمسح اللاعب QR ويدخل الغرفة',
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (ready) ...<Widget>[
                        const SizedBox(height: 7),
                        SelectableText(
                          _iphoneUrl,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: joined
                              ? () {
                                  GameFeedback.tap();
                                  setState(() => _showNetworkQrLobby = false);
                                  _broadcastWebState();
                                }
                              : null,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(joined ? 'بدء إكس أو' : 'بانتظار اللاعب'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

'''
s = s.replace(anchor, helper + anchor, 1)

old = "  @override\n  Widget build(BuildContext context) {\n    return Scaffold(\n"
new = """  @override
  Widget build(BuildContext context) {
    final hasAndroidGuest = widget.networkCore?.state.players
            .any((player) => !player.isHost) ??
        false;
    if (isNetworkGame && isHost && _showNetworkQrLobby && !hasAndroidGuest) {
      return _buildNetworkQrLobby(context);
    }
    return Scaffold(
"""
if s.count(old) != 1:
    raise SystemExit(f'XO build anchor count={s.count(old)}')
s = s.replace(old, new, 1)
p.write_text(s, encoding='utf-8')

# GameRoom: make the pre-game QR intent explicit for XO instead of a tiny in-game icon workflow.
p = Path('lib/core/game_room.dart')
s = p.read_text(encoding='utf-8')
s = s.replace(
    "? 'افتح اللعبة لإظهار QR للمتصفح بعد انضمام اللاعب'",
    "? (widget.game.id == 'xo'\n                            ? 'بعد إنشاء الغرفة افتح QR الكبير وشاركه قبل ظهور اللوحة'\n                            : 'افتح اللعبة لإظهار QR للمتصفح بعد انضمام اللاعب')",
)
s = s.replace(
    "? 'بدء اللعبة وفتح QR'",
    "? (widget.game.id == 'xo'\n                                          ? 'فتح QR الكبير قبل اللعبة'\n                                          : 'بدء اللعبة وفتح QR')",
)
p.write_text(s, encoding='utf-8')

# Regression/source contract: QR lobby must be large and must gate the board for network host XO.
p = Path('test/xo_pregame_qr_contract_test.dart')
p.write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('XO network host shows large QR lobby before board', () {
    final source = File('lib/games/xo/xo_game.dart').readAsStringSync();
    expect(source, contains('bool _showNetworkQrLobby = true;'));
    expect(source, contains('return _buildNetworkQrLobby(context);'));
    expect(source, contains('constraints.maxWidth * .78'));
    expect(source, contains("'امسح الكود قبل بدء اللعبة'"));
    expect(source, contains("'بدء إكس أو'"));
    expect(source, contains('onPressed: joined'));
  });

  test('Game room labels XO QR as pre-game action', () {
    final source = File('lib/core/game_room.dart').readAsStringSync();
    expect(source, contains("'فتح QR الكبير قبل اللعبة'"));
    expect(source, contains("'بعد إنشاء الغرفة افتح QR الكبير وشاركه قبل ظهور اللوحة'"));
  });
}
''', encoding='utf-8')

print('Applied XO pre-game QR lobby and contract test.')
