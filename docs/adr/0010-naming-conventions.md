---
status: accepted
date: 2026-10-14
decision-makers: scorsi
---

# Naming conventions

## Context and Problem Statement

The author's repositories carry Japanese names drawn from construction (jiban, ishizue, kiso, kanna, sekkeizu). Inside the tool, users type segment names, TOML keys, subcommands and Nix options. Where does Japanese stop and English start?

## Decision Drivers

- Discoverability: a Starship user should guess `git_branch`, not look up a word.
- Consistency with home-manager (`programs.<name>.camelCase`) and TOML (`snake_case`) conventions.
- The project name is part of the author's naming scheme, not of the user interface.

## Considered Options

1. **Japanese for the project name only; explicit English everywhere else.**
2. Japanese flavour inside too (segment or preset names).
3. English project name.

## Decision Outcome

**Option 1.**

| Thing | Convention | Example |
|-------|------------|---------|
| Project, repository, binary, flake input | Japanese, lowercase romaji; flake input prefixed `scorsi-` in consumers | `keiki`, `scorsi-keiki` |
| Segments, variables, TOML keys | English `snake_case`, Starship's words when one exists | `git_branch`, `threshold_warn` |
| Subcommands and flags | English, kebab-case | `timings`, `preview --fixture` |
| Nix options | `programs.<project>.camelCase` | `programs.keiki.claudeCode.enable` |
| Presets, palettes | English kebab-case; upstream theme names kept as spelled | `nerd-font`, `catppuccin-mocha` |
| Files | kebab-case; ADRs `NNNN-kebab-title.md` | `0004-configuration-format.md` |
| Nim modules | one lowercase word | `render`, `segments` |
| Commits | conventional commits, as in sekkeizu | `feat(segments): add cost` |
| Code comments, docs | English, why not what; discussion with the author may be French but nothing French lands in the repo | |

### Consequences

- Good: zero vocabulary to learn beyond the project name.
- Good: renaming the project touches the binary name and Nix option prefix only; everything else is stable.
- Bad: the name's meaning (計器, the gauges of a cockpit, a nod to Starship) is invisible in use; a line in the README explains it.

### Confirmation

A grep for non-ASCII identifiers in `src/`, `presets/` and the module finds none. The README has a "Name" paragraph.

## Pros and Cons of the Options

1. **Japanese outside, English inside**: fits the author's scheme and user expectations.
2. **Japanese inside**: charming; every user reads docs to write a format string.
3. **English name**: self-explanatory; breaks the author's scheme for no user benefit.

## More Information

- Related: all ADRs; ADR 0009 for Nix option names.
