import std/[unittest]
import ../src/shiori/[format]

suite "format":
  test "variables, braces and text":
    let f = parseFormat("a $x ${y}z $")
    check f.len == 5
    check f[0].text == "a "
    check f[1].name == "x"
    check f[3].name == "y"
    check f[4].text == "z $"
    check f.variables == @["x", "y"]

  test "nested groups":
    let f = parseFormat("[a [$b](dim)](bold red)")
    check f.len == 1
    check f[0].style == "bold red"
    check f[0].children[1].children[0].name == "b"
    check f.variables == @["b"]

  test "escapes":
    let f = parseFormat("\\$x \\[y\\] \\\\ \\n")
    check f.len == 1
    check f[0].text == "$x [y] \\ \\n"

  test "newlines are text":
    check parseFormat("$a\n$b").len == 3

  test "errors":
    for bad in ["[x", "[x]", "[x](dim", "x]", "${}", "${a"]:
      expect ValueError:
        discard parseFormat(bad)
