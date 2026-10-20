## Entry point: what Claude Code's `statusLine.command` runs (ADR 0002).

import std/[options, os, times]
import shiori/[input, config, render]

const NimblePkgVersion {.strdefine.} = "dev"

const usage = """shiori — a status line for Claude Code

Usage:
  shiori            read Claude Code's JSON on stdin, print the status line
  shiori --version
  shiori --help

Config: $SHIORI_CONFIG, else $XDG_CONFIG_HOME/shiori.toml or ~/.config/shiori.toml."""

proc main() =
  let args = commandLineParams()
  if args.len > 0:
    case args[0]
    of "--version": echo "shiori ", NimblePkgVersion
    of "--help", "-h": echo usage
    else:
      stderr.writeLine "shiori: unknown argument " & args[0]
      echo usage
    return

  var inp: Input
  var line = ""
  try:
    inp = parseInput(stdin.readAll)
    line = render(inp, loadConfig(), getTime().toUnix)
  except CatchableError, Defect:
    stderr.writeLine "shiori: " & getCurrentExceptionMsg()
  # Claude Code shows a blank line on empty output: never print one.
  if line == "":
    line = if inp.modelName.isSome: inp.modelName.get else: "shiori"
  stdout.write line & "\n"

when isMainModule:
  main()
