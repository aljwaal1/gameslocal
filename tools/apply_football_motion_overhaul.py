#!/usr/bin/env python3
"""Import real football photographs and enforce the slower motion contract."""

from __future__ import annotations

import time
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets" / "football" / "photo"

# Real photographs only. Each file is CC0 or public domain and is stored in the
# APK after the first successful main-branch build, so gameplay is fully offline.
ASSETS = {
    "player_ready.png": (
        "https://upload.wikimedia.org/wikipedia/commons/2/23/Best_player.png",
        "Best player.png — Bouakez Moez — CC0",
        "https://commons.wikimedia.org/wiki/File:Best_player.png",
    ),
    "player_run.jpg": (
        "https://upload.wikimedia.org/wikipedia/commons/5/53/Flamengo_v_Vasco_September_2018_IMG_4466_Par%C3%A1_%28cropped%29.jpg",
        "Flamengo v Vasco September 2018 IMG 4466 Pará (cropped).jpg — Nadine Oliverr — CC0",
        "https://commons.wikimedia.org/wiki/File:Flamengo_v_Vasco_September_2018_IMG_4466_Par%C3%A1_(cropped).jpg",
    ),
    "player_kick.jpg": (
        "https://upload.wikimedia.org/wikipedia/commons/d/dd/Zarekkick.jpg",
        "Zarekkick.jpg — Marcusquincy — Public domain",
        "https://commons.wikimedia.org/wiki/File:Zarekkick.jpg",
    ),
    "keeper_ready.jpg": (
        "https://upload.wikimedia.org/wikipedia/commons/1/19/Goal_keeper_during_a_football_game.jpg",
        "Goal keeper during a football game.jpg — Samson Ssemakadde — CC0",
        "https://commons.wikimedia.org/wiki/File:Goal_keeper_during_a_football_game.jpg",
    ),
    "keeper_dive.jpg": (
        "https://upload.wikimedia.org/wikipedia/commons/d/d3/Soccer_goalkeeper.jpg",
        "Soccer goalkeeper.jpg — Master Sgt. Lance Cheung, U.S. Air Force — Public domain",
        "https://commons.wikimedia.org/wiki/File:Soccer_goalkeeper.jpg",
    ),
}


def valid_image(data: bytes) -> bool:
    return data.startswith(b"\x89PNG\r\n\x1a\n") or data.startswith(b"\xff\xd8\xff")


def download_image(url: str, destination: Path) -> None:
    errors: list[str] = []
    for attempt in range(1, 5):
        try:
            request = Request(
                url,
                headers={
                    "User-Agent": "gameslocal-football-photo-importer/3.0",
                    "Accept": "image/png,image/jpeg,*/*",
                },
            )
            with urlopen(request, timeout=180) as response:  # noqa: S310
                data = response.read()
            if not valid_image(data):
                raise RuntimeError(f"Response is not PNG/JPEG ({len(data)} bytes)")
            destination.write_bytes(data)
            print(f"Downloaded {destination.name}: {len(data)} bytes")
            return
        except Exception as exc:  # Keep complete diagnostics in GitHub logs.
            errors.append(f"attempt {attempt}: {type(exc).__name__}: {exc}")
            time.sleep(attempt * 2)
    raise RuntimeError(f"Unable to download {url}: {' | '.join(errors)}")


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
        "# Photographic football assets",
        "",
        "These photographs are bundled locally for offline gameplay. GamesLocal",
        "uses them as full-screen cinematic action frames and does not claim",
        "endorsement by the photographed players or photographers.",
        "",
    ]
    for filename, (download_url, credit, page_url) in ASSETS.items():
        lines.extend(
            [
                f"- `{filename}` — {credit}",
                f"  - Source page: {page_url}",
                f"  - Downloaded from: {download_url}",
            ]
        )
    lines.append("")
    (ASSET_DIR / "SOURCES.md").write_text("\n".join(lines), encoding="utf-8")


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
    expect(frameSource, contains('assets/football/photo/player_ready.png'));
    expect(frameSource, contains('assets/football/photo/player_run.jpg'));
    expect(frameSource, contains('assets/football/photo/player_kick.jpg'));
    expect(frameSource, contains('assets/football/photo/keeper_ready.jpg'));
    expect(frameSource, contains('assets/football/photo/keeper_dive.jpg'));
    expect(frameSource, isNot(contains('SvgPicture')));

    for (final asset in <String>[
      'assets/football/photo/player_ready.png',
      'assets/football/photo/player_run.jpg',
      'assets/football/photo/player_kick.jpg',
      'assets/football/photo/keeper_ready.jpg',
      'assets/football/photo/keeper_dive.jpg',
      'assets/football/photo/SOURCES.md',
    ]) {
      final file = File(asset);
      expect(file.existsSync(), isTrue, reason: 'Missing $asset');
      expect(file.lengthSync(), greaterThan(20000), reason: 'Invalid $asset');
    }
  });
}
""",
        encoding="utf-8",
    )


def main() -> None:
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    for filename, (url, _credit, _page_url) in ASSETS.items():
        destination = ASSET_DIR / filename
        if not destination.exists() or not valid_image(destination.read_bytes()[:16]):
            download_image(url, destination)
    patch_game_timing()
    write_sources()
    write_contract_test()
    print("Photographic football overhaul applied successfully.")


if __name__ == "__main__":
    main()
