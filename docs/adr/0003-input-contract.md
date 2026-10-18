---
status: accepted
date: 2026-10-14
decision-makers: scorsi
---

# Input contract with Claude Code

## Context and Problem Statement

Claude Code pipes one JSON document to the status line command and sets `COLUMNS` and `LINES`. The document grew field by field across 2.1.x releases, many fields are optional or `null` depending on plan, moment and version (`context_window.current_usage` is `null` before the first API reply and after `/compact`; `rate_limits` exists on Pro/Max only; `prompt_cache` since 2.1.251). Nothing is versioned in the document itself except the `version` string.

How does shiori read this document so that any version, any plan and any moment produce a sensible line?

## Decision Drivers

- Never fail, never print an empty line (ADR 0002).
- Older or newer Claude Code than the reference 2.1.296 must degrade, not break.
- Segments should not each re-implement null handling.
- No dependency on undocumented data (transcript JSONL format, `~/.claude/sessions`).

## Considered Options

1. **Typed, all-optional record**: one `Input` type where every field is an `Option`; a single parser maps JSON to it with `{}` lookups; wrong type counts as absent.
2. Strict schema with validation: reject documents missing required fields.
3. Pass the raw `JsonNode` to segments and let each dig.

## Decision Outcome

**Option 1.** `input` parses stdin once into `Input`. Rules:

- Absent, `null` or wrongly typed field → `none`. Unknown fields ignored. Invalid JSON → an `Input` with every field `none`.
- Segments receive `Input` and decide what to show; a segment whose inputs are all `none` renders nothing (ADR 0005).
- Width comes from `COLUMNS`, falling back to 80 when unset or unparsable.
- Only the stdin document and the filesystem under `cwd` are read. `transcript_path` and `session_id` are parsed as strings, not followed.

Fields read in version 1 (all optional):

| Field | Used by |
|-------|---------|
| `model.display_name`, `model.id` | `model` |
| `effort.level` | `effort` |
| `context_window.used_percentage`, `total_input_tokens`, `context_window_size` | `context` |
| `rate_limits.{five_hour,seven_day}.{used_percentage,resets_at}` | `rate_limits` |
| `cost.total_cost_usd`, `total_duration_ms`, `total_lines_added`, `total_lines_removed` | `cost` |
| `workspace.current_dir`, `cwd`, `workspace.project_dir` | `directory`, `git_branch` |
| `session_name` | `session_name` |
| `vim.mode` | `vim_mode` |
| `version` | `timings` output only |

Documented fields not read in version 1 (`prompt_cache`, `pr`, `agent`, `worktree`, `fast_mode`, `thinking`, `output_style`, `exceeds_200k_tokens`, `workspace.repo`) are candidates for later segments and need no change to this contract.

Version policy: no minimum version is enforced. Fixtures (ADR 0008) are captured from the reference version named in ADR 0001; bumping the reference means capturing new fixtures and checking that every field in the table above is still present. A field removed upstream empties a segment and fails a snapshot test, which is the signal to adapt.

### Consequences

- Good: one place knows the JSON shape; segments are pure functions of `Input`.
- Good: a Free plan, a session before its first reply, or Claude Code 2.0 all produce a line.
- Bad: silently ignoring wrong types can hide upstream changes; the snapshot tests and `shiori timings` (which prints `version`) are the mitigation.
- Neutral: `used_percentage` is taken as given rather than recomputed from tokens; Claude Code already accounts for autocompact buffer.

### Confirmation

Fixtures `{}`, invalid JSON, pre-first-reply, no-rate-limits and full each render a non-empty line in tests (ADR 0008).

## Pros and Cons of the Options

1. **All-optional record**: one parser, trivially tolerant; cannot express "required" because nothing is.
2. **Strict schema**: catches upstream changes loudly; blank line for users whenever Claude Code changes, the opposite of the goal.
3. **Raw JsonNode**: least code; null handling duplicated in ten segments, types unchecked.

## More Information

- <https://code.claude.com/docs/en/statusline> (JSON reference, refresh triggers, `COLUMNS`/`LINES`).
- Related: ADR 0002, ADR 0005, ADR 0008.
