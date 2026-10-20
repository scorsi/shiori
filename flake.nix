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
          formatting = pkgs.runCommand "shiori-formatting" { } ''
            ${lib.getExe pkgs.nixfmt} --check ${./flake.nix} ${./nix}
            touch $out
          '';
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
          # nim_lk's HTTPS client dlopens a bare "libssl.3.dylib", which falls through to the
          # system LibreSSL on macOS and segfaults; point it at nixpkgs' OpenSSL.
          nimLk = pkgs.writeShellScriptBin "nim_lk" ''
            ${lib.optionalString pkgs.stdenv.hostPlatform.isDarwin "export DYLD_LIBRARY_PATH=${pkgs.openssl.out}/lib"}
            exec ${lib.getExe pkgs.nim_lk} "$@"
          '';
        in
        {
          default = pkgs.mkShellNoCC {
            packages = [
              pkgs.nim
              nimLk
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
