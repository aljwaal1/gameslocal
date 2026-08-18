from pathlib import Path

p = Path('lib/games/football/photo_penalty_game_v3.dart')
s = p.read_text(encoding='utf-8')

old = '''                        Positioned(
                          left: keeperPos.dx - size.width * .26,
                          top: keeperPos.dy - size.height * .19,
                          width: size.width * .52,
                          height: size.height * .38,
                          child: Transform.rotate(
                            angle: (_keeper.dx - .5) * .50 * keeperT,
                            child: RealisticFootballSprite(
                              pose: _keeperPose(),
                              primary: widget.championsMode
                                  ? const Color(0xFFFFB020)
                                  : const Color(0xFF38BDF8),
                              secondary: const Color(0xFF0F172A),
                              mirror: _keeper.dx < .5,
                              alignment: const Alignment(0, -.05),
                            ),
                          ),
                        ),
                        if (_phase == _PenaltyPhase.aiming)
                          Positioned.fromRect(
                            rect: goal,
                            child: IgnorePointer(
                              child: CustomPaint(painter: _GoalGridPainter()),
                            ),
                          ),
'''
new = '''                        // Keep the goal frame/net visible as part of the stadium,
                        // behind the keeper, through every phase of the shot.
                        Positioned.fromRect(
                          rect: goal,
                          child: IgnorePointer(
                            child: CustomPaint(painter: _GoalGridPainter()),
                          ),
                        ),
                        Positioned(
                          left: keeperPos.dx - size.width * .19,
                          top: keeperPos.dy - size.height * .145,
                          width: size.width * .38,
                          height: size.height * .29,
                          child: Transform.rotate(
                            angle: (_keeper.dx - .5) * .42 * keeperT,
                            child: RealisticFootballSprite(
                              pose: _keeperPose(),
                              primary: const Color(0xFF38BDF8),
                              secondary: const Color(0xFF0F172A),
                              mirror: _keeper.dx < .5,
                              alignment: const Alignment(0, -.05),
                            ),
                          ),
                        ),
'''
if old not in s:
    raise SystemExit('keeper/goal block not found; refusing unsafe patch')
s = s.replace(old, new, 1)

# The single surviving football game no longer needs a champions-only visual branch.
s = s.replace("      _PenaltyOutcome.goal => widget.championsMode ? 'هــــدف عالمي!' : 'هــــدف!',", "      _PenaltyOutcome.goal => 'هــــدف!',", 1)

# Make the instruction overlay lighter and less intrusive.
s = s.replace("padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),", "padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),", 1)
s = s.replace("fontSize: 15,", "fontSize: 14,", 1)

p.write_text(s, encoding='utf-8')
