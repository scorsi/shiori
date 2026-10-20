# The whole suite (ADR 0008). `buildNimPackage` runs tests/t*.nim in its check phase.
# SHIORI_UPDATE_SNAPSHOTS=1 rewrites tests/snapshots/ instead of comparing.

import std/[json, options, os, strutils, unittest]
import ../src/shiori/[input, config, format, style, segments, render]

const
  here = currentSourcePath().parentDir
  # Every fixture is rendered at this instant: 2026-10-20T12:00:00Z.
  now = 1792497600'i64
  fixtures = ["full", "minimal", "invalid", "pre-first-reply", "free-plan"]

proc fixture(name: string): string = readFile(here / "fixtures" / name & ".json")

proc renderWith(toml, json: string): string = render(parseInput(json), parseConfig(toml), now)

suite "format":
  test "variables, braces and text":
    let f = parseFormat("a $x ${y}z $")
    check f.len == 5
    check f[0].text == "a "
    check f[1].name == "x"
    check f[3].name == "y"
    check f[4].text == "z $"
    check f.variables == @["x", "y"]

  test "nested groups":
    let f = parseFormat("[a [$b](dim)](bold red)")
    check f.len == 1
    check f[0].style == "bold red"
    check f[0].children[1].children[0].name == "b"
    check f.variables == @["b"]

  test "escapes":
    let f = parseFormat("\\$x \\[y\\] \\\\ \\n")
    check f.len == 1
    check f[0].text == "$x [y] \\ \\n"

  test "newlines are text":
    check parseFormat("$a\n$b").len == 3

  test "errors":
    for bad in ["[x", "[x]", "[x](dim", "x]", "${}", "${a"]:
      expect ValueError:
        discard parseFormat(bad)

suite "style":
  test "words":
    check sgr("") == ""
    check sgr("none") == ""
    check sgr("bold cyan") == "\e[1;36m"
    check sgr("bright-red bg:blue") == "\e[91;44m"
    check sgr("208 bg:#a6e3a1") == "\e[38;5;208;48;2;166;227;161m"

  test "unknown words":
    for bad in ["blinky", "256", "#12345", "bg:nope"]:
      expect ValueError:
        discard sgr(bad)

suite "input":
  test "invalid or non-object JSON gives an empty input":
    for text in ["", "garbage", "[1, 2]", "42", "null"]:
      check parseInput(text) == Input()

  test "wrong types are none":
    let i = parseInput("""{"model": {"display_name": 3}, "context_window": {"used_percentage": "7"},
      "rate_limits": {"five_hour": {"resets_at": 1.5}}}""")
    check i.modelName.isNone
    check i.contextPercentage.isNone
    check i.fiveHour.resetsAt.isNone

  test "integers are accepted as floats":
    check parseInput("""{"cost": {"total_cost_usd": 2}}""").costUsd == some(2.0)

  test "contract: full has every field of ADR 0003":
    let root = parseJson(fixture("full"))
    for path in [@["model", "display_name"], @["model", "id"], @["effort", "level"],
        @["context_window", "used_percentage"], @["context_window", "total_input_tokens"],
        @["context_window", "context_window_size"],
        @["rate_limits", "five_hour", "used_percentage"], @["rate_limits", "five_hour", "resets_at"],
        @["rate_limits", "seven_day", "used_percentage"], @["rate_limits", "seven_day", "resets_at"],
        @["cost", "total_cost_usd"], @["cost", "total_duration_ms"],
        @["cost", "total_lines_added"], @["cost", "total_lines_removed"],
        @["workspace", "current_dir"], @["cwd"], @["workspace", "project_dir"],
        @["session_name"], @["vim", "mode"], @["version"]]:
      checkpoint path.join(".")
      check root{path} != nil

suite "config":
  test "errors are rejected whole":
    for bad in ["format = ", "colour = 1", "[context]\nbar_widht = 3", "[context]\nbar_width = \"3\"",
        "format = \"$nope\"", "format = \"[x\"", "[model]\nstyle = \"blinky\"",
        "[effort]\nhide_levels = [1]"]:
      checkpoint bad
      expect CatchableError:
        discard parseConfig(bad)

  test "user keys override defaults, the rest is kept":
    let c = parseConfig("[context]\nbar_width = 4\n")
    check c.integer("context", "bar_width") == 4
    check c.integer("context", "threshold_warn") == 70

  test "every preset parses":
    for path in walkFiles(here.parentDir / "presets" / "*.toml"):
      checkpoint path
      discard parseConfig(readFile(path))

suite "segments":
  test "tokens and durations":
    check humanTokens(999) == "999"
    check humanTokens(45_000) == "45k"
    check humanTokens(1_000_000) == "1M"
    check humanTokens(1_500_000) == "1.5M"
    check timeUntil(now + 7980, now) == "2h13m"
    check timeUntil(now + 183_600, now) == "2d3h"
    check timeUntil(now - 5, now) == "0m"

  test "hidden effort level":
    let json = fixture("full")
    check "medium" notin renderWith("[effort]\nhide_levels = [\"medium\"]", json)

  test "disabled segment":
    check renderWith("[model]\ndisabled = true", fixture("full")).find("Opus") < 0

  test "unreferenced segments are not shown":
    check renderWith("format = \"$model\"", fixture("full")) == "\e[1;36mOpus 5.5\e[0m"

  test "gauge thresholds":
    let json = """{"context_window": {"used_percentage": 95}}"""
    check renderWith("format = \"$context\"\n[context]\nformat = \"[x]($style)\"", json) == "\e[31mx\e[0m"

suite "render":
  test "an empty group disappears with its text":
    check renderWith("format = \"$model[ <$effort>]()\"", """{"model": {"id": "m"}}""") ==
      "\e[1;36mm\e[0m"

  test "a group with no variables stays":
    check renderWith("format = \"[x](dim)\"", "{}") == "\e[2mx\e[0m"

  test "multiline format, no trailing newline":
    check renderWith("format = \"\"\"\n$model\n$effort\n\"\"\"\n[model]\nstyle = \"\"\n[effort]\nstyle = \"\"",
      fixture("full")) == "Opus 5.5\nmedium"

  test "snapshots, plain preset":
    let plain = readFile(here.parentDir / "presets" / "plain.toml")
    for name in fixtures:
      checkpoint name
      let path = here / "snapshots" / name & ".plain.txt"
      let got = renderWith(plain, fixture(name)) & "\n"
      if existsEnv("SHIORI_UPDATE_SNAPSHOTS"): writeFile(path, got)
      else: check got == readFile(path)
