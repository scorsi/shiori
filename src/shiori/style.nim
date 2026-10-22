## Style words (ADR 0005) to SGR escape sequences.

import std/[strutils, parseutils, tables]
from std/unicode import runeAt, runeLenAt

type Palette* = Table[string, string]

const
  reset* = "\e[0m"
  colours = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]

proc colourCodes(word: string, background: bool): string =
  ## "" when `word` is not a colour.
  let base = if background: 40 else: 30
  let i = colours.find(word)
  if i >= 0: return $(base + i)
  if word.startsWith("bright-"):
    let j = colours.find(word[7 .. ^1])
    if j >= 0: return $(base + 60 + j)
  let extended = if background: "48" else: "38"
  var n: int
  if word.len > 0 and word.allCharsInSet(Digits) and parseInt(word, n) == word.len and n <= 255:
    return extended & ";5;" & $n
  if word.len == 7 and word[0] == '#' and word[1 .. ^1].allCharsInSet(HexDigits):
    return extended & ";2;" & $fromHex[int](word[1 .. 2]) & ";" & $fromHex[int](word[3 .. 4]) &
      ";" & $fromHex[int](word[5 .. 6])
  ""

proc isColour*(word: string): bool = colourCodes(word, false) != ""

proc sgr*(style: string, palette = default(Palette)): string =
  ## The escape sequence for `style`, "" for an empty style. Raises ValueError on an unknown word.
  var codes: seq[string]
  for word in style.splitWhitespace:
    let code =
      case word
      of "none": ""
      of "bold": "1"
      of "dim": "2"
      of "italic": "3"
      of "underline": "4"
      of "inverted": "7"
      else:
        let bg = word.startsWith("bg:")
        let colour = if bg: word[3 .. ^1] else: word
        let c = colourCodes(palette.getOrDefault(colour, colour), bg)
        if c == "": raise newException(ValueError, "unknown style word: " & word)
        c
    if code != "": codes.add code
  if codes.len == 0: "" else: "\e[" & codes.join(";") & "m"

proc runeWidth(r: int): int =
  for (first, last) in [(0x0300, 0x036f), (0x1ab0, 0x1aff), (0x1dc0, 0x1dff),
      (0x200b, 0x200f), (0x20d0, 0x20ff), (0xfe00, 0xfe0f), (0xfe20, 0xfe2f),
      (0x1f3fb, 0x1f3ff), (0xe0020, 0xe007f), (0xe0100, 0xe01ef)]:
    if r in first .. last: return 0
  if r < 32 or r in 0x7f .. 0x9f: return 0
  for (first, last) in [(0x1100, 0x115f), (0x231a, 0x231b), (0x2329, 0x232a),
      (0x23e9, 0x23ec), (0x23f0, 0x23f0), (0x23f3, 0x23f3), (0x25fd, 0x25fe),
      (0x2614, 0x2615), (0x2648, 0x2653), (0x267f, 0x267f), (0x2693, 0x2693),
      (0x26a1, 0x26a1), (0x26aa, 0x26ab), (0x26bd, 0x26be), (0x26c4, 0x26c5),
      (0x26ce, 0x26ce), (0x26d4, 0x26d4), (0x26ea, 0x26ea), (0x26f2, 0x26f3),
      (0x26f5, 0x26f5), (0x26fa, 0x26fa), (0x26fd, 0x26fd), (0x2705, 0x2705),
      (0x270a, 0x270b), (0x2728, 0x2728), (0x274c, 0x274c), (0x274e, 0x274e),
      (0x2753, 0x2755), (0x2757, 0x2757), (0x2795, 0x2797), (0x27b0, 0x27b0),
      (0x27bf, 0x27bf), (0x2e80, 0x303e), (0x3040, 0xa4cf),
      (0xac00, 0xd7a3), (0xf900, 0xfaff), (0xfe10, 0xfe19), (0xfe30, 0xfe6f),
      (0xff01, 0xff60), (0xffe0, 0xffe6), (0x1f000, 0x1faff), (0x20000, 0x3fffd)]:
    if r in first .. last: return 2
  1

iterator cells(s: string): tuple[text: string, width: int] =
  var i = 0
  while i < s.len:
    let start = i
    if s[i] == '\e':
      inc i
      if i < s.len and s[i] == '[':
        inc i
        while i < s.len and s[i] notin {'@' .. '~'}: inc i
        if i < s.len: inc i
      elif i < s.len and s[i] == ']':
        inc i
        while i < s.len and s[i] != '\a' and not s.continuesWith("\e\\", i): inc i
        if i < s.len: i += (if s[i] == '\a': 1 else: 2)
      elif i < s.len: inc i
      yield (s[start ..< i], 0)
    else:
      let first = s.runeAt(i).int
      var width = runeWidth(first)
      i += s.runeLenAt(i)
      var joined = false
      var regional = first in 0x1f1e6 .. 0x1f1ff
      # Keep combining marks, emoji joins and flag pairs together when clipping.
      while i < s.len and s[i] != '\e':
        let r = s.runeAt(i).int
        if r == 0x200d: joined = true
        elif runeWidth(r) == 0:
          if r == 0xfe0f: width = max(width, 2)
        elif joined:
          width = max(width, runeWidth(r))
          joined = false
        elif regional and r in 0x1f1e6 .. 0x1f1ff: regional = false
        else: break
        i += s.runeLenAt(i)
      yield (s[start ..< i], width)

proc displayWidth*(s: string): int =
  for cell in s.cells: result += cell.width

proc clip*(s: string, width: int): string =
  var used = 0
  for cell in s.cells:
    if used + cell.width > width:
      if '\e' in result: result.add reset
      break
    result.add cell.text
    used += cell.width

proc padding*(symbol: string, width: int): string =
  let size = symbol.displayWidth
  if size <= 0: return " ".repeat(max(width, 0))
  symbol.repeat(max(width, 0) div size) & " ".repeat(max(width, 0) mod size)
