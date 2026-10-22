## Subcommands share the same render path and always leave Claude Code a non-empty line.

import std/[monotimes, options, os, strutils, times]
import input, config, render, style

const
  NimblePkgVersion {.strdefine.} = "dev"
  fixtureTime* = 1792497600'i64
  fixtures* = ["full", "minimal", "invalid", "pre-first-reply", "free-plan",
    "post-compact", "detached-head", "narrow"]
  fixtureData = block:
    var data: array[fixtures.len, string]
    for i, name in fixtures:
      data[i] = staticRead("../../tests/fixtures/" & name & ".json")
    data
  usage = """shiori — a status line for Claude Code
Usage:
  shiori                                        render JSON from stdin
  shiori timings                                render, with timings on stderr
  shiori preview [--fixture NAME] [--config PATH] render an embedded fixture
  shiori --version
  shiori --help
Config: $SHIORI_CONFIG, else $XDG_CONFIG_HOME/shiori.toml or ~/.config/shiori.toml."""

proc fixture*(name: string): string =
  let i = fixtures.find(name)
  if i < 0: raise newException(ValueError, "unknown fixture " & name)
  fixtureData[i]

proc main*(args = commandLineParams()) =
  var inp: Input
  var line = ""
  try:
    let command = if args.len == 0: "" else: args[0]
    var selected = "full"
    var path = configPath()
    case command
    of "--version":
      echo "shiori ", NimblePkgVersion
      return
    of "--help", "-h":
      echo usage
      return
    of "preview":
      var i = 1
      while i < args.len:
        if args[i] notin ["--fixture", "--config"] or i + 1 == args.len:
          raise newException(ValueError, "expected --fixture NAME or --config PATH")
        if args[i] == "--fixture": selected = args[i + 1]
        else: path = args[i + 1]
        i += 2
    of "timings":
      if args.len != 1: raise newException(ValueError, "timings takes no arguments")
    of "": discard
    else: raise newException(ValueError, "unknown argument " & command)

    let timed = command == "timings"
    var start = if timed: getMonoTime() else: default(MonoTime)
    inp = parseInput(if command == "preview": fixture(selected) else: stdin.readAll)
    if timed:
      stderr.writeLine "input: " & $(getMonoTime() - start).inMicroseconds & " us"
      stderr.writeLine "version: " & inp.version.get("unknown")
      start = getMonoTime()
    let c = loadConfig(path)
    if timed:
      stderr.writeLine "config: " & $(getMonoTime() - start).inMicroseconds & " us"
      start = getMonoTime()
    line = render(inp, c, if command == "preview": fixtureTime else: getTime().toUnix, timings = timed)
    if timed: stderr.writeLine "render: " & $(getMonoTime() - start).inMicroseconds & " us"
  except CatchableError, Defect:
    stderr.writeLine "shiori: " & getCurrentExceptionMsg().splitLines.join(" ")
  # Claude Code shows a blank line on empty output: never print one.
  if line == "":
    line = inp.modelName.get(inp.modelId.get("")).splitLines.join(" ").strip.clip(columns())
    if line.isBlank: line = "shiori".clip(columns())
  stdout.write line & "\n"
