# Game Quality Overhaul Design

## Intent

Raise all 13 production games to a consistent mobile-game quality bar without changing their established rules. The overhaul covers logic integrity, visual clarity, proportions, physics, responsive layout, instructions, sound feedback, and multiplayer honesty.

## Goals

- Make every advertised play mode real and hide unsupported modes.
- Keep one authoritative rules path per game across offline, LAN, and Internet play.
- Make rendered movement and collision agree with scored outcomes.
- Use responsive sizes and touch targets suitable for small Android phones.
- Give every game concise first-play instructions and clear phase-specific guidance.
- Remove duplicate feedback and improve event-specific sound/haptics.
- Add behavioral tests for rules and regressions instead of source-string checks alone.

## Non-goals

- Do not change the Sheikh Beard rule that every completed straight line counts.
- Do not merge PR #66 or modify `main`.
- Do not publish an unverified APK.
- Do not add country-specific variants of board or card rules without an explicit selector.

## Constraints

- Flutter/Android, Arabic-first RTL UI.
- Offline play must remain available.
- Existing LAN and Internet message validation remains authoritative.
- Host-authoritative simulation for real-time network games.
- One final release APK after tests and analysis pass.

## Approach

Use an incremental shared-foundation approach. First establish explicit game capabilities, shared help presentation, and reusable feedback/physics helpers. Then repair the highest-risk games (Hand 51 mode honesty, football consistency, hockey geometry), improve time-based arcade simulation and responsive layouts, and finally harden all games with behavioral tests. This is safer than rewriting all games and more complete than applying isolated cosmetic patches.

## Quality bar

- Important text is at least 11 logical pixels; primary instructions are at least 12.
- Interactive targets are at least 44×44 logical pixels.
- Physics uses elapsed time and aspect-correct coordinates.
- Network clients interpolate snapshots rather than visibly snapping.
- A result shown to the player must be derived from the same authoritative state used for scoring.
- Unsupported modes never appear as selectable options.

