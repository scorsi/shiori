---
status: accepted
date: 2026-10-14
decision-makers: scorsi
---

# Version 1 segments and style vocabulary

## Context and Problem Statement

The format string (ADR 0004) names segments; each segment turns part of `Input` (ADR 0003) into variables and a styled string. Which segments ship in version 1, what each exposes, when it disappears, and which style words the config accepts?

## Decision Drivers

- Cover what the sekkeizu seed shows (model, effort, context, rate limits) plus what the author misses (directory, git branch, cost, session name, vim mode).
- No subprocess, no network in the render path (ADR 0002): `git` is not executed.
- Starship users should recognise the style words.
- Thresholds (warn/critical) stay first-class for gauges.

## Considered Options

1. **Closed list of ten built-in segments**, extended by new ADRs.
2. Built-ins plus `[custom.x] command = "…"` segments running shell commands, as Starship does.
3. Built-ins plus generic `[json.x] path = "cost.total_cost_usd"` segments reading any input field.

## Decision Outcome

**Option 1.** Option 3 is a cheap future addition and needs no architectural change; option 2 breaks the no-subprocess rule.

### Segments

| Segment | Variables | Extra keys | Shows nothing when |
|---------|-----------|------------|--------------------|
| `model` | `$name` (display_name, else id) | | no model |
| `effort` | `$level` | `hide_levels = ["medium"]` | no effort, or level hidden |
| `context` | `$percentage`, `$bar`, `$tokens` (`45k/200k`) | `bar_width`, `bar_fill`, `bar_empty`, `threshold_warn`, `threshold_critical`, `style_warn`, `style_critical` | `used_percentage` absent (before first reply) |
| `rate_limits` | `$five_hour`, `$seven_day`, `$five_hour_reset`, `$seven_day_reset` (`2h13m`) | thresholds and warn/critical styles as `context` | no `rate_limits` (not Pro/Max, or before first reply) |
| `cost` | `$usd` (`$1.23`), `$duration` (`1h02m`), `$added`, `$removed` | `precision` | no `cost` |
| `directory` | `$path` | `truncation_length` (default 3 components), `home_symbol = "~"`, `truncation_symbol = "…/"` | no `current_dir` nor `cwd` |
| `git_branch` | `$branch` (branch name, or short SHA when detached) | `truncation_length` | no `.git` found walking up from the directory |
| `session_name` | `$name` | | no `session_name` |
| `vim_mode` | `$mode` (`NORMAL`, `INSERT`) | `normal_style`, `insert_style` | no `vim` |
| `fill` | | `symbol = " "` | never; expands to padding |

`git_branch` reads `.git/HEAD`; if `.git` is a file (worktree or submodule) it follows the `gitdir:` line once. Anything unreadable means "no branch". No status, ahead/behind or dirty flags: those need `git` or an index parser and are out of scope.

Gauges (`context`, `rate_limits`) pick `style`, `style_warn` or `style_critical` from the percentage; `$style` in their `format` resolves to the chosen one.

### Style vocabulary

A style is a space-separated list of words, as in Starship:

- Attributes: `bold`, `dim`, `italic`, `underline`, `inverted`, `none`.
- Colours: `black red green yellow blue magenta cyan white`, `bright-<name>`, `0`–`255`, `#rrggbb`, or a palette name (ADR 0006).
- `bg:<colour>` sets the background; a bare colour sets the foreground.

Rendered as SGR escapes; truecolour is emitted as given, no downsampling. Width computations use display width, so East Asian and emoji symbols align.

### Consequences

- Good: everything the seed did is here, plus five segments, with no new runtime dependency.
- Good: adding a segment is one proc, one table row here, one fixture.
- Bad: `git_branch` without dirty state is less than Starship offers; acceptable given the no-subprocess rule.
- Bad: display-width handling needs a small width table in `style`; `std/unicode` gives code points, not widths.

### Confirmation

Each segment has a fixture where it shows and one where it is empty (ADR 0008). `shiori preview` with the default preset prints every segment on a full fixture.

## Pros and Cons of the Options

1. **Closed list**: predictable budget, no shell; users wait for a release to get a new segment.
2. **Custom commands**: infinite flexibility; subprocess per refresh, unbounded time, the thing this project refuses.
3. **Generic JSON path**: flexible and cheap; styling and formatting of arbitrary values gets fiddly. Deferred, not rejected.

## More Information

- Starship style strings: <https://starship.rs/advanced-config/#style-strings>.
- Related: ADR 0003, ADR 0004, ADR 0006, ADR 0007.
