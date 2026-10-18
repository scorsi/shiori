---
status: accepted
date: 2026-10-14
decision-makers: scorsi
---

# Testing strategy

## Context and Problem Statement

The program is a pure function from (stdin JSON, config, `COLUMNS`) to text. Claude Code's JSON changes over releases. How is behaviour pinned so that refactors and upstream changes are caught?

## Decision Drivers

- Tests run in `nix flake check` with no network and no Claude Code installed.
- Fixtures must contain no personal data (paths, session ids, cost).
- Nim's standard library only: `std/unittest`.

## Considered Options

1. **Fixture-driven snapshot tests plus unit tests for the parsers.**
2. Unit tests only, hand-asserted strings per segment.
3. End-to-end against a real Claude Code session.

## Decision Outcome

**Option 1.**

- `tests/fixtures/<name>.json`: input documents. Version 1 set: `full` (Pro/Max session, every field), `minimal` (`{}`), `invalid` (not JSON), `pre-first-reply` (`current_usage: null`, no `rate_limits`), `free-plan` (no `rate_limits`), `post-compact`, `detached-head`, `narrow` (used with `COLUMNS=40`). Captured from the reference Claude Code version (ADR 0001) and sanitised: `cwd` under `/home/user/`, synthetic `session_id`, round numbers.
- `tests/snapshots/<fixture>.<preset>.txt`: expected stdout for each fixture and each preset, ANSI included. A test renders and compares; `SHIORI_UPDATE_SNAPSHOTS=1` rewrites them and the diff is reviewed in git.
- Unit tests for `format` (grammar of ADR 0004), `style` (words to SGR, display width), `input` (type tolerance), and `git_branch` on temporary directories (branch, detached, worktree file, no repo).
- Contract check: a test asserts that every field in ADR 0003's table is present in `full`, so bumping the reference version and recapturing fails loudly if a field vanished.
- Run with `nim r tests/all.nim`; `buildNimPackage`'s `doCheck` runs the same in the flake check. Fixtures are embedded with `staticRead` so `preview` and tests share them.

### Consequences

- Good: a refactor of `render` is validated against every preset and edge case in one run.
- Good: fixtures double as `preview` material and as documentation of the input contract.
- Bad: snapshots with ANSI codes are hard to read in diffs; `preview` on the same fixture shows the rendered result.
- Bad: no test proves Claude Code actually calls us correctly; milestone 1's exit criterion is manual (the line shows up).

### Confirmation

`nix flake check` passes on `aarch64-darwin` and `x86_64-linux`. Deleting a field from `full` fails the contract test.

## Pros and Cons of the Options

1. **Snapshots + unit**: broad coverage for little code; snapshot churn on intentional changes, mitigated by the update flag.
2. **Unit only**: readable assertions; misses interactions between segments, fill and width.
3. **End to end**: proves the integration; needs a TTY, an account and a network, impossible in the sandbox.

## More Information

- Related: ADR 0003, ADR 0004, ADR 0005, ADR 0007, ADR 0009.
