# Hockey implementation report

Status: DONE pending independent root review. No commits or pushes by worker. Only lib/games/air_hockey and four new hockey test files changed.

## Changes
- New hockey_bot_controller.dart: immutable pixel-unit profile/state plus deterministic sampled step. Easy/Normal/Hard response intervals .24/.16/.09s; speed220/300/380px/s; acceleration700/1000/1400px/s²; prediction.12/.25/.42s and accuracy.55/.78/.96. Targets change only at response boundaries. Proportional arrival speed and capped acceleration smooth starts/stops/turns. Defensive return when puck is distant; attack requires a slow reachable puck in upper playable band. Prediction reflects at actual puck walls, then clamps paddle reach. Invalid/nonpositive dt ignored; large dt capped.034.
- hockey_physics.dart: independent advance/cap, paddle/post contact result and wall reflection. Restitution.90; normal-only paddle transfer.65; separation1px; contact release hysteresis2px. Separating/repeated contacts inject no impulse; coincident centers choose finite fallback normal.900px/s maximum before integration and after all collision routes.
- air_hockey_game.dart: replaces frame-tracking bot and old1.42/2.65/minimum shot injection with pixel controller/physics. Top-paddle collision speed derives actual position delta. Bot state resets after goal, reset, mode/difficulty and field-size changes. Unchanged normalized network payload keys and authority, goal mouth, collision radii, wall positions, score reversal, and first-to-five rules.
- Behaviorally discovered existing terminal-goal LAN bug fixed: fifth goal stopped tick loop before a state broadcast could happen. _goal now immediately sends existing hockey_state via host with exactly the same ten keys. Score calculation/win rules unchanged. Host/client tests verify final5 state and mirror.
- Existing narrow-screen scoreboard overflow fixed with Expanded score cards; all stats remain visible and text can wrap.

## TDD evidence
All Flutter calls prefix CI=true FLUTTER_SUPPRESS_ANALYTICS=true; no cloud metadata request.
1. Existing-API live widget regression test/hockey_speed_regression_test.dart RED:8421.2208px/s vs <=900, before paddle contact. /tmp/hockey-baseline-red.log.
2. New controller/physics API RED: missing module/definitions before implementation. /tmp/hockey-api-red.log.
3. First focused run exposed existing320x640/textScale1.3 score Row overflow216px. Expanded score cards fixed it; widget suite now passes. The original first-run output was observed through tool output; /tmp/hockey-focused.log contains final green run.
4. Reflected-prediction test RED:193.439px vs233.76±1.5 because initial model reflected at paddle reach instead of puck walls. Fixed actual wall geometry. /tmp/hockey-edge-red.log.
5. LAN fifth-goal test RED: no outgoing payload with score5/playingfalse. Fixed immediate host broadcast with unchanged payload. /tmp/hockey-host-goal-red.log.

## Verification
- Focused command: flutter test --no-pub test/hockey_bot_controller_test.dart test/hockey_collision_behavior_test.dart test/hockey_speed_regression_test.dart test/hockey_screen_behavior_test.dart test/hockey_physics_test.dart —28 passed, exit0, /tmp/hockey-focused.log.
- Full suite flutter test --no-pub —122 passed, exit0, /tmp/hockey-full-tests.log.
- Analysis flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings —exit0, no errors. Existing nonfatal repository diagnostics remain, /tmp/hockey-analyze.log. Removed newly introduced unnecessary import and reran its six collision tests /tmp/hockey-import-check.log; production unchanged after full suite.
- dart format owned lib/test —clean.

## Behavioral coverage
Difficulty ordering and exact intervals; held targets; 3000-step velocity/acceleration limits each profile; distant defensive convergence; reachable/slow-only attacks; same pixel acceleration across doubled dimensions; reflected prediction; invalid/large dt; reset.
Additional actual-motion stress test:72000 steps (3 profiles ×2 portrait/landscape field sizes ×12000 abrupt seeded target changes) verifies actual position-derived velocity matches state velocity and actual acceleration remains within profile. No clamping discontinuity reproduced; live collision uses actual movement rather than blindly using controller velocity regardless.
Physics stationary/moving tangential preservation,65% normal transfer, repeated/separating contact, zero distance, cap before displacement, paddle/post/wall cap and bounce.
Widget friend mode controls both paddles and resets bot; fifth goal ends match and resets bot; LAN host receives control and publishes unchanged keys at terminal goal; LAN and Internet clients mirror authoritative scores without sending new state.320x640 at text scale1.3 exercised.

