import std/[os, unittest]
import helpers

suite "render":
  test "an empty group disappears with its text":
    check renderWith("format = \"$model[ <$effort>]()\"", """{"model": {"id": "m"}}""") ==
      "\e[1;36mm\e[0m"

  test "a group with no variables stays":
    check renderWith("format = \"[x](dim)\"", "{}") == "\e[2mx\e[0m"

  test "multiline format, no trailing newline":
    check renderWith("format = \"\"\"\n$model\n$effort\n\"\"\"\n[model]\nstyle = \"\"\n[effort]\nstyle = \"\"",
      fixture("full")) == "Opus 5.5\nmedium"

  test "snapshots, plain preset":
    let plain = readFile(here.parentDir / "presets" / "plain.toml")
    for name in fixtures:
      checkpoint name
      let path = here / "snapshots" / name & ".plain.txt"
      let got = renderWith(plain, fixture(name)) & "\n"
      if existsEnv("SHIORI_UPDATE_SNAPSHOTS"): writeFile(path, got)
      else: check got == readFile(path)
