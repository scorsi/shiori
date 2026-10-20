import std/[unittest]
import ../src/shiori/[style]

suite "style":
  test "words":
    check sgr("") == ""
    check sgr("none") == ""
    check sgr("bold cyan") == "\e[1;36m"
    check sgr("bright-red bg:blue") == "\e[91;44m"
    check sgr("208 bg:#a6e3a1") == "\e[38;5;208;48;2;166;227;161m"

  test "unknown words":
    for bad in ["blinky", "256", "#12345", "bg:nope"]:
      expect ValueError:
        discard sgr(bad)
