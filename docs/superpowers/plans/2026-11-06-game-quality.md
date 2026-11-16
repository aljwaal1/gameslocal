# Games quality implementation plan

Goal: ship a verified release APK on feature/world-class-ui-v2 without merging main.
Architecture: pure geometry/physics/timeline controllers with Flutter integration and behavioral tests. Existing game rules, random call order, ArcadeTiming, and wire payload keys remain authoritative.
Tech Stack: Flutter, Dart, Flame, audioplayers, GitHub Actions.
Spec: user specification supplied 2026-11-06 (this plan records implementation boundaries).

## Global constraints
- Work only on feature/world-class-ui-v2; never merge PR 66 or modify main.
- Preserve game rules, score, network authority and all payload keys.
- Tests first for each significant change; focused tests, then full test/analyze after each package.
- No RetroPixels/CRT in road or plane; use smooth Canvas drawing.
- Final verification: pub get; dart format lib test; format check; analyze; test; release APK.

## Tasks
1. Cards: introduce Hand51CardLayout, shared rendering/hit geometry, real horizontal scrolling with >=24px exposed headers for 20 cards at width 320 and text scale 1.3. Bigger high-contrast corner identities both ends, joker. PlayingCardView large rank/suit plus corners; single scrollable hand; widget selection tests at both scales and width 320.
2. Hockey: independent pixel-unit bot profiles/state/controller with response .24/.16/.09, bounded acceleration/velocity, conditional attack/prediction/defensive return and dt guard. Independent contact response with restitution .90, normal transfer .65, separation 1px, universal 900px/s cap; integrate unchanged scoring/network. Unit tests edge cases and widget modes.
3. Football: independent shared timeline with .22 plant, .28 approach end, .26 keeper push, .34 contact, .38 launch, .48 reach, .58 follow through, .84 reach end, .86 arrival, 1 landing. Cancellation lifetime in feedback with await guards and player ownership. Local then remote integration: no flight before launch, feedback once at contact/arrival, no visible result before arrival, immediate shot message with exact existing keys. Test cancellation and timeline ordering.
4. Road: inspect carsgame engines/models/config/audio. Independent bounded RoadSceneGeometry and 2.5D smooth asphalt/vector cars, depth sizing, six readable weather states, lightweight HUD. Preserve engine, ArcadeTiming, collision and network. Geometry + widget aspect/paint tests.
5. Plane: independent bounded PlaneSceneGeometry, symmetric bounded bank, smooth vector planes, layered aerial background, pickups/enemies/bullets/explosion and local/remote distinction, readable low fuel HUD. Preserve engine, ArcadeTiming and network. Geometry + aspect/paint tests.
6. Integration: independent review per subsystem; final full suite, analyze, format, CI on target branch, release artifact and direct APK URL. Inspect imported WAVs for silence/clipping/duration and avoid duplicate events; prefer existing feedback if better.

Each task: write behavioral tests, observe expected failure, implement, pass focused/full checks, review spec+quality, commit and push target branch. Record evidence in progress log.

## Review focus
Narrow 320px and landscape layouts; scale 1.3 identities; large/invalid dt; feedback cancellation races; delayed network shot results.
