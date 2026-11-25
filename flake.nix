##
# pleamar-config — the pleamar desktop shell as a self-contained flake.
#
# What lives here: the `.plm` scene tree (`shells/`, `lib/`, `themes/`,
# `art.plm`, `theme.plm`), the Rust helper crates that the scenes spawn, the
# engine patches, the nix-maid module that deploys the shell and the login
# layer that paints the greetd screen.
#
# What does not: host glue (Hyprland keybinds, the feature flag, policy and
# unit overrides) stays in the host repository, which consumes this flake as an
# input.
##
{
  description = "pleamar shell configuration: scenes, libraries, themes, workers and the login layer";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Upstream engine. The rev is the one the host used before the split and
    # the patch series in `patches/` was re-based on it.
    pleamar = {
      url = "github:k4ditano/pleamar/eebd61adf88b25b6f3fb607d632b84a359237f7c";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pleamar-wm = {
      url = "github:k4ditano/pleamar-wm/5d8771bab7968a7134825a93c6cfbd811a75cdab";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pleamar.follows = "pleamar";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      pleamar,
      pleamar-wm,
      ...
    }:
    let
      lib = nixpkgs.lib;
      systems = [ "x86_64-linux" ];

      # Patch order matters: import-path first (the symlink farm loads scenes
      # through it), then the surface/behaviour fixes, media last.
      enginePatches = [
        ./patches/pleamar-import-path.patch
        ./patches/pleamar-right-click.patch
        ./patches/pleamar-dbusmenu.patch
        ./patches/pleamar-closed-surface.patch
        ./patches/pleamar-unmap-closed.patch
        ./patches/pleamar-media-state.patch
        ./patches/pleamar-transport-flags.patch
        ./patches/pleamar-media-position.patch
        ./patches/pleamar-soft-render.patch
        ./patches/pleamar-lock-engage.patch
        ./patches/pleamar-lock-full.patch
        ./patches/pleamar-bluetooth.patch
      ];

      # Every crate the scenes spawn by name, plus the developer harnesses.
      crateNames = [
        "pleamar-calendar"
        "pleamar-harness"
        "pleamar-kbdlayout"
        "pleamar-picker"
        "pleamar-sysmon"
        "pleamar-theme"
        "pleamar-weather"
        "wallpaper-palettes"
      ];

      overlay =
        final: prev:
        let
          system = final.stdenv.hostPlatform.system;
          mkMeta = prev.callPackage ./packages/lib/mkMeta.nix { };
        in
        {
          # `lib.mkMeta` is the shared `meta` builder the crate files use; it
          # lives here so the crates stay self-contained.
          lib = prev.lib.extend (_libFinal: _libPrev: { inherit mkMeta; });

          pleamar = pleamar.packages.${system}.pleamar.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ enginePatches;
          });
          pleamar-wm = pleamar-wm.packages.${system}.pleamar-wm;

          # The tree the login layer and the module deploy: the scene tree in
          # the layout the scenes import from (root carries `theme.plm`,
          # `shells/` and `lib/` are siblings).
          pleamar-tree = final.runCommand "pleamar-tree" { } ''
            mkdir -p $out
            cp -r ${./shells} $out/shells
            cp -r ${./lib} $out/lib
            cp -r ${./themes} $out/themes
            cp -r ${./scripts} $out/scripts
            cp ${./art.plm} $out/art.plm
            cp ${./theme.plm} $out/theme.plm
          '';
        }
        // lib.genAttrs crateNames (name: final.callPackage (./packages + "/${name}") { });

      forSystem =
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ overlay ];
          };
        in
        {
          packages = {
            default = pkgs.pleamar;
            tree = pkgs.pleamar-tree;
          }
          // lib.genAttrs (
            [
              "pleamar"
              "pleamar-wm"
            ]
            ++ crateNames
          ) (name: pkgs.${name});

          checks = {
            tree = pkgs.pleamar-tree;
          };

          formatter = pkgs.nixfmt;

          devShells.default = pkgs.mkShell {
            packages = [
              pkgs.pleamar # `pleamar --check` over the scenes
              pkgs.shellcheck
              pkgs.shfmt
              pkgs.statix
              pkgs.deadnix
            ];
          };
        };
    in
    {
      inherit overlay;
      overlays.default = overlay;

      packages = lib.genAttrs systems (system: (forSystem system).packages);
      checks = lib.genAttrs systems (system: (forSystem system).checks);
      devShells = lib.genAttrs systems (system: (forSystem system).devShells);
      formatter = lib.genAttrs systems (system: (forSystem system).formatter);

      # Two modules: the session shell and the greetd login layer. The host
      # imports `default` and sets the options (`enable`, `liveRoot`).
      nixosModules = {
        default = {
          imports = [
            ./modules/shell.nix
            ./modules/login.nix
          ];
        };
        shell = ./modules/shell.nix;
        login = ./modules/login.nix;
      };
    };
}
