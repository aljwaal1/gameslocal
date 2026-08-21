from pathlib import Path

p = Path('lib/games/xo/xo_game.dart')
s = p.read_text(encoding='utf-8')

def replace_once(old: str, new: str) -> None:
    global s
    count = s.count(old)
    if count != 1:
        raise SystemExit(f'XO polish anchor count={count}: {old[:100]!r}')
    s = s.replace(old, new, 1)

replace_once(
"""          IconButton(onPressed: reset, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: resetScore, icon: const Icon(Icons.restart_alt)),
""",
"""          IconButton(
            tooltip: 'جولة جديدة',
            onPressed: reset,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'تصفير النتائج',
            onPressed: resetScore,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
""",
)

replace_once(
"""                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[Color(0xFF0F766E), Color(0xFF6D28D9)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(color: Color(0x330F172A), blurRadius: 14, offset: Offset(0, 6)),
                      ],
                    ),
""",
"""                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: <Color>[
                          Color(0xFF073B3A),
                          Color(0xFF0F766E),
                          Color(0xFF6D28D9),
                        ],
                        stops: <double>[0, .52, 1],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0x2FFFFFFF)),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x36073B3A),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
""",
)

replace_once(
"""                              ButtonSegment<bool>(value: false, label: Text('لاعبان'), icon: Icon(Icons.people)),
                              ButtonSegment<bool>(value: true, label: Text('روبوت'), icon: Icon(Icons.smart_toy)),
""",
"""                              ButtonSegment<bool>(
                                value: false,
                                label: Text('لاعبان'),
                                icon: Icon(Icons.people_alt_rounded),
                              ),
                              ButtonSegment<bool>(
                                value: true,
                                label: Text('روبوت'),
                                icon: Icon(Icons.smart_toy_rounded),
                              ),
""",
)

replace_once(
"""                                    gradient: winning
                                        ? const LinearGradient(colors: <Color>[Color(0xFFFFD166), Color(0xFFFFB703)])
                                        : const LinearGradient(colors: <Color>[Colors.white, Color(0xFFF0F7FF)]),
                                    borderRadius: BorderRadius.circular(compact ? 18 : 24),
""",
"""                                    gradient: winning
                                        ? const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: <Color>[
                                              Color(0xFFFFE9A8),
                                              Color(0xFFF5B82E),
                                            ],
                                          )
                                        : LinearGradient(
                                            begin: Alignment.topRight,
                                            end: Alignment.bottomLeft,
                                            colors: <Color>[
                                              Colors.white,
                                              value == 'X'
                                                  ? const Color(0xFFFFF3F5)
                                                  : value == 'O'
                                                      ? const Color(0xFFF1F8FF)
                                                      : const Color(0xFFF8FAFC),
                                            ],
                                          ),
                                    borderRadius: BorderRadius.circular(compact ? 20 : 26),
""",
)

replace_once(
"""                                    boxShadow: const <BoxShadow>[
                                      BoxShadow(color: Color(0x220F172A), blurRadius: 10, offset: Offset(0, 4)),
                                    ],
""",
"""                                    boxShadow: <BoxShadow>[
                                      const BoxShadow(
                                        color: Color(0x1F0F172A),
                                        blurRadius: 14,
                                        offset: Offset(0, 6),
                                      ),
                                      if (winning)
                                        const BoxShadow(
                                          color: Color(0x44F5B82E),
                                          blurRadius: 18,
                                          spreadRadius: 1,
                                        ),
                                    ],
""",
)

replace_once(
"""      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
      ),
""",
"""      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.white,
            color.withValues(alpha: .08),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .18)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
""",
)

replace_once(
"""          Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.w900)),
          Text('$value',
              style: TextStyle(
                  color: color, fontSize: 24, fontWeight: FontWeight.w900)),
""",
"""          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 25,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
""",
)

p.write_text(s, encoding='utf-8')
print('Applied premium XO presentation without changing gameplay logic.')
