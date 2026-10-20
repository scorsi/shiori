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
  claudeCodeModule = config.programs ? claude-code && config.programs.claude-code.enable;
  patch = pkgs.writeText "shiori-claude-code-settings.json" (
    builtins.toJSON {
      statusLine = {
        type = "command";
        command = lib.getExe cfg.package;
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
      description = "Written to ~/.config/shiori.toml; keys left out keep the built-in defaults.";
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
    xdg.configFile."shiori.toml".source = toml.generate "shiori.toml" cfg.settings;

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
