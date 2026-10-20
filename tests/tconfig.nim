import std/[os, unittest]
import ../src/shiori/[config]
import helpers

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