Limitations: no device or Android build by worker; root owns full multi-game visual QA, independent review, CI and final APK. No other games, ArcadeTiming, network implementation or audio engine edited.

## Independent review fix round1 — actual landscape field

Finding: the mounted640×320/textScale1.3 screen left a616px-wide field with too little height, so width-based paddle radius40.04px protruded past the top/bottom. Controller-only landscape stress coverage did not prove the actual mounted field geometry.

RED: new test/hockey_field_layout_test.dart mounted actual320×640,390×844,640×320 at1.3 and measured painted paddle center/radius.640×320 initial upper paddle edge was-24.68px; /tmp/hockey-landscape-red.log. A first contact fixture using normalized .09 distance was corrected to a pixel-radius offset on the tall field, because the original tall fixture was outside collision reach rather than exposing a production defect.

Fix: extracted the unchanged HUD controls/score/replay and field widget. Landscape uses a side HUD whose content alone may scroll, keeping the field at full available height. The actual centered field width is capped at1.05×height, preserving existing normalized paddle limits, puck/goal geometry, all physics radii and network coordinates.640×320 now gets a256.2×244 field instead of616×96; the field and pointer geometry use exactly those same real constraints. Portrait retains the top HUD and centered field. Replay lives in the landscape HUD so ending the match cannot shrink the field into a shallow strip.

Behavioral validation: new tests assert full rendered paddle bodies inside the actual field initially, at four real touch movement extrema, after a real paddle contact/bounce, and in the completed-match layout. Actual field size is compared with state.fieldSize, and landscape width/height must each remain>=200px.320×640,390×844,640×320 are all tested with textScale1.3; no overflow.

Current results after fix:
- Focused31 PASS, /tmp/hockey-focused.log.
- Full125 PASS, /tmp/hockey-full-tests.log.
- Analyzeexit0/noerrors185nonfatal, /tmp/hockey-analyze.log.
- Ownedformat9files0changed, /tmp/hockey-format.log.
- Optional real-font visual captures passed3cases, /tmp/hockey-visual.log; screenshots /tmp/hockey-320x640.png, /tmp/hockey-390x844.png, /tmp/hockey-640x320.png. These were visually inspected; complete paddle bodies, full field, visible scores/control panel confirmed. Capture harness is scratch-only /tmp/hockey_visual_test.dart and not part of delivered source/tests.

No commits/pushes/spawns by worker. Ready for scoped independent re-review.


## Independent review
# Independent Hockey review

Reviewed the hockey/global requirements in docs/superpowers/specs/2026-11-06-games-quality.md, /tmp/hockey-review.diff, current implementation and tests. Read-only source review; no tests rerun, source edits, commits, pushes or agents. The implementer report was not yet present when reviewed. Existing logs show focused 28 tests passed, full 122 tests passed, and analysis completed with 186 existing findings (three warnings in photo_penalty_game_v3.dart; no hockey errors/warnings).

## Specification verdict: REQUEST CHANGES

The hockey-specific controller, pixel collision and network work satisfies the specified behavioral changes on inspection, supported by meaningful unit/widget tests. The remaining global landscape validation requirement is not met by the actual screen and has a concrete geometry defect below. The standalone controller landscape stress test does not validate the field dimensions produced by the real screen.

### P2 — Landscape field scales paddles to width while leaving an insufficient height

Location: lib/games/air_hockey/air_hockey_game.dart:458-470 (field layout); :561-563 (paddle radius); lib/games/air_hockey/hockey_bot_controller.dart:121-123 (vertical bounds/defense).

At 640×320, the field spans 616 logical pixels after 12px side padding, making each rendered paddle radius 40.04px. App bar, fixed top controls and vertical padding leave a field much shorter than 250.25px, the height necessary for the initial/defensive paddle center at 0.16*height to clear that radius. Consequently the initial upper and lower paddles protrude beyond their field edges. The .08/.43 vertical controller limits likewise do not account for paddle radius. This is more pronounced at text scale 1.3 and after the terminal-score replay button reduces available height. It also makes width-based puck/post/paddle collision radii disproportionately large relative to the vertical playing area. This issue predates some of the current implementation, but the specification explicitly requires landscape validation and forbids completing a package with a known defect.

