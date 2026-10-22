## Walks the format AST, evaluates only the segments it references, assembles the line.

import std/[monotimes, os, strutils, tables, times]
import format, style, input, config, segments

type Lookup = proc(name: string): string

# Decoration does not keep an otherwise empty group alive.
const meta = ["symbol", "style", "fill"]

proc expand(nodes: seq[Node], lookup: Lookup, palette: Palette, styles: var seq[string],
    used, filled: var int): string =
  for n in nodes:
    case n.kind
    of nkText: result.add n.text
    of nkVar:
      let v = lookup(n.name)
      if n.name notin meta:
        inc used
        if v != "": inc filled
      result.add v
      # A segment's own escapes end with a reset: restore the enclosing groups' styles.
      if '\e' in v and styles.len > 0: result.add styles.join
    of nkGroup:
      let code = sgr((if n.style.startsWith("$"): lookup(n.style[1 .. ^1]) else: n.style), palette)
      styles.add code
      var (u, f) = (0, 0)
      let inner = expand(n.children, lookup, palette, styles, u, f)
      discard styles.pop
      used += u
      filled += f
      if u > 0 and f == 0: continue
      if code == "": result.add inner
      else: result.add code & inner & reset & styles.join

proc renderFormat(f: Format, palette: Palette, lookup: Lookup): string =
  var styles: seq[string]
  var (u, f2) = (0, 0)
  expand(f, lookup, palette, styles, u, f2)

proc columns*(): int =
  try:
    result = parseInt(getEnv("COLUMNS", "80"))
  except ValueError:
    discard
  if result <= 0: result = 80

proc render*(inp: Input, c: Config, now: int64, width = columns(), timings = false): string =
  ## The status line, possibly several lines; "" when nothing has anything to show.
  var cache: Table[string, string]
  let top = parseFormat(c.topFormat)
  let line = renderFormat(top, c.palette) do (name: string) -> string:
    if name in ["style", "symbol"]: return ""
    if name notin cache:
      if c.boolean(name, "disabled"):
        cache[name] = ""
        return ""
      let start = if timings: getMonoTime() else: default(MonoTime)
      if name == "fill":
        let code = sgr(c.str("fill", "style"), c.palette)
        cache[name] = code & "\0" & (if code == "": "" else: reset)
      else:
        let vars = evaluate(name, inp, c, now)
        cache[name] =
          if vars.len == 0: ""
          else:
            renderFormat(parseFormat(c.str(name, "format")), c.palette) do (v: string) -> string:
              vars.getOrDefault(v)
      if timings: stderr.writeLine "segment." & name & ": " & $(getMonoTime() - start).inMicroseconds & " us"
    cache[name]
  for part in line.splitLines:
    var text = part.replace("\0", "")
    if text.isBlank: continue
    let fill = part.find('\0')
    if fill >= 0:
      let pad = padding(c.str("fill", "symbol"), width - text.displayWidth)
      text = part[0 ..< fill] & pad &
        part[fill + 1 .. ^1].replace("\0", "")
    text = text.clip(width)
    if text.isBlank: continue
    if result != "": result.add "\n"
    result.add text
