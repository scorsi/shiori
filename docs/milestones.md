# Milestones

Ordered so that the author runs keiki daily from the first milestone on. Each milestone lists what is in, what is out, verifiable exit criteria and the ADRs it implements. "Daily use" means the author's Claude Code sessions on the nix-darwin machine show a keiki status line.

## M1 — Replace the sekkeizu status line

**Goal**: keiki does what `claude-code-statusline.nim` does today, from a flake, configured by TOML, installed by home-manager.

**In**
- Nim package, `lock.json`, `buildNimPackage`; flake outputs `packages`, `homeModules`, `checks`, `devShells`, `formatter` (ADR 0002, 0009).
- `input` for the fields of ADR 0003; `config` with file resolution and all-or-nothing error handling; `format` grammar (ADR 0004).
- Segments `model`, `effort`, `context`, `rate_limits` (ADR 0005), built-in defaults equal to the `plain` preset.
- Robustness rules of ADR 0002 (fallback line, exit 0, stderr only).
- Fixtures `full`, `minimal`, `invalid`, `pre-first-reply`, `free-plan` with snapshots for `plain`; format parser unit tests (ADR 0008).
- home-manager module: `enable`, `package`, `settings`, `claudeCode.enable` with the jq activation patch (ADR 0009).
- sekkeizu: input `scorsi-keiki`, module imported, old derivation and `statusLine` key removed.

**Out**: other segments, `fill`, palettes, presets other than the built-in default, `timings`, `preview`, bench, README beyond a paragraph.

**Exit criteria**
- `nix build` and `nix flake check` pass on `aarch64-darwin`.
- `echo '{}' | keiki` and `echo 'garbage' | keiki` print a non-empty line and exit 0.
- `keiki` on the `full` fixture renders the four segments; the snapshot is committed.
- A config with a parse error prints one stderr line and the default rendering.
- sekkeizu's `nix flake check` passes with `programs.keiki.enable = true`; after activation, `~/.claude/settings.json` has `statusLine.command` pointing at the store path and keeps every other key.
- Daily use: the author's sessions show the keiki line for one week without a blank line observed.

**ADRs**: 0001, 0002, 0003, 0004, 0005 (four segments), 0008 (partial), 0009, 0010.

## M2 — Full version 1

**Goal**: the ten segments, presets and palettes, developer tooling, performance budget met.

**In**
- Segments `cost`, `directory`, `git_branch`, `session_name`, `vim_mode`, `fill` (ADR 0005); display-width handling in `style`.
- Palettes; presets `plain` and `nerd-font`; module options `preset` and `configFile` (ADR 0006, 0009).
- `keiki timings`, `keiki preview [--fixture] [--config]`, `nix run .#bench`, `nix run .#lock` (ADR 0002, 0007, 0009).
- Remaining fixtures (`post-compact`, `detached-head`, `narrow`), snapshots per preset, `git_branch` tests on temporary repositories, contract test on `full` (ADR 0008).
- home-manager evaluation test in `checks` (ADR 0009).

**Out**: hooks, state, tmux, notifications; segments reading `prompt_cache`, `pr`, `agent`; non-Nix installation.

**Exit criteria**
- Every segment in ADR 0005 has a showing and an empty fixture; all snapshots pass for both presets.
- `nix run .#bench` reports a median under 5 ms for `plain` on `full` on the author's machine; the number is recorded in the README.
- `keiki timings` on a one-segment format lists exactly one segment.
- `COLUMNS=40` with `$fill` yields lines of at most 40 cells.
- Daily use: the author runs `nerd-font` with a Catppuccin palette, configured through `programs.keiki.settings` in sekkeizu.

**ADRs**: 0005, 0006, 0007, 0008, 0009 (complete).

## M3 — Publish

**Goal**: someone else could use it.

**In**
- `LICENSE` (MIT), README: name, what it does, install via flake and home-manager, config reference (every key of ADR 0004 and 0005), preset screenshots, the "no subprocess, no network" promise, the bench number.
- `nix flake check` on `x86_64-linux` (and `aarch64-linux` when the NixOS laptop exists); Forgejo Actions running `nix flake check` on push, if the Forgejo instance offers runners.
- GitHub mirror configured from Forgejo.
- ADR statuses moved to `accepted`; this file updated with what shipped.

**Out**: nimble publication, release binaries, Homebrew, Windows (ADR 0001).

**Exit criteria**
- `nix run github:scorsi/keiki -- preview` works from a machine without a clone.
- A fresh home-manager configuration importing the module and setting `programs.keiki.enable = true` builds and installs the status line with no other step.
- README config reference matches the code: a test or script lists every TOML key and fails if one is undocumented.

**ADRs**: 0001, 0010.

## M4 — Session awareness (optional)

**Goal**: know when the other session needs attention, without looking. The original hikouki idea, kept here so it is not lost; it may never start.

**In, to be designed first**: new ADRs for hooks as state writers (`keiki hook`), per-session state file (format, location, lifecycle, privacy: what is stored, what is refused), tmux segment, notifications, reconciliation with `claude agents --json`. Only then implementation.

**Out**: anything until those ADRs are accepted.

**Exit criteria**: the ADRs exist and are accepted; implementation criteria are written in them. Prerequisite: M2 done and still used daily, so the state consumer already exists.

**ADRs**: 0011 onwards.
