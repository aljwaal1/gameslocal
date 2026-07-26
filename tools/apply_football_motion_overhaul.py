#!/usr/bin/env python3
"""Validate committed football photographs and enforce motion timing offline."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets" / "football" / "photo"
IMAGE_ASSETS = (
    "player_ready.jpg",
    "player_run.jpg",
    "player_kick.jpg",
    "keeper_ready.jpg",
    "keeper_dive.jpg",
)


def valid_image(data: bytes) -> bool:
    return data.startswith(b"\xff\xd8\xff") or data.startswith(b"\x89PNG\r\n\x1a\n")


def validate_offline_assets() -> None:
    for name in IMAGE_ASSETS:
        path = ASSET_DIR / name
        if not path.is_file():
            raise RuntimeError(f"Missing committed football photograph: {path}")
        data = path.read_bytes()
        if not valid_image(data[:16]):
            raise RuntimeError(f"Invalid PNG/JPEG header: {path}")
        if len(data) <= 20_000:
            raise RuntimeError(f"Football photograph is too small: {path} ({len(data)} bytes)")

    sources = ASSET_DIR / "SOURCES.md"
    if not sources.is_file() or sources.stat().st_size < 200:
        raise RuntimeError("Missing or incomplete football photo attribution file")


def replace_once(text: str, old: str, new: str) -> str:
    count = text.count(old)
    if count == 0:
        if new in text:
            return text
        raise RuntimeError(f"Expected source fragment not found: {old!r}")
    if count != 1:
        raise RuntimeError(f"Expected one source fragment, found {count}: {old!r}")
    return text.replace(old, new, 1)


def patch_game_timing() -> None:
    path = ROOT / "lib" / "games" / "football" / "professional_penalty_game.dart"
    text = path.read_text(encoding="utf-8")
    text = replace_once(
        text,
        "duration: const Duration(milliseconds: 1320),",
        "duration: const Duration(milliseconds: 3000),",
    )
    text = replace_once(
        text,
        "await Future<void>.delayed(const Duration(milliseconds: 760));",
        "await Future<void>.delayed(const Duration(milliseconds: 1350));",
    )
    text = replace_once(
        text,
        "await Future<void>.delayed(const Duration(milliseconds: 740));",
        "await Future<void>.delayed(const Duration(milliseconds: 1250));",
    )
    path.write_text(text, encoding="utf-8")


def write_contract_test() -> None:
    path = ROOT / "test" / "professional_penalty_visual_contract_test.dart"
    path.write_text(
        """import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('penalty mode keeps slow staged motion and real photo frames', () {
    final gameSource = File(
      'lib/games/football/professional_penalty_game.dart',
    ).readAsStringSync();
    final compatibilityScene = File(
      'lib/games/football/professional_penalty_scene.dart',
    ).readAsStringSync();
    final realisticScene = File(
      'lib/games/football/realistic_penalty_scene.dart',
    ).readAsStringSync();
    final frameSource = File(
      'lib/games/football/realistic_football_sprite.dart',
    ).readAsStringSync();

    expect(gameSource, contains('class ProPenaltyShootoutGameScreen'));
    expect(gameSource, contains('Duration(milliseconds: 3000)'));
    expect(gameSource, contains('Duration(milliseconds: 1350)'));
    expect(gameSource, contains('Duration(milliseconds: 1250)'));
    expect(gameSource, contains("'targetX': targetX"));
    expect(gameSource, contains("'power': _shotPower"));
    expect(gameSource, contains('_robotShot()'));
    expect(gameSource, contains('LocalNetworkCore? networkCore'));

    expect(compatibilityScene, contains('class ProfessionalPenaltyScene'));
    expect(compatibilityScene, contains('RealisticPenaltyScene'));
    expect(realisticScene, contains('class RealisticPenaltyScene'));
    expect(realisticScene, contains('final runT = _phase(0.12, 0.47'));
    expect(realisticScene, contains('final keeperDiveT = _phase(0.66, 0.92'));
    expect(realisticScene, contains('final flightT = _phase(0.60, 0.86'));
    expect(realisticScene, contains('AnimatedSwitcher'));
    expect(realisticScene, contains('_quadraticBezier'));
    expect(realisticScene, contains('_drawNetImpact'));
    expect(realisticScene, isNot(contains('_drawFootballerBody')));
    expect(realisticScene, isNot(contains('_drawKeeperBody')));

    expect(frameSource, contains('Image.asset'));
    expect(frameSource, contains('assets/football/photo/player_ready.jpg'));
    expect(frameSource, contains('assets/football/photo/player_run.jpg'));
    expect(frameSource, contains('assets/football/photo/player_kick.jpg'));
    expect(frameSource, contains('assets/football/photo/keeper_ready.jpg'));
    expect(frameSource, contains('assets/football/photo/keeper_dive.jpg'));
    expect(frameSource, isNot(contains('SvgPicture')));

    for (final asset in <String>[
      'assets/football/photo/player_ready.jpg',
      'assets/football/photo/player_run.jpg',
      'assets/football/photo/player_kick.jpg',
      'assets/football/photo/keeper_ready.jpg',
      'assets/football/photo/keeper_dive.jpg',
    ]) {
      final file = File(asset);
      expect(file.existsSync(), isTrue, reason: 'Missing $asset');
      expect(file.lengthSync(), greaterThan(20000), reason: 'Invalid $asset');
    }

    final sources = File('assets/football/photo/SOURCES.md');
    expect(sources.existsSync(), isTrue);
    expect(sources.lengthSync(), greaterThan(200));
  });
}
""",
        encoding="utf-8",
    )


def main() -> None:
    validate_offline_assets()
    patch_game_timing()
    write_contract_test()
    print("Offline photographic football overhaul verified successfully.")


if __name__ == "__main__":
    main()
