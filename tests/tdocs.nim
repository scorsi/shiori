import std/[os, strutils, tables, unittest]
import toml_serialization
import helpers

proc keys(value: TomlValueRef, prefix = ""): seq[string] =
  for key, child in value.tableVal:
    let path = if prefix == "": key else: prefix & "." & key
    result.add path
    if child.kind in {TomlKind.Table, TomlKind.InlineTable}:
      result.add keys(child, path)

proc documented(path: string): string =
  let parts = path.split('.')
  if parts[0] == "palettes" and parts.len > 1:
    return if parts.len == 2: "palettes.<name>" else: "palettes.<name>.<colour>"
  if parts.len == 2 and parts[1] in ["format", "symbol", "style", "disabled"]:
    return "segment." & parts[1]
  path

suite "docs":
  test "README documents every TOML key in every preset":
    let readme = readFile(here.parentDir / "README.md")
    for preset in walkFiles(here.parentDir / "presets" / "*.toml"):
      for key in keys(Toml.decode(readFile(preset), TomlValueRef)):
        echo preset.extractFilename & ": " & key
        check ("`" & documented(key) & "`") in readme

  test "only shared segment keys and arbitrary palette names are generalized":
    check documented("context.bar_width") == "context.bar_width"
    check documented("cost.undocumented") == "cost.undocumented"
    check documented("model.format") == "segment.format"
    check documented("palettes.custom.accent") == "palettes.<name>.<colour>"
