import std/[os, strutils, unittest]
import ../src/shiori/[render, style]
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

  test "fill, extra fills, styles and multiline width":
    check renderWith("format = 'L$fill R$fill!'", "{}", 8) == "L     R!"
    check renderWith("format = '日$fill🐱'\n[fill]\nsymbol = '.'", "{}", 7) == "日...🐱"
    check renderWith("format = 'L$fill R'\n[fill]\ndisabled = true", "{}", 8) == "L R"
    check renderWith("format = 'L$fill R'\n[fill]\nsymbol = '日'", "{}", 8) == "L日日  R"
    check renderWith("format = 'L$fill R'\n[fill]\nstyle = 'dim'", "{}", 5) == "L\e[2m  \e[0m R"
    check renderWith("format = \"a$fill!\\nb$fill!\"", "{}", 4) == "a  !\nb  !"
    check renderWith("format = 'abcdef$fill!'", "{}", 4) == "abcd"
    check renderWith("format = '$fill'", "{}") == ""
    check renderWith("format = 'x[ $fill$model]()'", "{}") == "x"
    check renderWith("format = \"\\n$model\\n\\n\"", "{}") == ""

  test "COLUMNS defaults and invalid values":
    let old = getEnv("COLUMNS")
    let existed = existsEnv("COLUMNS")
    defer:
      if existed: putEnv("COLUMNS", old)
      else: delEnv("COLUMNS")
    delEnv("COLUMNS")
    check columns() == 80
    for value in ["", "x", "0", "-2", "999999999999999999999999"]:
      putEnv("COLUMNS", value)
      check columns() == 80
    putEnv("COLUMNS", "40")
    check columns() == 40

  test "narrow fixture stays within 40 cells":
    let got = snapshot(readFile(here.parentDir / "presets" / "plain.toml"), "narrow")
    for line in got.splitLines: check line.displayWidth <= 40

  test "snapshots, plain preset":
    let plain = readFile(here.parentDir / "presets" / "plain.toml")
    for name in fixtures:
      checkpoint name
      let path = here / "snapshots" / name & ".plain.txt"
      let got = snapshot(plain, name) & "\n"
      if existsEnv("SHIORI_UPDATE_SNAPSHOTS"): writeFile(path, got)
      else: check got == readFile(path)
