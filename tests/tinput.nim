import std/[json, options, strutils, unittest]
import ../src/shiori/[input]
import helpers

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
