## Starship-style format strings (ADR 0004): `$name`, `${name}`, `[text](style)`, `\` escapes.

import std/strutils

type
  NodeKind* = enum
    nkText, nkVar, nkGroup

  Node* = object
    case kind*: NodeKind
    of nkText: text*: string
    of nkVar: name*: string
    of nkGroup:
      children*: seq[Node]
      style*: string

  Format* = seq[Node]

const nameChars = {'a' .. 'z', 'A' .. 'Z', '0' .. '9', '_'}

proc parseFormat*(s: string): Format =
  ## Raises ValueError on an unclosed group, a group without `(style)` or a stray `]`.
  var i = 0

  proc addText(nodes: var seq[Node], t: string) =
    if nodes.len > 0 and nodes[^1].kind == nkText: nodes[^1].text.add t
    else: nodes.add Node(kind: nkText, text: t)

  proc parseSeq(inGroup: bool): seq[Node] =
    while i < s.len:
      let c = s[i]
      case c
      of '\\':
        if i + 1 < s.len and s[i + 1] in {'$', '[', ']', '\\'}:
          result.addText $s[i + 1]
          i += 2
        else:
          result.addText "\\"
          inc i
      of '$':
        if i + 1 < s.len and s[i + 1] == '{':
          let close = s.find('}', i + 2)
          let name = if close < 0: "" else: s[i + 2 ..< close]
          if name.len == 0 or not name.allCharsInSet(nameChars):
            raise newException(ValueError, "bad variable at offset " & $i)
          result.add Node(kind: nkVar, name: name)
          i = close + 1
        else:
          var j = i + 1
          while j < s.len and s[j] in nameChars: inc j
          if j == i + 1: result.addText "$"
          else: result.add Node(kind: nkVar, name: s[i + 1 ..< j])
          i = j
      of '[':
        let start = i
        inc i
        let children = parseSeq(true)
        if i >= s.len: raise newException(ValueError, "unclosed [ at offset " & $start)
        inc i # the `]`
        if i >= s.len or s[i] != '(':
          raise newException(ValueError, "group at offset " & $start & " needs a (style)")
        let close = s.find(')', i + 1)
        if close < 0: raise newException(ValueError, "unclosed ( at offset " & $i)
        result.add Node(kind: nkGroup, children: children, style: s[i + 1 ..< close])
        i = close + 1
      of ']':
        if inGroup: return
        raise newException(ValueError, "stray ] at offset " & $i)
      else:
        result.addText $c
        inc i

  parseSeq(false)

proc variables*(f: Format): seq[string] =
  ## Every variable named in `f`, nested groups included.
  for n in f:
    case n.kind
    of nkText: discard
    of nkVar: result.add n.name
    of nkGroup: result.add n.children.variables
