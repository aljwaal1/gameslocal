# Road presentation verification — 2026-11-06

## Result and scope

Replaced the integrated pixel painter with a smooth Canvas scene. `RoadSceneGeometry` is independent of the widget and provides depth, projection, road width, car size and inverse touch mapping. The collision plane remains the simulation's y=.82; the previous painter drew the player at .84. All cars now share the same projection, including local/remote cars. At the contact plane, horizontal projection remains exactly world x × viewport width for every aspect ratio.

The scene has gently textured asphalt, perspective shoulders and edges, animated corridor markings and roadside reflectors, curved vector car shells, roofs, glass, wheels, lights, shadows and highlights. Steering settles through a small rotation around the unchanged center. Day, sunset, night, fog, snow and rain have distinct palettes; distant fog fades before the contact plane and headlights preserve readability. The light HUD sits outside the field and adapts to short landscape screens. No image assets, retro pixels, scanlines or CRT effects remain in Road.

Production changes are limited to `lib/games/retro_road/`. No shared audio, network core, ArcadeTiming or other game's implementation changed in this package.

## Rules and wire invariants

Reference inspected: `carsgame` commit `fedb200b784fb8ec37fcf778cafccb32fa1be6bd`, specifically Road engine, config, models, weather and audio. Its old painter was not reused. Existing integrated timing already adapts the reference engine through ArcadeTiming.

Compared against the pre-change integrated file at `72e870cd92ce2906d2b21623fdddfd8ad3b3aa6d`. Whitespace-normalized bodies of all ten methods are SHA-256 identical: `start`, `tick`, `updateWeather`, `hasCrashAt`, `move`, `dragRoad`, `_sendRoadControl`, `_sendState`, `_onNetworkMessage`, `_showEffect`.

The audit is in `verification/road-invariants.json` outside the checkout. Thus spawn probability, RNG order, speed, score/day thresholds, steering multipliers, strict collision thresholds (.050 horizontal / .066 vertical), timing, authority, result mapping, payload names and cue selection are unchanged. Touch calls pass through the shared inverse projection before calling the unchanged drag method.

The existing synthesized road cues were retained after reviewing `docs/verification/audio-audit.md`. No WAV imports, duplicate event cues or APK audio bytes were added.

## Tests and evidence

All checks ran sequentially using the pinned Flutter runtime and pub cache. No tests are skipped or disabled.

- Initial RED: missing geometry API plus three actual screen failures, `verification/road-red.log`.
- Additional behavioral RED: extreme finite viewport produced nonfinite projection, `verification/road-red-extreme-finite.log`. Geometry now bounds invalid/overflowing dimensions without affecting supported viewports.
- Focused GREEN: 15 enabled tests, `verification/road-green.log`.
- Final complete suite: **222 passed**, no skips, `verification/road-full-test.log`.
- Analysis: exit 0, **0 errors, 0 warnings**, 163 existing informational findings (previous package baseline 185). New geometry, painter and Road tests have no findings. Five preserved engine-method infos remain unchanged. `verification/road-analyze.log`.
- Format validation: seven Road files checked, zero changes, `verification/road-format-check.log`.
- Actual integrated raster capture with real DejaVu Sans and Material Icons: passed, `verification/road-captures.log`.

Coverage includes monotonic depth, symmetric projection, safe offscreen/NaN/infinite/extreme geometry, contact-plane invariance, inverse touch, depth car sizes, all six weather states at **320×640, 390×844 and 640×320 with text scale 1.3**, no widget overflow, stable game State/score across live rotation, working post-rotation drag, real host collision termination, strict live collision thresholds, pass/day scoring, complete host start payload, client request/result mapping, and pixel assertions proving local/remote/traffic cars remain distinct at the contact plane.

`road_visual_capture_test.dart` always runs its integrated raster assertions. `--dart-define=ROAD_CAPTURE=true` additionally loads review fonts and writes PNGs; it does not enable otherwise skipped tests.

All 18 PNGs are under `verification/road/road-{320x640,390x844,640x320}-{day,sunset,night,fog,snow,rain}.png` outside the checkout. Portrait and landscape day/fog/night/rain captures were visually inspected. No clipping or HUD obstruction was observed.

## Limits and handoff

These checks exercise real Flutter layout, Canvas rasterization, input, simulation and wire fixtures. Physical-device frame rate, audio listening and Android installation remain release validation work for the root integration. No APK, commit, push or merge is claimed by this package. Independent root review precedes publication and the Plane package.
