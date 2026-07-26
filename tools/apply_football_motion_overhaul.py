#!/usr/bin/env python3
"""Import CC0 football artwork and enforce the slower motion contract.

This script is intentionally idempotent. It is executed once by a branch-only
workflow so the downloaded public-domain SVG files become normal repository
assets and future builds remain fully offline.
"""

from __future__ import annotations

from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets" / "football" / "cc0"

ASSETS = {
    "player_ready.svg": (
        "https://openclipart.org/download/341701",
        "Football player — OpenClipart #341701",
    ),
    "player_run.svg": (
        "https://openclipart.org/download/194544",
        "Soccer Player (Green/Black) — OpenClipart #194544",
    ),
    "player_kick.svg": (
        "https://openclipart.org/download/349151",
        "Soccer Player — OpenClipart #349151",
    ),
    "keeper_ready.svg": (
        "https://openclipart.org/download/316443",
        "Goalkeeper — OpenClipart #316443",
    ),
    "keeper_dive.svg": (
        "https://openclipart.org/download/282558",
        "The goalkeeper — OpenClipart #282558",
    ),
}


def download_svg(url: str, destination: Path) -> None:
    request = Request(
        url,
        headers={
            "User-Agent": "gameslocal-football-asset-importer/1.0",
            "Accept": "image/svg+xml,text/xml,*/*",
        },
    )
    with urlopen(request, timeout=180) as response:  # noqa: S310 - fixed URLs
        data = response.read()
    if b"<svg" not in data[:2000].lower():
        raise RuntimeError(f"Downloaded file is not SVG: {url}")
    destination.write_bytes(data)


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


def write_sources() -> None:
    lines = [
        "# Football artwork sources",
        "",
        "The files in this directory are imported from OpenClipart and are used",
        "under the Creative Commons Zero (CC0) public-domain dedication.",
        "",
    ]
    for filename, (url, title) in ASSETS.items():
        detail_id = url.rsplit("/", 1)[-1]
        lines.extend(
            [
                f"- `{filename}` — {title}",
                f"  - Detail: https://openclipart.org/detail/{detail_id}",
                f"  - Download: {url}",
            ]
        )
    lines.extend(
        [
            "",
            "The original artwork is kept intact. GamesLocal only positions and",
            "animates the SVG layers inside the penalty scene.",
            "",
        ]
    )
    (ASSET_DIR / "SOURCES.md").write_text("\n".join(lines), encoding="utf-8")


def write_contract_test() -> None:
    path = ROOT / "test" / "professional_penalty_visual_contract_test.dart"
    path.write_text(
        """import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('penalty mode keeps slow staged motion and CC0 human artwork', () {
    final gameSource = File(
      'lib/games/football/professional_penalty_game.dart',
    ).readAsStringSync();
    final compatibilityScene = File(
      'lib/games/football/professional_penalty_scene.dart',
    ).readAsStringSync();
    final realisticScene = File(
      'lib/games/football/realistic_penalty_scene.dart',
    ).readAsStringSync();
    final spriteSource = File(
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
    expect(realisticScene, contains('RealisticFootballSprite'));
    expect(realisticScene, contains('_quadraticBezier'));
    expect(realisticScene, contains('_drawNetImpact'));
    expect(realisticScene, isNot(contains('_drawFootballerBody')));
    expect(realisticScene, isNot(contains('_drawKeeperBody')));

    expect(spriteSource, contains('assets/football/cc0/player_ready.svg'));
    expect(spriteSource, contains('assets/football/cc0/player_run.svg'));
    expect(spriteSource, contains('assets/football/cc0/player_kick.svg'));
    expect(spriteSource, contains('assets/football/cc0/keeper_ready.svg'));
    expect(spriteSource, contains('assets/football/cc0/keeper_dive.svg'));

    for (final asset in <String>[
      'assets/football/cc0/player_ready.svg',
      'assets/football/cc0/player_run.svg',
      'assets/football/cc0/player_kick.svg',
      'assets/football/cc0/keeper_ready.svg',
      'assets/football/cc0/keeper_dive.svg',
      'assets/football/cc0/SOURCES.md',
    ]) {
      expect(File(asset).existsSync(), isTrue, reason: 'Missing $asset');
    }
  });
}
""",
        encoding="utf-8",
    )


def main() -> None:
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    for filename, (url, _title) in ASSETS.items():
        destination = ASSET_DIR / filename
        if not destination.exists() or b"<svg" not in destination.read_bytes()[:2000].lower():
            download_svg(url, destination)
    patch_game_timing()
    write_sources()
    write_contract_test()
    print("Football motion overhaul applied successfully.")


if __name__ == "__main__":
    main()
