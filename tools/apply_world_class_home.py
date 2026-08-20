from pathlib import Path

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

def replace_once(old: str, new: str) -> None:
    global s
    count = s.count(old)
    if count != 1:
        raise SystemExit(f'Expected one anchor, found {count}: {old[:80]!r}')
    s = s.replace(old, new, 1)

replace_once(
'''      height: 128,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF1F6F63), Color(0xFF7B2CBF)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
''',
'''      height: 144,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: AppColors.heroGradient,
          stops: <double>[0, .52, 1],
        ),
        border: Border.all(color: const Color(0x28FFFFFF)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33073B3A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
''')

replace_once(
'''            const CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.accent,
              child: Icon(
                Icons.sports_esports,
                color: AppColors.primaryDark,
                size: 36,
              ),
            ),
''',
'''            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0x22FFFFFF),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0x44FFFFFF)),
              ),
              child: const Icon(
                Icons.sports_esports_rounded,
                color: AppColors.accent,
                size: 40,
              ),
            ),
''')

replace_once(
'''                  Text(
                    'GamesLocal',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'ألعاب محلية • روبوت • شبكة محلية',
                    style: TextStyle(fontSize: 14, color: Colors.white),
                  ),
''',
'''                  Text(
                    'GamesLocal',
                    style: TextStyle(
                      fontSize: 29,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.4,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'العب مع العائلة • روبوت • LAN • QR',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE8F7F5),
                    ),
                  ),
''')

replace_once(
'''        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
''',
'''        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              Colors.white,
              color.withValues(alpha: .10),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: .24)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x120F172A),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
''')

replace_once(
'''        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
''',
'''        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: <Color>[
              Colors.white,
              color.withValues(alpha: .07),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: .16)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x1F0F172A),
              blurRadius: 16,
              offset: Offset(0, 7),
            ),
          ],
        ),
''')

replace_once(
'''                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.65)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
''',
'''                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[color, color.withValues(alpha: .72)],
                    ),
                    borderRadius: BorderRadius.circular(19),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: color.withValues(alpha: .28),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 30),
''')

s = s.replace('releaseColor.withOpacity(0.12)', 'releaseColor.withValues(alpha: .12)')
s = s.replace('releaseColor.withOpacity(0.35)', 'releaseColor.withValues(alpha: .35)')

replace_once(
'''            const SizedBox(height: 3),
            Text(
              game.playersText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
''',
'''            const SizedBox(height: 4),
            Text(
              game.playersText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.inkSoft,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              game.status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
''')

p.write_text(s, encoding='utf-8')
print('Applied world-class home polish without gameplay changes.')
