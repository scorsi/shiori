## The JSON document Claude Code pipes on stdin (ADR 0003): every field optional, never raises.

import std/[json, options]

type
  RateLimit* = object
    usedPercentage*: Option[float]
    resetsAt*: Option[int64]

  Input* = object
    modelName*, modelId*, effort*: Option[string]
    contextPercentage*: Option[float]
    contextTokens*, contextSize*: Option[int64]
    fiveHour*, sevenDay*: RateLimit
    costUsd*: Option[float]
    durationMs*, linesAdded*, linesRemoved*: Option[int64]
    currentDir*, cwd*, projectDir*: Option[string]
    sessionName*, vimMode*, version*: Option[string]

proc str(root: JsonNode, path: varargs[string]): Option[string] =
  let n = root{path}
  if n != nil and n.kind == JString: some(n.str) else: none(string)

proc num(root: JsonNode, path: varargs[string]): Option[float] =
  let n = root{path}
  if n == nil: none(float)
  elif n.kind == JFloat: some(n.fnum)
  elif n.kind == JInt: some(n.num.float)
  else: none(float)

proc integer(root: JsonNode, path: varargs[string]): Option[int64] =
  let n = root{path}
  if n != nil and n.kind == JInt: some(n.num) else: none(int64)

proc limit(root: JsonNode, window: string): RateLimit =
  RateLimit(
    usedPercentage: root.num("rate_limits", window, "used_percentage"),
    resetsAt: root.integer("rate_limits", window, "resets_at"),
  )

proc parseInput*(text: string): Input =
  var root: JsonNode
  try:
    root = parseJson(text)
  except CatchableError:
    return
  # `{}` on a non-object returns nil at the first step, so any JSON value is safe here.
  Input(
    modelName: root.str("model", "display_name"),
    modelId: root.str("model", "id"),
    effort: root.str("effort", "level"),
    contextPercentage: root.num("context_window", "used_percentage"),
    contextTokens: root.integer("context_window", "total_input_tokens"),
    contextSize: root.integer("context_window", "context_window_size"),
    fiveHour: root.limit("five_hour"),
    sevenDay: root.limit("seven_day"),
    costUsd: root.num("cost", "total_cost_usd"),
    durationMs: root.integer("cost", "total_duration_ms"),
    linesAdded: root.integer("cost", "total_lines_added"),
    linesRemoved: root.integer("cost", "total_lines_removed"),
    currentDir: root.str("workspace", "current_dir"),
    cwd: root.str("cwd"),
    projectDir: root.str("workspace", "project_dir"),
    sessionName: root.str("session_name"),
    vimMode: root.str("vim", "mode"),
    version: root.str("version"),
  )
