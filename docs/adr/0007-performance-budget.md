---
status: accepted
date: 2026-10-14
decision-makers: scorsi
---

# Performance budget and measurement

## Context and Problem Statement

Claude Code runs the status line several times a minute and kills a run when a new event arrives; a slow status line is a flickering or stale one. How fast must keiki be, and how is it kept there?

## Decision Drivers

- Human perception: anything under ~10 ms is instant; the seed Nim program runs in about 1 ms.
- Work must scale with the format string, not with the number of segments that exist.
- Measurement must be cheap enough to run on every change.

## Considered Options

1. **Budget on total wall time, enforced by a benchmark app and per-segment `timings`.**
2. No explicit budget; rely on Nim being fast.
3. Per-segment timeouts at runtime.

## Decision Outcome

**Option 1.**

- Budget: **5 ms** median wall time for the `plain` preset on the full fixture, measured on the author's machine with `hyperfine` (`nix run .#bench`). Startup included. Not a `nix flake check`: timing in a sandbox is noisy.
- `keiki timings` prints, on stderr, microseconds for parsing input, parsing config, each evaluated segment, and rendering, plus the input `version`. This is the tool for finding a slow segment.
- Laziness: `render` evaluates only segments referenced in the format AST, once each, even if referenced twice.
- Rules that keep the budget: no subprocess, no network, no locks; filesystem reads limited to `git_branch` (two small files at most) and the config file; fixtures and presets embedded at compile time; avoid `std/re` and other heavy-init modules.
- Release build flags: `-d:release`, `--opt:speed`, `--mm:orc` (default). No `-d:danger`.

### Consequences

- Good: a regression shows up in `nix run .#bench` before it shows up in the terminal.
- Good: a config that uses two segments pays for two segments.
- Bad: 5 ms is a local number; CI does not enforce it. Acceptable for a one-person project.
- Neutral: the TOML library's parse time counts against the budget; a 40-line file should be well under a millisecond, to be confirmed by `timings` in milestone 1.

### Confirmation

`nix run .#bench` reports a median under 5 ms for `plain` on the full fixture. `keiki timings` on a format that references one segment lists exactly that segment.

## Pros and Cons of the Options

1. **Budget + tools**: explicit and measurable; one number to revisit when hardware changes.
2. **No budget**: nothing to maintain; no way to notice a slow segment until it annoys.
3. **Runtime timeouts**: bounded worst case; threads or signals for a 1 ms program, and the lazy rule already removes the only unbounded work.

## More Information

- Starship's `starship timings` is the model for the subcommand.
- Related: ADR 0002, ADR 0004, ADR 0008, ADR 0009.
