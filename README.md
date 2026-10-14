# keiki (計器)

The gauges: a status line for [Claude Code](https://code.claude.com/docs/en/statusline), in Nim,
configured like [Starship](https://starship.rs) (a TOML file, a `format` string), shipped as a Nix
flake with a home-manager module. Consumed by [sekkeizu](https://github.com/scorsi/sekkeizu) as a
pinned input; for fun and to show, not a product.

**Status: design.** Nothing is built yet. The decisions are in [`docs/adr/`](docs/adr/README.md)
(ten records, MADR format) and the plan in [`docs/milestones.md`](docs/milestones.md). What follows
describes the tool those decisions specify.

## What it shows

Model, effort level, context usage (bar, percentage, tokens), rate limits with time to reset,
session cost, directory, git branch, session name, vim mode, and a `fill` to align the rest to the
right. Everything comes from the JSON Claude Code pipes on stdin, plus `.git/HEAD` for the branch:
no subprocess, no network, under 5 ms.

## Using it

```bash
nix run github:scorsi/keiki -- preview          # render a sample session with your config
nix run github:scorsi/keiki -- timings          # per-segment timings on stdin JSON
```

Home-manager, in a flake that has `scorsi-keiki` as input:

```nix
imports = [ inputs.scorsi-keiki.homeModules.keiki ];
programs.keiki = {
  enable = true;                 # installs the binary and writes ~/.config/keiki.toml
  preset = "nerd-font";          # or "plain" (default)
  settings.palette = "catppuccin-mocha";
  # claudeCode.enable = true;    # default: adds statusLine to ~/.claude/settings.json, keeps the rest
};
```

The `statusLine` entry is merged into Claude Code's `settings.json` at activation rather than
owning the file, so Claude Code can keep writing to it.

## Configuration

`$KEIKI_CONFIG`, else `~/.config/keiki.toml`, else built-in defaults. A Starship user needs no
manual:

```toml
format = """
[$model](bold cyan) $effort $context $fill $rate_limits
$directory $git_branch
"""

[context]
bar_width = 10
threshold_warn = 70
threshold_critical = 90
```

`$segment` expands a segment, `[text](style)` styles it and vanishes when its variables are empty,
`$fill` pads to the terminal width. Segments and their keys: [ADR 0005](docs/adr/0005-segments-and-style-vocabulary.md);
grammar: [ADR 0004](docs/adr/0004-configuration-format.md).

## Flake outputs

| Output                | What it is                                                              |
| --------------------- | ----------------------------------------------------------------------- |
| `packages.default`    | the `keiki` binary (`buildNimPackage`, `lock.json` from `nim_lk`)        |
| `homeModules.keiki`   | `programs.keiki.*`: config file, preset, Claude Code integration        |
| `overlays.default`    | adds `keiki`                                                            |
| `checks`              | snapshot and unit tests on fixtures, formatting                         |
| `apps.bench`, `apps.lock` | `hyperfine` run against the 5 ms budget; regenerate `lock.json`     |

## Layout (planned)

```
src/keiki/          input, config, format, segments, style, render, cli
presets/            plain.toml, nerd-font.toml
tests/fixtures/     sanitised Claude Code stdin documents
tests/snapshots/    expected output per fixture and preset
nix/                package, home-manager module
docs/adr/           decisions; docs/milestones.md the plan
```

## Name

計器 are the instruments of a cockpit: what you glance at while flying. The project was first
called hikouki (飛行機, aeroplane), a nod to Starship; the gauges are what you actually look at.
