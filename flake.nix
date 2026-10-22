{
  description = "shiori (栞, the bookmark) — a Starship-style status line for Claude Code";

  # Same branch as sekkeizu, which makes this input follow its own nixpkgs anyway.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;
      forAllSystems = lib.genAttrs [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      pkgsFor = system: nixpkgs.legacyPackages.${system};
      # Keep Nim HTTPS on nixpkgs' OpenSSL rather than macOS's incompatible LibreSSL.
      nimLkFor =
        pkgs:
        pkgs.writeShellScriptBin "nim_lk" ''
          ${lib.optionalString pkgs.stdenv.hostPlatform.isDarwin "export DYLD_LIBRARY_PATH=${pkgs.openssl.out}/lib"}
          exec ${lib.getExe pkgs.nim_lk} "$@"
        '';
    in
    {
      packages = forAllSystems (
        system:
        let
          shiori = (pkgsFor system).callPackage ./nix/package.nix { };
        in
        {
          inherit shiori;
          default = shiori;
        }
      );

      homeModules.shiori = import ./nix/home-module.nix self;
      homeModules.default = self.homeModules.shiori;
      homeManagerModules = self.homeModules;

      overlays.default = final: _prev: { shiori = final.callPackage ./nix/package.nix { }; };

      checks = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          # The package runs tests/t*.nim and the installed-binary checks.
          shiori = self.packages.${system}.default;
          home-module = import ./nix/home-module-test.nix { inherit self pkgs lib; };
          formatting = pkgs.runCommand "shiori-formatting" { } ''
            ${lib.getExe pkgs.nixfmt} --check ${./flake.nix} ${./nix}
            touch $out
          '';
        }
      );

      apps = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          bench = pkgs.writeShellApplication {
            name = "shiori-bench";
            runtimeInputs = [
              pkgs.hyperfine
              pkgs.jq
            ];
            text = ''
              fixture_home=$(mktemp -d "$PWD/.shiori-bench.XXXXXX")
              trap 'rm -rf "$fixture_home"' EXIT
              mkdir -p "$fixture_home/project/.git"
              printf 'ref: refs/heads/main\n' > "$fixture_home/project/.git/HEAD"
              jq --arg dir "$fixture_home/project" \
                '.cwd = $dir | .workspace.current_dir = $dir | .workspace.project_dir = $dir' \
                ${./tests/fixtures/full.json} > "$fixture_home/full.json"
              results="$fixture_home/results.json"
              export COLUMNS=80 SHIORI_CONFIG=${./presets/plain.toml}
              hyperfine --warmup 10 --runs 100 --shell=none \
                --input "$fixture_home/full.json" --export-json "$results" \
                ${lib.getExe self.packages.${system}.default}
              median=$(jq '.results[0].median * 1000' "$results")
              printf 'Median: %.3f ms (budget: 5 ms)\n' "$median"
              jq -e '.results[0].median < 0.005' "$results" > /dev/null
            '';
          };
          lock = pkgs.writeShellApplication {
            name = "shiori-lock";
            runtimeInputs = [
              (nimLkFor pkgs)
              pkgs.jq
            ];
            text = ''
              pending=$(mktemp ./lock.json.XXXXXX)
              trap 'rm -f "$pending"' EXIT
              nim_lk nimble-to-nix "$@" > "$pending"
              jq -e '.depends | type == "array"' "$pending" > /dev/null
              mv "$pending" lock.json
            '';
          };
        in
        {
          bench = {
            type = "app";
            program = lib.getExe bench;
            meta.description = "Benchmark the full fixture against the 5 ms median budget";
          };
          lock = {
            type = "app";
            program = lib.getExe lock;
            meta.description = "Regenerate lock.json with the development shell's nim_lk wrapper";
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          # The lock.json sources, for `nim c` outside Nix (read by config.nims).
          depPaths = map (
            d:
            "${
              pkgs.fetchzip {
                name = "source";
                inherit (d) url sha256;
              }
            }/${d.srcDir}"
          ) (lib.importJSON ./lock.json).depends;
        in
        {
          default = pkgs.mkShellNoCC {
            packages = [
              pkgs.nim
              (nimLkFor pkgs)
              pkgs.hyperfine
              pkgs.jq
              pkgs.nixfmt
            ];
            SHIORI_NIM_PATHS = lib.concatStringsSep ":" depPaths;
          };
        }
      );

      formatter = forAllSystems (system: (pkgsFor system).nixfmt-tree);
    };
}
