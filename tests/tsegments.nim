import std/[strutils, unittest]
import ../src/shiori/[segments]
import helpers

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
