# Road independent specification and code-quality review — 2026-11-06

Verdict: **specification PASS; code-quality PASS. No blocking findings.**

Scope: reviewed the Road, global invariant and reference-audio requirements in `docs/superpowers/specs/2026-11-06-games-quality.md`; the Road diff against baseline `72e870c`; the complete current game, geometry and painter implementations; all four Road behavioral/raster test files; invariant evidence; and the available verification logs. No implementation code was changed and no tests were rerun during this independent review.

## Specification assessment

| Requirement | Review evidence | Assessment |
|---|---|---|
| Independent, safe perspective geometry | `road_scene_geometry.dart:6` owns projection, depth, road width, car size and touch conversion. Depth increases monotonically, symmetric world positions project symmetrically, and the `.82` contact plane projects to the unchanged normalized engine center. Finite viewport dimensions are bounded, including the added `1e308` regression. | Pass |
| Smooth road and vehicles | `road_scene_painter.dart:163` draws asphalt, subtle deterministic aggregate texture, shoulders, edge paint, animated lane marks and posts. `:275` draws curved vehicle bodies, wheels, glass, roof, lights, gloss and ground shadows. The game supplies transient steering lean without moving the collision anchor. | Pass |
| Six weather states and usable HUD | The painter has distinct day, sunset, night, fog, snow and rain treatments. Cars are painted after road fog; headlights and particles retain vehicle visibility. The compact HUD and bottom controls leave the play area visible in landscape. | Pass |
| Existing rules, timing and network behavior | The ten normalized engine/control/effect/wire method bodies in `../verification/road-invariants.json` match baseline. Source inspection confirms unchanged lanes, speeds, score/day transitions, collision thresholds, `ArcadeTiming` use, authority and payload keys. New painter code receives presentation snapshots and does not change the engine. | Pass |
| Audio constraints | Existing `GameFeedback` event calls remain in the unchanged simulation/network methods. There are no added WAV imports, direct audio players, duplicate event cues, or audio dependencies in the new geometry/painter. Reference inspection and measured audio decision are documented in `audio-audit.md`. | Pass |
| Actual behavior and required viewports | Tests exercise geometry, painter pixels, integrated widget pixels, every weather, 320×640, 390×844, 640×320 at scale 1.3, postrotation control, actual host collision, pass/day scoring and host/client wire behavior. | Pass |

## Code-quality assessment

- Geometry and drawing are separated from simulation/network code. `RoadTrafficVisual` contains only immutable presentation values.
- Traffic depth sorting copies the input list (`road_scene_painter.dart:41`); neither engine traffic nor its order is mutated. Texture and weather use deterministic arithmetic and do not consume gameplay RNG calls.
- Car rotation occurs around the projected center. The presentation lean preserves the exact player contact position and touch conversion.
- No `RetroPixels`, CRT effect, or old pixel painter remains in the Road rendering path. Source naming still retains the existing screen/game identity for compatibility.
- New geometry and painter files have no analyzer diagnostics in the reviewed log. The five remaining Road game diagnostics concern unchanged engine code.

## Nonblocking observation

`road_scene_geometry.dart:25` preserves a readable vehicle aspect ratio while bounding its size by both viewport dimensions. Consequently, the drawn silhouette is not an exact outline of the preserved normalized collision envelope, especially in short landscape fields: same-lane sprites can visually overlap before the engine's existing `.066` vertical threshold. This is a presentation precision observation, not a simulation regression or a failure of the required stable collision-center contract. The reviewed rules and thresholds should remain unchanged; exact silhouette-to-hitbox matching can be considered during final visual acceptance.

## Evidence and limits

Reviewed logs show focused **15 passed**, full suite **222 passed with no skips**, analyzer **163 nonfatal diagnostics**, and the Road format check **7 files, 0 changed**. The extreme finite-viewport failure was reproduced in `road-red-extreme-finite.log` before the final geometry guard; the final focused log includes its passing regression. These are existing execution logs inspected by the reviewer, not reviewer reruns.

Visually inspected the integrated 640×320 night, 390×844 snow and 320×640 sunset PNGs at scale 1.3. All show smooth perspective road geometry, visible local/remote/traffic cars, readable HUD and accessible controls. The implementer/root also reviewed day, fog and rain captures; the raster suites exercise all 18 weather/viewport combinations.

This review approves the Road subsystem at the reviewed source state. It does not claim a release APK, device playtest, or final Plane/integration approval.
