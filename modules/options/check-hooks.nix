{
  lib,
  ...
}:
let
  description = ''
    Hooks to run on check-flake-file

    Ordered by their index field before being run.
    Run on outside flake root, any changes at pwd
    are temporary.
  '';
  hook = lib.types.submodule {
    options = {
      # we use this as poor-man's DAG.
      index = lib.mkOption {
        description = "Index of this hook to run. For user hooks use >100.";
        type = lib.types.int;
        default = 100;
      };
      program = lib.mkOption {
        description = ''
          Function from pkgs to program (derivation with meta.mainProgram).

          Takes the path to the flake root directory as first argument.
        '';
        type = lib.types.functionTo lib.types.unspecified;
      };
    };
  };

in
{
  options.flake-file.check-hooks = lib.mkOption {
    inherit description;
    default = [ ];
    type = lib.types.listOf hook;
  };

  options.flake-file.check-files = lib.mkOption {
    description = ''
      Files, relative to the flake root, copied into the root seen by
      check-flake-file and its check-hooks.

      Only these files affect the check's derivation hash, so commits
      touching anything else reuse a cached check result.
    '';
    type = lib.types.listOf lib.types.str;
    default = [
      "flake.nix"
      "flake.lock"
    ];
  };

}
