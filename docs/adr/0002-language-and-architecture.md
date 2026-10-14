---
status: accepted
date: 2026-10-14
decision-makers: scorsi
---

# Language and binary architecture

## Context and Problem Statement

Claude Code spawns the status line command on every refresh (each assistant message, `refreshInterval`, mode changes), debounced at 300 ms and killed when a new event arrives. A blank line is shown on non-zero exit or empty output. Startup time matters more than throughput.

Which language, how many binaries, which subcommands, and what must version 1 not preclude (ADR 0001 defers hooks and state)?

## Decision Drivers

- Startup in the low milliseconds.
- Simple Nix packaging; the author already builds Nim tools with nixpkgs.
- A language the author enjoys.
- Never crash: degraded output, never blank.
- Adding `hook` later must not require restructuring.
- No subprocess, no network in the render path.

## Considered Options

Language: **Nim 2.2** / Rust / shell or Nushell script.

Shape: **A. one binary with subcommands** / B. one binary per role / C. library + thin CLI.

## Decision Outcome

**Nim 2.2, one binary with a subcommand dispatcher.**

Nim: it is what the author wants to write, the seed already exists in Nim, nixpkgs ships Nim 2.2.4, and a release build starts in about a millisecond. Rust's richer ecosystem does not matter for a program with one TOML dependency.

One binary: all roles share input, config and rendering; Nix exposes one package.

### Internal layout

One Nim package (`keiki.nimble`, `lock.json`), modules under `src/keiki/`:

| Module     | Responsibility                                                                   |
|------------|----------------------------------------------------------------------------------|
| `input`    | stdin JSON → typed all-optional record; never raises; unknown fields ignored (ADR 0003) |
| `config`   | locate and parse TOML → typed config with defaults; on error, stderr + defaults (ADR 0004) |
| `format`   | Starship-style format string (`$segment`, `[text](style)`, `$fill`) → small AST (ADR 0004) |
| `segments` | one proc per segment, `(input, config) → variables or nothing`; filesystem reads only for `directory` and `git_branch` (ADR 0005) |
| `style`    | style vocabulary → ANSI; width-aware fill (ADR 0005)                             |
| `render`   | walk the AST, call only referenced segments, assemble lines, apply `COLUMNS`      |
| `cli`      | subcommand dispatch, exit codes                                                  |

Fixtures under `tests/fixtures/*.json` are embedded at compile time (`staticRead`), so the binary needs no runtime data files.

### Subcommands (version 1)

| Invocation                           | Behaviour                                                              |
|--------------------------------------|------------------------------------------------------------------------|
| `keiki`                            | read stdin, render, print; what `settings.json` calls                   |
| `keiki timings`                    | same, plus per-segment wall time on stderr (ADR 0007)                   |
| `keiki preview [--fixture <name>]` | render an embedded fixture with the current config                      |
| `--version`, `--help`                | the usual                                                              |

Reserved, not designed: `keiki hook`, `keiki init`, `keiki tmux`. Adding them touches `cli` and a new module only.

### Robustness rules

- One `try`/`except CatchableError` in `main`; on failure print a fallback line (model name if parsed, else `keiki`) and exit 0.
- Default `--panics:off` so defects are catchable too.
- stdout is the rendered line only; diagnostics on stderr.
- `-d:release`, never `-d:danger`: bounds checks stay on.

### Dependency policy

Standard library plus one TOML library, chosen in ADR 0004. Anything else needs a new ADR and a `lock.json` entry.

### Consequences

- Good: the sekkeizu file maps onto `input`, `segments`, `style`; milestone 1 is a refactor plus TOML.
- Good: `preview` and `timings` allow config and performance work without a live session.
- Bad: the TOML library and its transitive dependencies are the only third-party code; if one breaks on a future Nim, the fallback is a pinned fork in `lock.json`.
- Bad: a new fixture needs a rebuild.

### Confirmation

One executable from `nim c -d:release`. `keiki preview` works with no config file. `{}` or invalid JSON on stdin exits 0 with a non-empty line. ADR 0007's benchmark confirms the startup budget.

## Pros and Cons of the Options

- **Nim**: author's choice, nixpkgs has compiler and `nim_lk`, `staticRead` and `std/json` fit; thin ecosystem.
- **Rust**: serde/toml/clap/insta solve everything; heavier Nix build, no longer what the author wants here.
- **Shell/Nushell**: no build step; `jq` per refresh is slower, untyped, and a format parser in shell is painful.
- **A one binary**: one package, one lock, one `bin/`; carries developer subcommands users never call.
- **B per role**: trivial binaries; shared code needs a library package or duplication.
- **C lib + CLI**: clean; one consumer and double the Nix work.

## More Information

- <https://code.claude.com/docs/en/statusline>; nixpkgs `doc/languages-frameworks/nim.section.md`; .
- Related: ADR 0003, 0004, 0005, 0007, 0009.
