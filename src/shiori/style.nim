## Style words (ADR 0005) to SGR escape sequences.

import std/[strutils, parseutils]

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

proc sgr*(style: string): string =
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
        let c = colourCodes(if bg: word[3 .. ^1] else: word, bg)
        if c == "": raise newException(ValueError, "unknown style word: " & word)
        c
    if code != "": codes.add code
  if codes.len == 0: "" else: "\e[" & codes.join(";") & "m"
