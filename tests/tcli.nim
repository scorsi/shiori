import std/[os, sequtils, strutils, tempfiles, unittest]
import ../src/shiori/cli
import helpers

proc invoke(args: seq[string], json = "", toml = "", width = "80"): tuple[output, diagnostics: string] =
  let dir = createTempDir("shiori-cli-", "", here)
  let (oldIn, oldOut, oldErr) = (stdin, stdout, stderr)
  var environment: seq[tuple[key, value: string, present: bool]]
  for (key, value) in [("SHIORI_CONFIG", dir / "config.toml"), ("COLUMNS", width), ("HOME", dir)]:
    environment.add (key, getEnv(key), existsEnv(key))
    putEnv(key, value)
  writeFile(dir / "input", json)
  writeFile(dir / "config.toml", toml)
  stdin = open(dir / "input")
  stdout = open(dir / "output", fmWrite)
  stderr = open(dir / "diagnostics", fmWrite)
  defer:
    close(stdin)
    close(stdout)
    close(stderr)
    (stdin, stdout, stderr) = (oldIn, oldOut, oldErr)
    for entry in environment:
      if entry.present: putEnv(entry.key, entry.value)
      else: delEnv(entry.key)
    removeDir(dir)
  main(args)
  stdout.flushFile
  stderr.flushFile
  (readFile(dir / "output"), readFile(dir / "diagnostics"))

suite "cli":
  test "embedded fixtures are the test fixtures":
    for name in fixtures:
      check fixture(name) == readFile(here / "fixtures" / name & ".json")
    expect ValueError: discard fixture("unknown")

  test "preview defaults to full, accepts a fixture and does not read stdin":
    let full = invoke(@["preview"], "invalid")
    check "Opus 5.5" in full.output
    check "2h13m" in full.output
    check full.diagnostics == ""
    for name in fixtures:
      let got = invoke(@["preview", "--fixture", name])
      check got.output.strip != ""
      check got.diagnostics == ""
    check invoke(@["preview", "--fixture", "minimal"]).output == "shiori\n"

  test "preview config flag overrides environment config":
    let dir = createTempDir("shiori-config-", "", here)
    defer: removeDir(dir)
    writeFile(dir / "test.toml", "format = 'custom'")
    check invoke(@["preview", "--config", dir / "test.toml"], toml = "format = 'other'").output == "custom\n"

  test "timings lists only evaluated segments, once each":
    let got = invoke(@["timings"], fixture("full"),
      "format = '$model$model$directory'\n[directory]\ndisabled = true")
    let entries = got.diagnostics.splitLines.filterIt(it.startsWith("segment."))
    check entries.len == 1
    check entries[0].startsWith("segment.model: ")
    check "input: " in got.diagnostics
    check "config: " in got.diagnostics
    check "render: " in got.diagnostics
    check "version: 2.1.296" in got.diagnostics
    check "segment." notin got.output
    check got.output == invoke(@[], fixture("full"),
      "format = '$model$model$directory'\n[directory]\ndisabled = true").output

  test "empty, invalid and failed renders always have a fallback":
    for json in ["", "garbage", "{}", "[]", "null", "{\"model\":{\"display_name\":\"\"}}"]:
      check invoke(@[], json).output == "shiori\n"
    check invoke(@[], "{\"model\":{\"id\":\"m\"}}", "format = ''").output == "m\n"
    check invoke(@[], "{}", "format = '[ ](dim)'").output == "shiori\n"
    check invoke(@[], "{}", width = "1").output == "s\n"
    let bad = invoke(@[], fixture("full"), "format = [")
    check "Opus 5.5" in bad.output
    check bad.diagnostics.splitLines.filterIt(it != "").len == 1

  test "bad arguments are diagnostics, with exit-zero fallback output":
    for args in [@["unknown"], @["preview", "--fixture"], @["preview", "--fixture", "missing"],
        @["preview", "--bad", "x"], @["timings", "--config", "x"]]:
      let got = invoke(args)
      check got.output == "shiori\n"
      check got.diagnostics.startsWith("shiori: ")
    check "Usage:" in invoke(@["--help"]).output
    check invoke(@["--version"]).output.startsWith("shiori ")
