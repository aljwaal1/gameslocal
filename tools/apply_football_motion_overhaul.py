#!/usr/bin/env python3
"""Import CC0 football artwork and enforce the slower motion contract."""

from __future__ import annotations

import json
import time
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets" / "football" / "cc0"

ASSETS = {
    "player_ready.svg": (
        "341701",
        "https://openclipart.org/download/341701",
        "Football player — OpenClipart #341701",
    ),
    "player_run.svg": (
        "194544",
        "https://openclipart.org/download/194544",
        "Soccer Player (Green/Black) — OpenClipart #194544",
    ),
    "player_kick.svg": (
        "349151",
        "https://openclipart.org/download/349151",
        "Soccer Player — OpenClipart #349151",
    ),
    "keeper_ready.svg": (
        "316443",
        "https://openclipart.org/download/316443",
        "Goalkeeper — OpenClipart #316443",
    ),
    "keeper_dive.svg": (
        "282558",
        "https://openclipart.org/download/282558",
        "The goalkeeper — OpenClipart #282558",
    ),
}


def request_bytes(url: str, accept: str) -> bytes:
    request = Request(
        url,
        headers={
            "User-Agent": "gameslocal-football-asset-importer/2.0",
            "Accept": accept,
        },
    )
    with urlopen(request, timeout=180) as response:  # noqa: S310 - fixed URLs
        return response.read()


def fetch_svg_from_dataset(openclipart_id: str) -> bytes:
    where = f'"page_url" LIKE \'%/{openclipart_id}/%\''
    query = urlencode(
        {
            "dataset": "kawwaaa/openclipart",
            "config": "default",
            "split": "train",
            "where": where,
            "offset": 0,
            "length": 1,
        }
    )
    endpoint = f"https://datasets-server.huggingface.co/filter?{query}"
    payload = json.loads(request_bytes(endpoint, "application/json"))
    rows = payload.get("rows") or []
    if not rows:
        raise RuntimeError(f"Dataset mirror has no row for OpenClipart #{openclipart_id}")
    svg = rows[0].get("row", {}).get("svg_content")
    if not isinstance(svg, str) or "<svg" not in svg[:2000].lower():
        raise RuntimeError(f"Dataset mirror returned invalid SVG for #{openclipart_id}")
    return svg.encode("utf-8")


def download_svg(openclipart_id: str, url: str, destination: Path) -> None:
    errors: list[str] = []
    for attempt in range(1, 4):
        try:
            print(f"Fetching OpenClipart #{openclipart_id} from dataset mirror (attempt {attempt})")
            data = fetch_svg_from_dataset(openclipart_id)
            destination.write_bytes(data)
            return
        except Exception as exc:  # network diagnostics are retained for CI logs
            errors.append(f"mirror attempt {attempt}: {exc}")
            time.sleep(attempt * 2)

    for attempt in range(1, 4):
        try:
            print(f"Fetching OpenClipart #{openclipart_id} directly (attempt {attempt})")
            data = request_bytes(url, "image/svg+xml,text/xml,*/*")
            if b"<svg" not in data[:2000].lower():
                raise RuntimeError("response is not SVG")
            destination.write_bytes(data)
            return
        except Exception as exc:
            errors.append(f"direct attempt {attempt}: {exc}")
            time.sleep(attempt * 2)

    raise RuntimeError(
        f"Unable to fetch OpenClipart #{openclipart_id}: " + " | ".join(errors)
    )


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
        "A stable CC0 dataset mirror is used by the importer when the original",
        "download server is unavailable.",
        "",
    ]
    for filename, (openclipart_id, url, title) in ASSETS.items():
        lines.extend(
            [
                f"- `{filename}` — {title}",
                f"  - Detail: https://openclipart.org/detail/{openclipart_id}",
                f"  - Original download: {url}",
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
    for filename, (openclipart_id, url, _title) in ASSETS.items():
        destination = ASSET_DIR / filename
        if not destination.exists() or b"<svg" not in destination.read_bytes()[:2000].lower():
            download_svg(openclipart_id, url, destination)
    patch_game_timing()
    write_sources()
    write_contract_test()
    print("Football motion overhaul applied successfully.")


if __name__ == "__main__":
    main()
