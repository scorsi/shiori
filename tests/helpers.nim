# Shared by the tests/t*.nim files; not a test itself (buildNimPackage runs only tests/t*.nim).
# SHIORI_UPDATE_SNAPSHOTS=1 makes trender.nim rewrite tests/snapshots/ instead of comparing.

import std/os
import ../src/shiori/[input, config, render]

const
  here* = currentSourcePath().parentDir
  # Every fixture is rendered at this instant: 2026-10-20T12:00:00Z.
  now* = 1792497600'i64
  fixtures* = ["full", "minimal", "invalid", "pre-first-reply", "free-plan"]

proc fixture*(name: string): string = readFile(here / "fixtures" / name & ".json")

proc renderWith*(toml, json: string): string = render(parseInput(json), parseConfig(toml), now)
