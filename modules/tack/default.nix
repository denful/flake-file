{ lib, config, ... }:
let
  inherit (config) flake-file;
  inherit (import ../lib.nix lib) inputsExpr;

  serialize = import ./serialize.nix lib;

  tackSrc = fetchTarball {
    url = "https://github.com/manic-systems/tack/archive/8c574901340af860979500f24495417ce7e53cdc.tar.gz";
    sha256 = "sha256-5dYWCjKBwjHOCJBlQK9iBKJxoUosTGQvI62vPBdQUgs=";
  };

  cfg = flake-file.tack;

  tackFields = builtins.mapAttrs (
    _: inp:
    lib.filterAttrs (_: v: v != null) {
      tackType = inp.tackType or null;
      unpack = inp.unpack or null;
    }
  ) flake-file.inputs;

  inputs = builtins.mapAttrs (name: inp: (tackFields.${name} or { }) // inp) (
    flake-file.preProcess (inputsExpr flake-file.inputs)
  );

  pinsToml = serialize {
    inherit inputs;
    inherit (cfg) shorturls allFollow recomposable;
  };

  tackDir = "${flake-file.intoPath}/${cfg.lockDir}";

  resolverExists = lib.hasPrefix "/" tackDir && builtins.pathExists "${tackDir}/default.nix";

  sources = if resolverExists then (import tackDir) { overrides = cfg.overrides; } else { };

  write-tack =
    pkgs:
    pkgs.writeShellApplication {
      name = "write-tack";
      meta.description = "Generate ${cfg.lockDir}/${cfg.pinsFile} from flake-file.inputs and run tack update.";
      runtimeInputs = [
        (cfg.package pkgs)
        pkgs.coreutils
      ];
      text = ''
        TACK_DIR=${lib.escapeShellArg tackDir}
        export TACK_DIR
        mkdir -p "$TACK_DIR"
        cp ${pkgs.writeText "pins.toml" pinsToml} "$TACK_DIR/${cfg.pinsFile}"
        chmod +w "$TACK_DIR/${cfg.pinsFile}"
        [ -e "$TACK_DIR/default.nix" ] || tack init --resolver
        exec tack update "$@"
      '';
    };
in
{
  config.flake-file.apps = { inherit write-tack; };

  options.flake-file.inputs = lib.mkOption {
    type = lib.types.lazyAttrsOf (
      lib.types.submodule {
        options = {
          tackType = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.enum [
                "flake"
                "fetch"
                "fixed"
              ]
            );
            default = null;
            description = "tack pin type. null defaults to flake (or fetch when `flake = false`).";
          };
          unpack = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.enum [
                "tarball"
                "file"
              ]
            );
            default = null;
            description = "tack unpack mode for fixed pins.";
          };
        };
      }
    );
  };

  options.flake-file.tack = {
    package = lib.mkOption {
      type = lib.types.functionTo lib.types.package;
      default = pkgs: pkgs.tack or (pkgs.callPackage "${tackSrc}/nix/package.nix" { });
      defaultText = lib.literalExpression "pkgs: pkgs.tack or (pkgs.callPackage \"\${tackSrc}/nix/package.nix\" { })";
      description = "Function from pkgs to the tack package providing the `tack` binary. Defaults to `pkgs.tack` when present, otherwise builds tack from a pinned source tarball.";
    };

    lockDir = lib.mkOption {
      type = lib.types.str;
      default = ".tack";
      description = "Directory holding tack pins/lock/resolver, relative to intoPath.";
    };

    pinsFile = lib.mkOption {
      type = lib.types.str;
      default = "pins.toml";
      description = "tack pins file name (the generated source of truth).";
    };

    lockFile = lib.mkOption {
      type = lib.types.str;
      default = "pins.lock.json";
      description = "tack lock file name (written by tack update, read by nix).";
    };

    recomposable = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = true;
      description = "Emit `[tack] recomposable`. null omits the table.";
    };

    shorturls = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "tack `[shorturls]` scheme expansions, e.g. { gh = \"github:{path}\"; }.";
    };

    allFollow = lib.mkOption {
      type = lib.types.attrsOf (lib.types.either lib.types.str (lib.types.listOf lib.types.str));
      default = { };
      description = "tack `[all_follow]` rules: name -> target, or target -> [aliases].";
    };

    overrides = lib.mkOption {
      type = lib.types.raw;
      default = { };
      description = "tack resolver overrides passed as `tackOverrides`.";
    };

    sources = lib.mkOption {
      type = lib.types.raw;
      readOnly = true;
      description = "Inputs resolved from the tack lockfile via the resolver, ready as flake inputs.";
      default = sources;
    };
  };
}
