import std/[os, tables, unittest]
import toml_serialization
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

  test "fill units cannot introduce extra status lines":
    for key in ["format", "symbol"]:
      expect ValueError:
        discard parseConfig("[fill]\n" & key & " = \"x\\ny\"")

  test "every preset parses":
    let defaults = Toml.decode(readFile(here.parentDir / "presets" / "plain.toml"), TomlValueRef)
    for path in walkFiles(here.parentDir / "presets" / "*.toml"):
      checkpoint path
      discard parseConfig(readFile(path))
      let preset = Toml.decode(readFile(path), TomlValueRef)
      for key, value in defaults.tableVal:
        check preset.tableVal.hasKey(key)
        if key != "palettes" and value.kind == TomlKind.Table:
          for sub in value.tableVal.keys: check preset.tableVal[key].tableVal.hasKey(sub)

  test "arbitrary palette names and colours, including inline tables":
    let c = parseConfig("""
palette = "my-theme"
palettes = { my-theme = { accent = "#123456", green = "42" } }
[model]
style = "bold accent bg:green"
""")
    check c.palette["accent"] == "#123456"
    check c.palette["green"] == "42"

  test "invalid palettes and literal format styles reject the whole config":
    for bad in ["palette = 'missing'", "palette = 1", "palettes = 1",
        "[palettes]\nbad = 1", "[palettes.x]\nred = 1", "[palettes.x]\nred = 'bold'",
        "[palettes.x]\nred = 'alias'", "format = '$palettes'", "format = '[x](unknown)'",
        "[model]\nformat = '[$name](unknown)'", "[model]\nstyle = 'accent'"]:
      checkpoint bad
      expect CatchableError: discard parseConfig(bad)
