# Fuel Plane verification

Reviewed the reference Fuel Plane engine, configuration and models in `aljwaal1/carsgame` at `fedb200b784fb8ec37fcf778cafccb32fa1be6bd`. The integrated game keeps its 30 ms simulation and `ArcadeTiming` scaling. Spawn rolls, object indices and hitboxes, bullet movement, fuel drain and pickup, point awards, level progression, co-op and versus results, and existing shared sound cues retain their prior rules. No audio assets were added.

The vector scene draws coastal water, shallow shoreline, islands, moving cloud and mist layers, distinct aircraft, fuel, rocks, bullets, muzzle flashes and short bursts. Projection keeps the visible aircraft center at the simulation contact point. Banking affects sprite presentation only. The fuel HUD gives a percentage and an Arabic text warning, and landscape places the controls beside the flight field.

The existing host remains authoritative over the same start, mode, control, and state messages. An odd terminal tick now sends the final state immediately so the guest receives the result even when the timer has stopped. Guest muzzle and hit visuals derive from existing snapshots. A hit that occurs entirely between snapshots may only be represented by the existing score or status feedback.

## Verification

| Check | Result |
| --- | --- |
| Initial landscape regression | Failed at 640×320 with text scale 1.3 because the Start button could not be hit |
| Initial geometry and painter tests | Failed to load against the old screen because the required scene interfaces were missing |
| Odd terminal tick with old synchronization condition | Failed because the host emitted no final state |
| Focused Fuel Plane suite | 18 passed, zero skipped |
| Whole-project format verification | 125 Dart files, zero changes |
| Whole-project Flutter analyzer | Exit 0 with cached dependencies and nonfatal diagnostics enabled. 99 diagnostics outside Fuel Plane |
| Whole-project Flutter tests | 240 passed, zero skipped |

Focused coverage includes invalid geometry, depth and banking, actual raster colors and terrain, live low fuel and touch/slider controls, local and internet guest mapping and authority, exact start payload, fuel drain and refill, bullet hits and scoring, level transition, co-op continuation and versus termination. The integrated screen was rendered and inspected in RTL at 320×640, 390×844 and 640×320 with text scale 1.3. The local evidence files are `../verification/plane/plane-320x640.png`, `plane-390x844.png`, and `plane-640x320.png`. Recreate them with `flutter test --dart-define=PLANE_CAPTURE=true test/plane_visual_capture_test.dart` in the review workspace. Physical device play and release APK verification are tracked separately from these Flutter tests.
