## Walks the format AST, evaluates only the segments it references, assembles the line.

import std/[strutils, tables]
import format, style, input, config, segments

type Lookup = proc(name: string): string

# `$symbol` and `$style` are always set, so they do not keep a group alive.
const meta = ["symbol", "style"]

proc expand(nodes: seq[Node], lookup: Lookup, styles: var seq[string],
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
      let code = sgr(if n.style.startsWith("$"): lookup(n.style[1 .. ^1]) else: n.style)
      styles.add code
      var (u, f) = (0, 0)
      let inner = expand(n.children, lookup, styles, u, f)
      discard styles.pop
      used += u
      filled += f
      if u > 0 and f == 0: continue
      if code == "": result.add inner
      else: result.add code & inner & reset & styles.join

proc renderFormat(f: Format, lookup: Lookup): string =
  var styles: seq[string]
  var (u, f2) = (0, 0)
  expand(f, lookup, styles, u, f2)

proc render*(inp: Input, c: Config, now: int64): string =
  ## The status line, possibly several lines; "" when nothing has anything to show.
  var cache: Table[string, string]
  let top = parseFormat(c.topFormat)
  let line = renderFormat(top) do (name: string) -> string:
    if name notin cache:
      let vars = evaluate(name, inp, c, now)
      cache[name] =
        if vars.len == 0: ""
        else:
          renderFormat(parseFormat(c.str(name, "format"))) do (v: string) -> string:
            vars.getOrDefault(v)
    cache[name]
  for part in line.splitLines:
    if part.strip == "": continue
    if result != "": result.add "\n"
    result.add part
