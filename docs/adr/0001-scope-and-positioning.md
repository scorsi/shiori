---
status: accepted
date: 2026-10-14
decision-makers: scorsi
---

# Scope and positioning of shiori

## Context and Problem Statement

shiori (栞, a bookmark; first called hikouki, 飛行機, then keiki, 計器) started as "a Starship for Claude Code": status line, hooks writing per-session state, tmux segment, notifications, in one binary. Since then Starship 1.25 ships a native `statusline claude-code` subcommand, several Rust status lines exist, and Claude Code itself reports session status to terminals (OSC 7501, `claude agents --json`, desktop notifications).

The author already runs a 170-line Nim status line compiled by Nix inside sekkeizu (`modules/home/claude-code-statusline.nim`), with compile-time constants for every setting.

What is shiori for, and how much of the original ambition belongs to version 1?

## Decision Drivers

- For fun and to show, not a product: one person must enjoy maintaining it.
- Must replace the sekkeizu status line at the first milestone, so it is used daily from the start.
- sekkeizu's rule: application code lives in its own flake, not under `modules/`.
- Nix flake + home-manager module from version 1 (non-negotiable).
- Multi-session awareness is a real need, but Claude Code and terminals are starting to cover it.

## Considered Options

1. Full toolkit from day one (original plan).
2. Status line first; hooks, state, tmux, notifications in later optional milestones.
3. Do not build it; use Starship or cship.

## Decision Outcome

**Option 2.** Version 1 is:

- a Nim binary reading the Claude Code status line JSON on stdin and printing styled lines, configured by a TOML file with a Starship-style format string;
- a Nix flake: package, home-manager module (writes the TOML, installs the `statusLine` entry in `settings.json`), checks;
- consumed by sekkeizu, possibly later by kanna, as flake input `scorsi-shiori`.

Deferred and not designed: hooks, per-session state and its privacy rules, tmux segment, notifications, `shiori init`, plugin packaging, distribution outside Nix, Windows.

Reference Claude Code version: **2.1.296** (pinned in sekkeizu). Input is read tolerantly, so older versions degrade rather than fail (ADR 0003). Licence: **MIT**.

### Consequences

- Good: milestone 1 is close to the existing file; sekkeizu goes back to configuration only.
- Good: ten ADRs instead of fifteen; deferred topics get ADRs when their milestone opens.
- Bad: the multi-session need stays unmet by shiori for now.
- Bad: ADR 0002 must keep room for a `hook` subcommand that may never come.
- Neutral: overlap with Starship is accepted; shiori exists because its author wants it in Nim and Nix with their own segments.

### Confirmation

`docs/milestones.md` keeps hooks, tmux and notifications in a later optional milestone. A `LICENSE` file holds the MIT text. After milestone 1, sekkeizu's `claude-code.nix` no longer builds a status line.

## Pros and Cons of the Options

1. **Full toolkit**: covers the need, but needs a dozen design decisions before anything ships, a plugin cannot set `statusLine`, and the features compete with what Claude Code now does natively.
2. **Status line first**: usable at milestone 1, extends working code, keeps the door open; costs some reserved space in the architecture.
3. **Do not build**: maintained by others, but not Nim, not Nix, and missing rate limits, effort, session name and vim mode.

## More Information

- Prior art: Starship 1.25.0, cship, CCometixLine, ccstatusline, sotayamashita/claude-code-statusline (archived), starship-claude.
- Status line docs: <https://code.claude.com/docs/en/statusline>.
- Seed: sekkeizu `modules/home/claude-code-statusline.nim` and `claude-code.nix` (its `settings.json` jq patch is reused in ADR 0009).