Required: provide a usable landscape field with an appropriate width/height relationship (for example, a centered field with constrained width, or a compact landscape HUD) and test the *actual mounted screen* at landscape/text scale 1.3. Assert rendered paddle extents fit inside the field at initial positions and controller extrema; exercise an actual bounded movement/contact path. Current hockey_screen_behavior_test.dart mount supports a size argument, but all its cases use the 320×640 default.

## Code-quality verdict: PASS for controller/physics/network changes; landscape issue blocks package completion

No additional blocking code-quality findings.

- Profiles expose the exact .24/.16/.09 response intervals and ordered pixel speed/acceleration/prediction capability. Target decisions are held; proportional arrival provides gradual braking. Invalid dt returns unchanged state and large dt is bounded. The 72,000-frame stress checks compare actual derived movement to reported speed/acceleration rather than trusting fields alone.
- Defense, conditional attacks, difficulty-dependent reflected prediction and equal pixel acceleration across dimensions are behaviorally tested. Reflection uses the puck wall extents rather than paddle movement bounds.
- Puck velocity is limited to 900 logical px/s before position integration and throughout paddle, post, wall and final assignment paths. Existing aperture/post positions are preserved. Stationary normal restitution is .90 and paddle normal transfer .65, with no difficulty minimum-shot injection or 1.42 transfer. Separation, zero-distance fallback, separating-contact no-impulse and contact hysteresis are finite and meaningful.
- Bot reset occurs after a goal, match reset and mode changes. Friend controls, five-goal win/reset and local/internet mirrored client state remain intact. The immediate goal state broadcast correctly fixes a stopped terminal match whose fifth goal would otherwise never reach the client; existing payload keys and authority conditions remain unchanged. Random call sites/order are not altered.
- The Expanded score cells solve the narrow score-row width issue without reducing text size. Their content may wrap, which is acceptable, but it does not resolve the landscape playing-field aspect defect.

Validation limits: the stated RED evidence came from the parent/implementer context; this reviewer did not independently rerun RED/GREEN tests. Logs alone establish current green outcomes, not visual landscape fitness.


## Scoped re-review
# Hockey scoped re-review — landscape correction

Scope: re-review the prior landscape geometry finding and layout changes in /tmp/hockey-rereview.diff. Read current source and hockey_field_layout_test.dart; inspected existing RED/GREEN/analyze logs. No tests rerun, source edited, commits/pushes or agents.

## Specification verdict: PASS — prior P2 ADDRESSED

The responsive HUD side panel preserves the field's available height at 640×320. air_hockey_game.dart:450-493 constrains actual field width to at most 1.05×field height while keeping full height. With the unchanged paddle radius of .065×width, the radius is at most .06825×height, smaller than the .08×height clearance at both extreme touch bounds. Thus initial positions and bot/friend vertical extrema clear the edges for both live and finished-match layouts. The constraints apply to the actual Listener/CustomPaint, so touch conversion and collision fieldSize use the same dimensions. The wide-screen replay control remains in the scrollable side panel and does not steal field height. Portrait retains the familiar vertical HUD and bounds the field width if height becomes tight.

The new actual widget cases cover 320×640, 390×844 and 640×320 at text scale 1.3. They inspect painted paddle extents, initial positions, friend-mode pointer extremes, actual contact bounce/capped velocity and completed-match layout; they also reject Flutter layout exceptions. Landscape requires at least 200px in both actual field dimensions, preventing a trivial tiny-field workaround. The original landscape RED log records an edge extent of -24.68px. Current focused log shows 31 tests passed; current full log shows 125 tests passed. Analysis completed with 185 findings, with no hockey warnings/errors. These checks satisfy the original finding's requested regression coverage.

## Code-quality verdict: PASS

No new severity findings in the scoped layout changes. The extracted HUD/mode/replay widgets avoid duplicating handlers or creating alternate game-state paths. Only the HUD scrolls in landscape; the playable field remains fixed and centered. Existing scores, mode/reset callbacks, network payloads, normalized coordinate limits, radii and physics rules are retained. The mathematical aspect bound provides a clear reason for the sizing constant and continues to work when the terminal replay button appears.

The earlier controller/physics/network review remains unchanged. This scoped review introduces no further blockers.
