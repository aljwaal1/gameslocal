# Audio audit — 2026-11-06

Source: aljwaal1/carsgame; measured PCM WAVs. No samples clipped at >=32760.

| Cue | Duration (s) | Peak | RMS | PCM bytes |
|---|---:|---:|---:|---:|
| fuel_pickup.wav | 0.220 | 0.320 | 0.082 | 19404 |
| plane_explosion.wav | 0.420 | 0.453 | 0.131 | 37044 |
| plane_shoot.wav | 0.100 | 0.312 | 0.092 | 8820 |
| car_crash.wav | 0.380 | 0.486 | 0.136 | 33516 |
| car_pass.wav | 0.100 | 0.227 | 0.066 | 8820 |
| stage_clear.wav | 0.450 | 0.296 | 0.065 | 39690 |
| weather_change.wav | 0.350 | 0.229 | 0.059 | 30868 |

Decision: retain the existing synthesized per-game feedback layer unless listening and gameplay demonstrate a benefit. No imported WAV bytes and no added APK audio weight. Objective metrics alone do not prove perceived quality.
Source engines/config/models have been inspected as references; existing integrated engines already match their spawn and scoring values. Presentation changes must preserve ArcadeTiming and network payloads.
