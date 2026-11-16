# Game Quality Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve logic, presentation, proportions, instructions, sound, and multiplayer integrity across all 13 production games while preserving established rules.

**Architecture:** Add shared capability/help/feedback primitives, then migrate games in risk order. Keep turn-based games host-authoritative and real-time games host-simulated with aspect-correct physics and interpolated snapshots.

**Tech Stack:** Flutter, Dart, Flame, audioplayers, SharedPreferences, existing LocalNetworkCore/WebSocket relay.

**Spec:** `docs/superpowers/specs/2026-10-29-game-quality-overhaul-design.md`

## Global Constraints

- Keep PR #66 draft and never modify `main`.
- Preserve the rule that every completed straight line counts in Sheikh Beard.
- Do not advertise a mode that the game does not implement.
- Require `flutter test`, `flutter analyze`, and release APK build before completion.
- Deliver one final APK after the whole batch.

## Review Focus

- Small/tall screens: no clipped controls and at least 44×44 touch targets.
- Network delay/duplicates: no double move, score, or reset.
- Aspect ratio: rendered objects and collision geometry stay aligned.
- First launch: instructions explain the objective and main gesture.
- Accessibility settings: disabling sound or vibration suppresses all related feedback.

---

### Task 1: Honest game capabilities and shared instructions

**Files:**
- Modify: `lib/core/game_definition.dart`
- Modify: `lib/core/game_room.dart`
- Modify: `lib/main.dart`
- Create: `lib/core/game_help.dart`
- Test: `test/game_capabilities_test.dart`

- [ ] Write failing behavioral tests for supported offline, robot, local-device, LAN, Internet, and browser modes for all 13 games.
- [ ] Verify the tests fail because capabilities are currently inferred globally.
- [ ] Add explicit immutable capability and instruction metadata to `GameDefinition`.
- [ ] Render only supported room options and add a reusable first-play help sheet.
- [ ] Run the focused and complete test suites.

### Task 2: Feedback correctness

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/core/audio_feedback.dart`
- Modify: `lib/games/football/world_class_penalty_game_v2.dart`
- Test: `test/audio_feedback_behavior_test.dart`

- [ ] Write failing tests that prohibit global gameplay pointer clicks and duplicate direct haptics.
- [ ] Verify failure on the existing global Listener and football calls.
- [ ] Limit UI clicks to actual controls and route each event through one feedback path.
- [ ] Add small deterministic pitch variation for repeated physical impacts without changing result cues.
- [ ] Run all tests.

### Task 3: Football rules and shared presentation

**Files:**
- Create: `lib/games/football/penalty_rules.dart`
- Modify: `lib/games/football/world_class_penalty_game_v2.dart`
- Modify: `lib/games/football/elite_penalty_game_v2.dart`
- Test: `test/penalty_rules_test.dart`

- [ ] Write failing tests for early shootout termination, sudden death, frame/post collision classification, and normalized keeper reach.
- [ ] Verify the current shootout fails early-termination cases.
- [ ] Extract pure shootout rules and collision classification.
- [ ] Make local and network screens consume the same dimensions, assets, and outcome contract.
- [ ] Run all tests.

### Task 4: Aspect-correct hockey physics

**Files:**
- Create: `lib/games/air_hockey/hockey_physics.dart`
- Modify: `lib/games/air_hockey/air_hockey_game.dart`
- Test: `test/hockey_physics_test.dart`

- [ ] Write failing tests showing identical pixel collisions on square and tall fields.
- [ ] Verify normalized Euclidean distance fails tall-field cases.
- [ ] Extract pixel/aspect-correct collision and fixed-step integration.
- [ ] Add bot reaction delay and snapshot interpolation.
- [ ] Run all tests.

### Task 5: Time-based arcade simulation

**Files:**
- Modify: `lib/games/fuel_plane/fuel_plane_game.dart`
- Modify: `lib/games/retro_road/retro_road_game.dart`
- Create: `lib/games/arcade/arcade_timing.dart`
- Test: `test/arcade_timing_test.dart`

- [ ] Write failing tests proving equivalent progress at 30, 60, and 120 Hz.
- [ ] Verify fixed Timer increments fail.
- [ ] Move fuel drain, movement, spawning, and score progress to elapsed-time units.
- [ ] Make road collision and lane bounds perspective-aware.
- [ ] Run all tests.

### Task 6: Turn-based rule and layout hardening

**Files:**
- Modify: `lib/games/xo/xo_game.dart`
- Modify: `lib/games/checkers/checkers_game.dart`
- Modify: `lib/games/domino/domino_premium_game.dart`
- Modify: `lib/games/chess/chess_game.dart`
- Modify: `lib/games/cards/cards_game.dart`
- Modify: `lib/games/hand51/hand51_game.dart`
- Modify: `lib/games/name_animal_object/name_animal_object_game.dart`
- Modify: `lib/games/line_games/line_games.dart`
- Test: `test/turn_game_quality_test.dart`

- [ ] Add failing tests for bot hidden-information boundaries, minimum readable sizes, network reset ownership, and first-play instructions.
- [ ] Verify current failures, including Hand 51 accepting but ignoring network state.
- [ ] Hide unsupported Hand 51 network modes until full synchronization exists.
- [ ] Improve responsive sizing, selection feedback, and stage instructions without changing core rules.
- [ ] Run all tests.

### Task 7: Full verification and release

**Files:**
- Modify: `.github/workflows/build-apk.yml` only if branch verification is not triggered.

- [ ] Run formatting checks.
- [ ] Run `flutter test` and record the exact result.
- [ ] Run `flutter analyze` and record the exact result.
- [ ] Build the release APK.
- [ ] Inspect the final diff for unintended rules or scoring changes.
- [ ] Push only to `feature/world-class-ui-v2`, keep PR #66 draft, and provide the verified APK.

