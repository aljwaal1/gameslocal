import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../design/app_theme.dart';

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
            final compact = constraints.maxHeight < 650;
            final qrSize = math.min(
              constraints.maxWidth * .78,
              constraints.maxHeight * (compact ? .40 : .46),
            ).clamp(140.0, 380.0).toDouble();

            return Padding(
              padding: EdgeInsets.fromLTRB(14, compact ? 7 : 14, 14, 12),
              child: Column(
                children: <Widget>[
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: compact ? 11 : 15,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: <Color>[
                          AppColors.primaryDark,
                          AppColors.primary,
                          accent,
                        ],
                        stops: const <double>[0, .52, 1],
                      ),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: const Color(0x28FFFFFF)),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x30073B3A),
                          blurRadius: 22,
                          offset: Offset(0, 9),
                        ),
                      ],
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: compact ? 48 : 54,
                          height: compact ? 48 : 54,
                          decoration: BoxDecoration(
                            color: const Color(0x20FFFFFF),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0x38FFFFFF)),
                          ),
                          child: const Icon(
                            Icons.qr_code_2_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Text(
                                'امسح QR قبل بدء اللعبة',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 19,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFE8F7F5),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: compact ? 7 : 12),
                  Expanded(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: const Color(0x180F172A)),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x240F172A),
                              blurRadius: 20,
                              offset: Offset(0, 8),
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
                                      Text(
                                        'جاري تجهيز رابط QR الحقيقي...',
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 7 : 11),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                    decoration: BoxDecoration(
                      color: joined ? const Color(0xFFE7F8F4) : AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: joined ? const Color(0x665EEAD4) : AppColors.hairline,
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          joined ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                          color: joined ? AppColors.primary : AppColors.muted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            joined
                                ? 'تم اتصال اللاعب • جاهز للبدء'
                                : 'بانتظار دخول اللاعب عبر QR',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        Container(
                          constraints: const BoxConstraints(minWidth: 34),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: joined
                                ? const Color(0x1F0F766E)
                                : const Color(0x100F172A),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$connectedPlayers',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (ready && !compact) ...<Widget>[
                    const SizedBox(height: 5),
                    SelectableText(
                      url,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  SizedBox(height: compact ? 6 : 9),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: joined ? onStart : null,
                      icon: Icon(
                        joined ? Icons.play_arrow_rounded : Icons.people_alt_rounded,
                      ),
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
