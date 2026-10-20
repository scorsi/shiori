## One proc per segment (ADR 0005): input and config to variables, or nothing to show.

import std/[options, math, strutils, tables]
import input, config

type Vars* = Table[string, string]

const known* = ["model", "effort", "context", "rate_limits"]

proc percent(p: float): int = round(p).int

proc gaugeStyle(c: Config, segment: string, p: int): string =
  if p >= c.integer(segment, "threshold_critical"): c.str(segment, "style_critical")
  elif p >= c.integer(segment, "threshold_warn"): c.str(segment, "style_warn")
  else: c.str(segment, "style")

proc bar(p, width: int, fill, empty: string): string =
  let filled = clamp(p, 0, 100) * max(width, 0) div 100
  fill.repeat(filled) & empty.repeat(max(width, 0) - filled)

proc humanTokens*(n: int64): string =
  if n >= 1_000_000:
    let tenths = (n mod 1_000_000) div 100_000
    $(n div 1_000_000) & (if tenths == 0: "" else: "." & $tenths) & "M"
  elif n >= 1000: $(n div 1000) & "k"
  else: $n

proc timeUntil*(target, now: int64): string =
  let diff = max(target - now, 0)
  let (d, h, m) = (diff div 86400, diff mod 86400 div 3600, diff mod 3600 div 60)
  if d > 0: $d & "d" & $h & "h"
  elif h > 0: $h & "h" & intToStr(m.int, 2) & "m"
  else: $m & "m"

proc model(inp: Input): Vars =
  let name = if inp.modelName.isSome: inp.modelName else: inp.modelId
  if name.isSome: result["name"] = name.get

proc effort(inp: Input, c: Config): Vars =
  if inp.effort.isSome and inp.effort.get notin c.strings("effort", "hide_levels"):
    result["level"] = inp.effort.get

proc context(inp: Input, c: Config): Vars =
  if inp.contextPercentage.isNone: return
  let p = percent(inp.contextPercentage.get)
  result["percentage"] = $p
  result["bar"] = bar(p, c.integer("context", "bar_width"), c.str("context", "bar_fill"),
    c.str("context", "bar_empty"))
  if inp.contextTokens.isSome and inp.contextSize.isSome:
    result["tokens"] = humanTokens(inp.contextTokens.get) & "/" & humanTokens(inp.contextSize.get)
  result["style"] = gaugeStyle(c, "context", p)

proc rateLimits(inp: Input, c: Config, now: int64): Vars =
  var worst = -1
  for (key, limit) in [("five_hour", inp.fiveHour), ("seven_day", inp.sevenDay)]:
    if limit.usedPercentage.isNone: continue
    let p = percent(limit.usedPercentage.get)
    worst = max(worst, p)
    result[key] = $p
    if limit.resetsAt.isSome: result[key & "_reset"] = timeUntil(limit.resetsAt.get, now)
  # One style for both windows, from the more used one.
  if worst >= 0: result["style"] = gaugeStyle(c, "rate_limits", worst)

proc evaluate*(name: string, inp: Input, c: Config, now: int64): Vars =
  ## Empty when the segment is disabled or has nothing to show.
  if c.boolean(name, "disabled"): return
  result =
    case name
    of "model": model(inp)
    of "effort": effort(inp, c)
    of "context": context(inp, c)
    of "rate_limits": rateLimits(inp, c, now)
    else: raise newException(KeyError, "unknown segment " & name)
  if result.len == 0: return
  if "style" notin result: result["style"] = c.str(name, "style")
  result["symbol"] = c.str(name, "symbol")
