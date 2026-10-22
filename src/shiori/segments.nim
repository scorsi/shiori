## One proc per segment (ADR 0005): input and config to variables, or nothing to show.

import std/[options, math, os, sequtils, strutils, tables]
from std/unicode import runeSubStr
import input, config

type Vars* = Table[string, string]

const known* = ["model", "effort", "context", "rate_limits", "cost", "directory",
  "git_branch", "session_name", "vim_mode"]

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

proc cost(inp: Input, c: Config): Vars =
  if inp.costUsd.isSome:
    result["usd"] = "$" & formatFloat(inp.costUsd.get, ffDecimal, c.integer("cost", "precision"))
  if inp.durationMs.isSome: result["duration"] = timeUntil(inp.durationMs.get div 1000, 0)
  if inp.linesAdded.isSome: result["added"] = $inp.linesAdded.get
  if inp.linesRemoved.isSome: result["removed"] = $inp.linesRemoved.get

proc directoryPath(inp: Input): string =
  if inp.currentDir.isSome and inp.currentDir.get != "": inp.currentDir.get
  else: inp.cwd.get("")

proc directory(inp: Input, c: Config): Vars =
  var path = inp.directoryPath
  if path == "": return
  path = normalizedPath(path)
  let home = getHomeDir().normalizedPath
  if home != "/" and (path == home or path.startsWith(home & "/")):
    path = c.str("directory", "home_symbol") & path[home.len .. ^1]
  let parts = path.split('/').filterIt(it != "")
  let length = c.integer("directory", "truncation_length")
  if length > 0 and parts.len > length:
    path = c.str("directory", "truncation_symbol") & parts[^length .. ^1].join("/")
  result["path"] = path

proc gitBranch(inp: Input, c: Config): Vars =
  var dir = inp.directoryPath
  if dir == "": return
  dir = absolutePath(dir).normalizedPath
  while true:
    let dotgit = dir / ".git"
    if dirExists(dotgit) or fileExists(dotgit):
      try:
        var gitdir = dotgit
        if fileExists(dotgit):
          let link = readFile(dotgit).strip
          if not link.startsWith("gitdir: "): return
          gitdir = absolutePath(link[8 .. ^1], dir)
        let head = readFile(gitdir / "HEAD").strip
        var branch: string
        if head.startsWith("ref: refs/heads/"): branch = head[16 .. ^1]
        elif head.len in [40, 64] and head.allCharsInSet(HexDigits): branch = head[0 .. 6]
        else: return
        let length = c.integer("git_branch", "truncation_length")
        if length > 0: branch = branch.runeSubStr(0, length)
        result["branch"] = branch
      except CatchableError:
        discard
      return
    let parent = dir.parentDir
    if parent == dir or parent == "": return
    dir = parent

proc sessionName(inp: Input): Vars =
  if inp.sessionName.isSome: result["name"] = inp.sessionName.get

proc vimMode(inp: Input, c: Config): Vars =
  if inp.vimMode.isNone: return
  result["mode"] = inp.vimMode.get.toUpperAscii
  case result["mode"]
  of "NORMAL": result["style"] = c.str("vim_mode", "normal_style")
  of "INSERT": result["style"] = c.str("vim_mode", "insert_style")
  else: discard

proc evaluate*(name: string, inp: Input, c: Config, now: int64): Vars =
  ## Empty when the segment is disabled or has nothing to show.
  if c.boolean(name, "disabled"): return
  result =
    case name
    of "model": model(inp)
    of "effort": effort(inp, c)
    of "context": context(inp, c)
    of "rate_limits": rateLimits(inp, c, now)
    of "cost": cost(inp, c)
    of "directory": directory(inp, c)
    of "git_branch": gitBranch(inp, c)
    of "session_name": sessionName(inp)
    of "vim_mode": vimMode(inp, c)
    else: raise newException(KeyError, "unknown segment " & name)
  if result.len == 0: return
  if "style" notin result: result["style"] = c.str(name, "style")
  result["symbol"] = c.str(name, "symbol")
