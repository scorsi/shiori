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

  test "display cells, ANSI, combining marks and emoji":
    for (text, width) in [("abc", 3), ("日本語", 6), ("e\u0301", 1), ("🐱", 2),
        ("👩‍💻", 2), ("🇫🇷", 2), ("👍🏽", 2), ("❤️", 2), ("✓", 1), ("\u0301", 0),
        ("\e[1;38;2;1;2;3m日本\e[0m", 4), ("\e]8;;https://example.org\aHi\e]8;;\e\\", 2)]:
      checkpoint text
      check text.displayWidth == width

  test "clipping keeps code points, joined emoji, accents and resets intact":
    check clip("a日本", 4) == "a日"
    check clip("e\u0301x", 1) == "e\u0301"
    check clip("👩‍💻!", 2) == "👩‍💻"
    check clip("🇫🇷x", 2) == "🇫🇷"
    check clip("\e[31mabc\e[0m", 2) == "\e[31mab\e[0m"
    check clip("a", 0) == ""

  test "padding uses cells and finishes an odd width with spaces":
    check padding("日", 5) == "日日 "
    check padding("", 3) == "   "
    check padding("\u0301", 3) == "   "
    check padding(".", -1) == ""
