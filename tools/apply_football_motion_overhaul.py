#!/usr/bin/env python3
"""Validate committed football photographs and enforce motion timing offline.

This script deliberately does not generate or overwrite tests or scene files.
Tests are source-controlled and must remain unchanged during CI.
"""

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


def main() -> None:
    validate_offline_assets()
    patch_game_timing()
    print("Offline football assets and timing verified without rewriting tests.")


if __name__ == "__main__":
    main()
