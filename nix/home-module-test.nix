# Evaluate the public module without adding home-manager as a flake input.
{
  self,
  pkgs,
  lib,
}:
let
  evaluate =
    module:
    (lib.evalModules {
      specialArgs = {
        inherit pkgs;
        lib = lib // {
          hm.dag.entryAfter = after: data: {
            inherit after data;
            before = [ ];
          };
        };
      };
      modules = [
        self.homeModules.shiori
        {
          options = {
            home.homeDirectory = lib.mkOption {
              type = lib.types.str;
              default = "/home/test";
            };
            home.packages = lib.mkOption {
              type = lib.types.listOf lib.types.package;
              default = [ ];
            };
            home.file = lib.mkOption {
              type = lib.types.attrsOf (
                lib.types.submodule {
                  options.source = lib.mkOption { type = lib.types.path; };
                }
              );
              default = { };
            };
            home.sessionVariables = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              default = { };
            };
            home.activation = lib.mkOption {
              type = lib.types.attrsOf (
                lib.types.submodule {
                  options = {
                    data = lib.mkOption { type = lib.types.lines; };
                    before = lib.mkOption { type = lib.types.listOf lib.types.str; };
                    after = lib.mkOption { type = lib.types.listOf lib.types.str; };
                  };
                }
              );
              default = { };
            };
            xdg.configHome = lib.mkOption {
              type = lib.types.str;
              default = "/home/test/.config";
            };
          };
        }
        module
      ];
    }).config;
  plain = evaluate { programs.shiori.enable = true; };
  themed = evaluate {
    programs.shiori = {
      enable = true;
      preset = "nerd-font";
      settings.context.bar_width = 4;
      settings.effort.hide_levels = [ "medium" ];
    };
  };
  custom = evaluate {
    programs.shiori = {
      enable = true;
      configFile = "/home/test/custom 'config'.toml";
    };
  };
  withoutIntegration = evaluate {
    programs.shiori = {
      enable = true;
      claudeCode.enable = false;
    };
  };
  disabled = evaluate { };
  withClaude = evaluate {
    options.programs.claude-code = {
      enable = lib.mkOption { default = true; };
      configDir = lib.mkOption { default = "/home/test/custom-claude"; };
    };
    config.programs.shiori.enable = true;
  };
  invalid = evaluate { programs.shiori.preset = "missing"; };
  activation = pkgs.writeText "shiori-activation" themed.home.activation.shioriClaudeCode.data;
  customActivation = pkgs.writeText "shiori-custom-activation" custom.home.activation.shioriClaudeCode.data;
in
assert plain.home.packages == [ plain.programs.shiori.package ];
assert plain.programs.shiori.configFile == "/home/test/.config/shiori.toml";
assert plain.programs.shiori.claudeCode.settingsFile == "/home/test/.claude/settings.json";
assert themed.home.activation.shioriClaudeCode.after == [ "writeBoundary" ];
assert custom.home.sessionVariables.SHIORI_CONFIG == "/home/test/custom 'config'.toml";
assert builtins.hasAttr "/home/test/custom 'config'.toml" custom.home.file;
assert withoutIntegration.home.activation == { };
assert
  disabled.home.packages == [ ] && disabled.home.file == { } && disabled.home.activation == { };
assert
  withClaude.programs.shiori.claudeCode.settingsFile == "/home/test/custom-claude/settings.json";
assert !(builtins.tryEval invalid.programs.shiori.preset).success;
pkgs.runCommand "shiori-home-module-test"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.jq
    ];
  }
  ''
    python3 - <<'PY'
    import tomllib
    from pathlib import Path
    plain = tomllib.loads(Path('${
      plain.home.file.${plain.programs.shiori.configFile}.source
    }').read_text())
    themed = tomllib.loads(Path('${
      themed.home.file.${themed.programs.shiori.configFile}.source
    }').read_text())
    assert plain == tomllib.loads(Path('${../presets/plain.toml}').read_text())
    assert themed['palette'] == 'catppuccin-mocha'
    assert themed['context']['bar_width'] == 4
    assert themed['context']['bar_fill'] == '━'
    assert themed['effort']['hide_levels'] == ['medium']
    activation = Path('${activation}').read_text()
    assert "/home/test/.claude/settings.json" in activation
    assert "jq" in activation and ".[0] * .[1]" in activation
    PY
    sed "s|/home/test|$TMPDIR/home|g" ${activation} > activation.sh
    run() { "$@"; }
    mkdir -p "$TMPDIR/home/.claude"
    printf '{"keep": true, "statusLine": {"command": "old"}}' > "$TMPDIR/home/.claude/settings.json"
    source activation.sh
    jq -e --arg binary '${lib.getExe themed.programs.shiori.package}' \
      '.keep and .statusLine.type == "command" and (.statusLine.command | endswith($binary)) and
      (.statusLine.command | contains("SHIORI_CONFIG=/home/test/.config/shiori.toml"))' \
      "$TMPDIR/home/.claude/settings.json"
    cp "$TMPDIR/home/.claude/settings.json" before.json
    source activation.sh
    cmp before.json "$TMPDIR/home/.claude/settings.json"
    sed "s|/home/test|$TMPDIR/home|g" ${customActivation} > custom-activation.sh
    source custom-activation.sh
    jq -e --arg prefix ${lib.escapeShellArg "SHIORI_CONFIG=${lib.escapeShellArg custom.programs.shiori.configFile}"} \
      '.statusLine.command | startswith($prefix)' "$TMPDIR/home/.claude/settings.json"
    touch $out
  ''
