# programs.shiori (ADR 0009): the binary, ~/.config/shiori.toml and Claude Code's statusLine.
self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.shiori;
  toml = pkgs.formats.toml { };
  presets = cfg.package.presets;
  settings = lib.recursiveUpdate (builtins.fromTOML (
    builtins.readFile (presets + "/${cfg.preset}.toml")
  )) cfg.settings;
  claudeCodeModule = config.programs ? claude-code && config.programs.claude-code.enable;
  patch = pkgs.writeText "shiori-claude-code-settings.json" (
    builtins.toJSON {
      statusLine = {
        type = "command";
        command = "SHIORI_CONFIG=${lib.escapeShellArg cfg.configFile} ${lib.getExe cfg.package}";
      };
    }
  );
in
{
  options.programs.shiori = {
    enable = lib.mkEnableOption "shiori, a status line for Claude Code";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      defaultText = lib.literalExpression "shiori.packages.\${system}.default";
      description = "The shiori package.";
    };

    settings = lib.mkOption {
      inherit (toml) type;
      default = { };
      example = lib.literalExpression ''{ context.bar_width = 6; effort.hide_levels = [ "medium" ]; }'';
      description = "Recursively merged over the preset; arrays are replaced wholesale.";
    };

    preset = lib.mkOption {
      type = lib.types.enum (
        map (lib.removeSuffix ".toml") (
          builtins.filter (name: lib.hasSuffix ".toml" name) (builtins.attrNames (builtins.readDir presets))
        )
      );
      default = "plain";
      description = "The complete preset to use as the base configuration.";
    };

    configFile = lib.mkOption {
      type = lib.types.path;
      default = "${config.xdg.configHome}/shiori.toml";
      defaultText = lib.literalExpression ''"''${xdg.configHome}/shiori.toml"'';
      description = "Absolute path under the home directory for the generated TOML file.";
    };

    claudeCode = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Point Claude Code's statusLine at shiori, keeping every other key of settings.json.";
      };

      settingsFile = lib.mkOption {
        type = lib.types.str;
        default =
          if claudeCodeModule then
            "${config.programs.claude-code.configDir}/settings.json"
          else
            "${config.home.homeDirectory}/.claude/settings.json";
        defaultText = lib.literalExpression ''"''${programs.claude-code.configDir}/settings.json" or "~/.claude/settings.json"'';
        description = "The Claude Code settings file to patch.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
    home.file.${cfg.configFile}.source = toml.generate "shiori.toml" settings;
    home.sessionVariables.SHIORI_CONFIG = cfg.configFile;

    # Merged into the mutable file rather than owning it: Claude Code writes to it too.
    home.activation.shioriClaudeCode = lib.mkIf cfg.claudeCode.enable (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        settings=${lib.escapeShellArg cfg.claudeCode.settingsFile}
        run mkdir -p "$(dirname "$settings")"
        [ -s "$settings" ] || echo '{}' > "$settings"
        tmp=$(mktemp)
        ${lib.getExe pkgs.jq} -s '.[0] * .[1]' "$settings" ${patch} > "$tmp"
        if cmp -s "$tmp" "$settings"; then rm "$tmp"; else run mv "$tmp" "$settings"; fi
      ''
    );
  };
}
