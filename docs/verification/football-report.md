# Football implementation and verification report

Date: 2026-11-06. Baseline: bf935247f1debc794e6a75b3288ac8273b21d2e4. Scope: football and shared feedback only. Implementation and final local verification are complete. Independent specification and code-quality re-review approved all five findings (`football-rereview-round2.md`); this report does not authorize merge or claim an APK has been built.

## Implemented behavior

Both local Flame and elite network arenas use the shared penalty motion timeline: plant .22, approach end .28, keeper push .26-.48, contact .34-.38, ball launch .38, follow-through end .58, reach end .84, arrival/landing .86-1. The ball stays still until launch. Contact feedback fires once; visible outcomes, results and score change at arrival. Existing photo actors use shared Canvas transforms with the kicking boot anchored to the stationary ball. Actor layout bounds rotated keeper and player bodies across phone/landscape dimensions, and instruction/HUD panels stay outside the field.

Each shot owns a cancellable feedback lifetime. The shared player channel serializes asynchronous stop/volume/source/resume commands, checking ownership/cancellation after every await. Haptics start at the event independently of blocked audio preparation. Old cancellation cannot stop a newer owner. Existing calls without a cancellation argument remain supported.

## Independent review findings addressed

| Finding | Implementation | Behavioral evidence |
| --- | --- | --- |
| Live rotation disposed the active Flame game | A persistent GlobalKey retains GameWidget state across Column/Row layout changes. | Loaded-photo arena rotates portrait→landscape→portrait during an active shot; same element, shot, results and fresh interaction survive. |
| Remote packets could claim locally owned turns or poison the next-turn slot | Enforce remote role parity, exactly one admissible next turn based on arrival, and finished-match rejection. | Unsolicited local-owner turn, premature peer turn, wrong-role future turn, duplicate/stale turn, malformed pending-slot packet, full terminal match, paired LAN/internet sequencing. |
| Disconnect allowed an old shot to resume | Clear pending shot/feedback/gestures, cancel generation and block resume/tick/animation/incoming entry points after disconnect. | Received active shot and queued next shot both remain terminal across pause/resume; disconnect message and score stay unchanged. |
| Suspended gestures could resolve after resume | Local input epoch invalidates old shell drags; paused entry points reject input; elite clears armed drags. Fresh eligible keeper pan-start arms the keeper gesture. | Actual loaded local lifecycle with old release before/after resume, then a successful fresh gesture; elite shooting release orders; actual elite Champions keeper stale gesture followed by successful fresh dive. Already-sent network turns resume silently and never resend. |
| Malformed payloads threw or created unbounded actors | Validate numeric types, integral finite nonnegative turn, finite/ranged fields and known string outcome before queueing; clamp actor targets defensively. | Wrong types/null/NaN/infinity/fractional turns/outliers rejected without score or painter exception; valid full producer endpoints accepted; malformed packet cannot block valid next turn. |

The full producer envelope includes a pan-start/end with no update: `_animate` may leave displayed aim x=-.06..1.06, y=-.05..1.03; maximum skillNoise=.077 adds ±.0385, and curve adds ±.018 to x. Accepted raw wire bounds are therefore x=-.1165..1.1165 and y=-.0885..1.0685, with keeper x=.06...94, y=.08...88, power=.42..1 and curve=-1..1. The producer and Random calculations are unchanged. A paired test uses the actual arena start/end callbacks without an update after a preceding edge shot; its next legitimate tx is >=1.0535 for every Random result, and both peers now score the turn.

## RED / GREEN evidence

Pre-maintenance RED logs were lost; surviving partial fixes were inspected rather than blindly rewritten. Fresh reconstructed-defect sensitivity checks deliberately removed one reviewed safeguard at a time and restored exact source in `finally`. All six produced the intended behavioral RED: rotation element identity false, wrong-role score 1 instead of 0, disconnect revival score 1, old local pointer starting a flight, outlier keeper packet scoring, and wrong-type packet throwing NoSuchMethodError. These are reconstructed regression checks, not claimed historical logs: `football-red-{rotation,remote-ownership,disconnect-resume,old-local-gesture,packet-ranges,packet-types}.log`, summarized in `football-red-summary.log`.

Independent round 2 found two residual issues: fresh elite keeper input was never armed, and the retained edge aim enlarged legal producer bounds. New tests ran before production fixes and failed specifically: keeper expected 2 results, actual 1; paired inherited edge shot expected 4 results, actual 3. `football-round2-red.log` records both failures; `football-round2-green.log` records 45 passing network tests after the fixes.

An initial fixture run had three test failures: local lifecycle tests ran before image loading mounted Flame's lifecycle observer; a new queue test left the existing result delay pending at teardown. The fixtures now wait for actual arena attachment and finish the delay. An attempted direct wait on an already-started fake-async loader was interrupted and replaced with bounded real-async/pump readiness. A later parallel command attempt collided on Flutter's engine stamp temp file; final verification was rerun sequentially. Neither interrupted run is completion evidence.

## Final actual verification

All commands used CI=true, FLUTTER_SUPPRESS_ANALYTICS=true and the restored workspace PUB_CACHE. Flutter 3.47.9 / Dart 3.13.7.

| Check | Actual result | Log in /workspace/scratch/2eba1a5ed526/verification/ |
| --- | --- | --- |
| Focused football/feedback/rules/visual suite, 12 files | Exit 0; 90 passed | football-focused-green.log |
| Full Flutter test suite | Exit 0; 207 passed | football-full-green.log |
| flutter analyze --no-fatal-infos --no-fatal-warnings | Exit 0; 0 errors, 3 existing warnings, 182 infos (185 total) | football-analyze.log |
| dart format of owned files | Exit 0 | football-format.log |
| dart format --output=none --set-exit-if-changed lib test | Exit 0; 111 files, 0 changed | football-format-check.log |
| Outcome/Random invariants compared with baseline | Both calculation blocks unchanged ignoring formatting; every Random call retains lexical order/count (elite 18, local 15) | football-invariants.log |

Outgoing payload tests assert exactly nine keys: action, turn, tx, ty, kx, ky, power, curve, outcome. Existing rules tests preserve score/roles/early finish/sudden death. No new assets or WAV files were imported. All tests remain enabled. Layout/geometry covers 320x640, long phone, landscape and text scale 1.3. Round-trip live rotation/lifecycle tests wait for actual loaded photo assets. No optional filmstrip was regenerated in this resumed pass.

Release APK, road/plane stages, CI publishing and final integration remain the parent workflow's responsibility. No commit, push, merge or release build was performed by this worker.
