---
status: accepted
date: 2026-10-14
decision-makers: scorsi
---

# Presets and palettes

## Context and Problem Statement

A full configuration is forty lines of TOML. Users (first of all the author on two machines) want to start from something that looks good and tweak a key or two. Terminals differ in fonts (Nerd Font or not) and colour schemes. How are ready-made configurations and colour themes delivered?

## Decision Drivers

- Starship's model (presets as complete TOML files, palettes as named colour tables) is familiar.
- The home-manager module must be able to select a preset and override keys declaratively (ADR 0009).
- Keep the binary ignorant of as much as possible.

## Considered Options

1. **Presets as TOML files in the repository, palettes as a config feature**; selection and merging done by Nix.
2. Presets embedded in the binary, selected with `preset = "name"` in the config or a `keiki preset` subcommand.
3. A separate theme layer (colours and symbols) orthogonal to presets.

## Decision Outcome

**Option 1.**

- `presets/<name>.toml` in the repository, each a complete, valid configuration. Version 1 ships `plain` (ASCII, named colours; also the built-in default when no file is found) and `nerd-font` (Nerd Font symbols). Later presets are added without an ADR.
- The flake exposes them (`presets` passthru on the package) so the home-manager module can read one with `builtins.fromTOML`, apply the user's `settings` with `recursiveUpdate`, and write the result (ADR 0009).
- The binary has no notion of preset. `keiki preview` takes `--config <path>` to try one by hand.
- Palettes are a config feature, as in Starship: `[palettes.<name>]` maps colour names to colours, `palette = "<name>"` activates one, and style words are looked up in the active palette before the built-in colour names. A theme is therefore a preset that only defines a palette, or a palette table pasted into any preset.

### Consequences

- Good: the binary stays small; presets are data reviewed like any file.
- Good: switching the Catppuccin flavour on one machine is one `palette` line in Nix.
- Bad: without Nix, applying a preset means copying a file; acceptable, Nix is the only distribution channel (ADR 0001).
- Bad: `recursiveUpdate` replaces arrays wholesale (e.g. `hide_levels`); documented, not worked around.

### Confirmation

Every file under `presets/` parses and renders the full fixture in tests (ADR 0008). The home-manager test (ADR 0009) builds a config from `nerd-font` with one overridden key.

## Pros and Cons of the Options

1. **Files + Nix merge**: simplest binary, declarative merge; no preset switching outside Nix.
2. **Embedded presets**: works everywhere, `keiki preset catppuccin > ~/.config/keiki.toml`; adds a subcommand, a merge policy and rebuilds per preset change. Could be added later if non-Nix users ever appear.
3. **Theme layer**: separates symbols from colours; a second concept to explain when palettes already cover colours.

## More Information

- Starship presets and palettes: <https://starship.rs/presets/>, <https://starship.rs/config/#palette>.
- Related: ADR 0004, ADR 0005, ADR 0009.
