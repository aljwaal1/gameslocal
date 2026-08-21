from pathlib import Path

p = Path('lib/games/checkers/checkers_game.dart')
s = p.read_text(encoding='utf-8')

def replace_once(old: str, new: str) -> None:
    global s
    count = s.count(old)
    if count != 1:
        raise SystemExit(f'Checkers polish anchor count={count}: {old[:100]!r}')
    s = s.replace(old, new, 1)

replace_once(
"""              IconButton(onPressed: requestBoardReset, icon: const Icon(Icons.refresh))
""",
"""              IconButton(
                tooltip: 'إعادة المباراة',
                onPressed: requestBoardReset,
                icon: const Icon(Icons.refresh_rounded),
              )
""",
)

replace_once(
"""                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                  child: Padding(
                    padding: const EdgeInsets.all(9),
""",
"""                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: <Color>[
                        Color(0xFFFFFFFF),
                        Color(0xFFF5FAF9),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0x1A0F172A)),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x140F172A),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(11),
""",
)

replace_once(
"""                            Icon(
                                redTurn ? Icons.circle : Icons.circle_outlined),
""",
"""                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: redTurn
                                    ? const Color(0x16E11D48)
                                    : const Color(0x120F172A),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                redTurn
                                    ? Icons.circle_rounded
                                    : Icons.circle_outlined,
                                color: redTurn
                                    ? const Color(0xFFE11D48)
                                    : const Color(0xFF0F172A),
                                size: 20,
                              ),
                            ),
""",
)

replace_once(
"""                              ButtonSegment(
                                  value: false,
                                  label: Text('لاعب ضد لاعب'),
                                  icon: Icon(Icons.people)),
                              ButtonSegment(
                                  value: true,
                                  label: Text('ضد الكمبيوتر'),
                                  icon: Icon(Icons.smart_toy)),
""",
"""                              ButtonSegment(
                                  value: false,
                                  label: Text('لاعب ضد لاعب'),
                                  icon: Icon(Icons.people_alt_rounded)),
                              ButtonSegment(
                                  value: true,
                                  label: Text('ضد الكمبيوتر'),
                                  icon: Icon(Icons.smart_toy_rounded)),
""",
)

replace_once(
"""                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              tableColor.withOpacity(0.95),
                              tableColor.withOpacity(0.65)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: AppColors.accent, width: 5),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black38,
                                blurRadius: 18,
                                offset: Offset(0, 7))
                          ],
""",
"""                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              tableColor.withValues(alpha: .98),
                              tableColor.withValues(alpha: .72),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: const Color(0xFFF5B82E),
                            width: 3,
                          ),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x42000000),
                              blurRadius: 22,
                              offset: Offset(0, 10),
                            ),
                            BoxShadow(
                              color: Color(0x33F5B82E),
                              blurRadius: 12,
                            ),
                          ],
""",
)

p.write_text(s, encoding='utf-8')
print('Applied premium checkers presentation without changing gameplay logic.')
