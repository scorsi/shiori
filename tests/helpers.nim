# Shared by the tests/t*.nim files; not a test itself (buildNimPackage runs only tests/t*.nim).
# SHIORI_UPDATE_SNAPSHOTS=1 makes trender.nim rewrite tests/snapshots/ instead of comparing.

import std/[os, strutils, tempfiles]
import ../src/shiori/[input, config, render, cli]

const
  here* = currentSourcePath().parentDir
  # Every fixture is rendered at this instant: 2026-10-20T12:00:00Z.
  now* = fixtureTime

export cli.fixtures, cli.fixture

proc renderWith*(toml, json: string, width = 80): string =
  render(parseInput(json), parseConfig(toml), now, width)

proc snapshot*(toml, name: string): string =
  let home = createTempDir("shiori-", "", here)
  let oldHome = getEnv("HOME")
  defer:
    putEnv("HOME", oldHome)
    removeDir(home)
  putEnv("HOME", home)
  createDir(home / "project" / ".git")
  writeFile(home / "project" / ".git" / "HEAD",
    if name == "detached-head": "0123456789abcdef0123456789abcdef01234567\n"
    else: "ref: refs/heads/main\n")
  result = renderWith(toml, fixture(name).replace("/home/user", home), if name == "narrow": 40 else: 80)
  if result == "": result = "shiori"
