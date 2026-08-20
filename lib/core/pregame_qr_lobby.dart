import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PregameQrLobby extends StatelessWidget {
  const PregameQrLobby({
    super.key,
    required this.title,
    required this.url,
    required this.connectedPlayers,
    required this.onStart,
    this.minimumPlayers = 1,
    this.subtitle = 'امسح الكود من iPhone أو Android على نفس شبكة Wi-Fi.',
    this.accent = const Color(0xFF6D28D9),
  });

  final String title;
  final String url;
  final int connectedPlayers;
  final int minimumPlayers;
  final VoidCallback onStart;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ready = url.startsWith('http');
    final joined = connectedPlayers >= minimumPlayers;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final qrSize = math.min(
              constraints.maxWidth * .78,
              constraints.maxHeight * .46,
            ).clamp(220.0, 380.0).toDouble();
            final compact = constraints.maxHeight < 650;

            return Padding(
              padding: EdgeInsets.fromLTRB(14, compact ? 8 : 14, 14, 12),
              child: Column(
                children: <Widget>[
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: compact ? 12 : 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: <Color>[
                          const Color(0xFF0F766E),
                          accent,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x2D0F172A),
                          blurRadius: 18,
                          offset: Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.qr_code_2_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'امسح QR قبل بدء اللعبة',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: compact ? 8 : 12),
                  Expanded(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0x160F172A)),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x220F172A),
                              blurRadius: 16,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ready
                            ? QrImageView(
                                data: url,
                                size: qrSize,
                                padding: const EdgeInsets.all(4),
                                backgroundColor: Colors.white,
                              )
                            : SizedBox(
                                width: qrSize,
                                height: qrSize,
                                child: const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      CircularProgressIndicator(),
                                      SizedBox(height: 10),
                                      Text('جاري تجهيز رابط QR الحقيقي...'),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 8 : 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                    decoration: BoxDecoration(
                      color: joined ? const Color(0xFFE6FFFA) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(17),
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
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            joined
                                ? 'تم اتصال اللاعب • جاهز للبدء'
                                : 'بانتظار دخول اللاعب عبر QR',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          '$connectedPlayers',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                        ),
                      ],
                    ),
                  ),
                  if (ready) ...<Widget>[
                    const SizedBox(height: 5),
                    SelectableText(
                      url,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
                    ),
                  ],
                  SizedBox(height: compact ? 7 : 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: joined ? onStart : null,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(joined ? 'بدء اللعبة' : 'بانتظار لاعب'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
