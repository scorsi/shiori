## TOML configuration (ADR 0004): a user file over the built-in `plain` preset, all or nothing.

import std/[os, strutils, tables]
import toml_serialization
import format, style

type Config* = object
  user, defaults: TomlValueRef
  palette*: Palette

const plainToml = staticRead("../../presets/plain.toml")

proc isTable(v: TomlValueRef): bool =
  v.kind in {TomlKind.Table, TomlKind.InlineTable}

proc lookup(t: TomlValueRef, key: string): TomlValueRef =
  if not t.isNil and t.isTable and t.tableVal.hasKey(key): t.tableVal[key] else: nil

proc value(c: Config, segment, key: string): TomlValueRef =
  result = c.user.lookup(segment).lookup(key)
  if result.isNil: result = c.defaults.lookup(segment).lookup(key)
  if result.isNil: raise newException(KeyError, "no default for " & segment & "." & key)

proc str*(c: Config, segment, key: string): string = c.value(segment, key).stringVal
proc integer*(c: Config, segment, key: string): int = c.value(segment, key).intVal.int
proc boolean*(c: Config, segment, key: string): bool = c.value(segment, key).boolVal

proc strings*(c: Config, segment, key: string): seq[string] =
  for v in c.value(segment, key).arrayVal: result.add v.stringVal

proc topFormat*(c: Config): string =
  let v = c.user.lookup("format")
  if not v.isNil: v.stringVal else: c.defaults.lookup("format").stringVal

proc sameKind(a, b: TomlValueRef): bool =
  a.kind == b.kind or (a.isTable and b.isTable)

proc checkFormat(f: Format, palette: Palette) =
  for node in f:
    if node.kind == nkGroup:
      if not node.style.startsWith("$"): discard sgr(node.style, palette)
      checkFormat(node.children, palette)

proc checkValue(path: string, v: TomlValueRef, palette: Palette) =
  ## Formats and literal styles are parsed now, so a typo fails at load rather than at render.
  if v.kind != TomlKind.String: return
  if path.endsWith("format"): checkFormat(parseFormat(v.stringVal), palette)
  elif path.contains("style") and not v.stringVal.startsWith("$"): discard sgr(v.stringVal, palette)

proc readPalette(user: TomlValueRef): Palette =
  let palettes = user.lookup("palettes")
  if not palettes.isNil:
    if not palettes.isTable: raise newException(ValueError, "wrong type for palettes")
    for name, colours in palettes.tableVal:
      if not colours.isTable: raise newException(ValueError, "wrong type for palettes." & name)
      for colour, value in colours.tableVal:
        if value.kind != TomlKind.String or not isColour(value.stringVal):
          raise newException(ValueError, "invalid colour palettes." & name & "." & colour)
  let active = user.lookup("palette")
  if active.isNil: return
  if active.kind != TomlKind.String: raise newException(ValueError, "wrong type for palette")
  if active.stringVal == "": return
  let colours = palettes.lookup(active.stringVal)
  if colours.isNil: raise newException(ValueError, "unknown palette " & active.stringVal)
  for colour, value in colours.tableVal: result[colour] = value.stringVal

proc validate(user, defaults: TomlValueRef, palette: Palette) =
  for key, v in user.tableVal:
    let d = defaults.lookup(key)
    if d.isNil: raise newException(ValueError, "unknown key " & key)
    if not v.sameKind(d): raise newException(ValueError, "wrong type for " & key)
    if key == "palettes": continue
    if v.isTable:
      for sub, sv in v.tableVal:
        let sd = d.lookup(sub)
        let path = key & "." & sub
        if sd.isNil: raise newException(ValueError, "unknown key " & path)
        if not sv.sameKind(sd): raise newException(ValueError, "wrong type for " & path)
        if sv.kind == TomlKind.Array:
          for e in sv.arrayVal:
            if e.kind != TomlKind.String: raise newException(ValueError, "wrong type in " & path)
        checkValue(path, sv, palette)
    else:
      checkValue(key, v, palette)
  # Top-level variables are segment names, which are the preset's tables.
  let top = user.lookup("format")
  if not top.isNil:
    for name in parseFormat(top.stringVal).variables:
      let d = defaults.lookup(name)
      if d.isNil or not d.isTable or name == "palettes":
        raise newException(ValueError, "unknown segment $" & name)

proc defaultConfig*(): Config =
  let d = Toml.decode(plainToml, TomlValueRef)
  Config(user: TomlValueRef(kind: TomlKind.Table, tableVal: new TomlTable), defaults: d)

proc parseConfig*(text: string): Config =
  ## Raises on a TOML error, an unknown key, a wrongly typed value or a bad format or style.
  result = defaultConfig()
  let user = Toml.decode(text, TomlValueRef)
  result.palette = readPalette(user)
  validate(user, result.defaults, result.palette)
  result.user = user

proc configPath*(): string =
  result = getEnv("SHIORI_CONFIG")
  if result != "": return
  let xdg = getEnv("XDG_CONFIG_HOME")
  result = (if xdg != "": xdg else: getHomeDir() / ".config") / "shiori.toml"

proc loadConfig*(): Config =
  ## Missing file: defaults, silently. Any other error: one stderr line, then defaults.
  let path = configPath()
  if not fileExists(path): return defaultConfig()
  try:
    parseConfig(readFile(path))
  except CatchableError as e:
    stderr.writeLine "shiori: " & path & ": " & e.msg & "; using defaults"
    defaultConfig()
