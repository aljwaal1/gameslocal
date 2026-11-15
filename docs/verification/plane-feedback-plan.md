# Plane follow-up — 2026-11-15

Request: flight engine, firing, explosion and refuel audio; visible remaining fuel; ships and planes instead of stones. Work on feature/world-class-ui-v2 only, no main merge.

Implementation choice: retain synthesized feedback through GameFeedback; dedicated owned motor loop; per-event short cues with cancellation. Preserve timing, Random calls, scores, collision thresholds and network payloads (obstacle index 1 becomes a ship visually). Make the fuel label, bar and percentage obvious, preserve low-fuel alert, inspect 320x640 / long / landscape at text scale 1.3.

Validation: failing actual-widget audio/event/HUD tests and canvas pixel tests first; implement; focused and full Flutter tests; format/analyze; independent review; GitHub Actions Release and real APK before delivery. Guest snapshots must not manufacture pickup/hit sounds at start or repeat them. Pause/removal/restart cancels pending/playing audio.
