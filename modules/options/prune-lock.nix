{ lib, config, ... }:
let
  HOOK_INDEX = 1;

  prune-lock-option = lib.mkOption {
    default = { };
    type = lib.types.submodule {
      options = {
        enable = lib.mkEnableOption "Should we automatically prune flake.lock";
        program = lib.mkOption {
          description = ''
            Function from pkgs to an exe derivation used to prune flake.lock.

            The program takes the flake.lock location as first positional argument
            and is expected to produce a pruned version into the second argument.

            The output is expected to be deterministic.
          '';
          example = lib.literalExample (builtins.readFile ./../prune-lock/_nothing.nix);
          type = lib.types.functionTo lib.types.unspecified;
          default = import ./../prune-lock/_nothing.nix;
        };
      };
    };
  };

  prune-lock = config.flake-file.prune-lock;
  prune-cmd = pkgs: pkgs.lib.getExe (prune-lock.program pkgs);
  prune-lock-run =
    pkgs:
    pkgs.writeShellApplication {
      name = "prune-lock";
      runtimeInputs = [ pkgs.diffutils ];
      text = ''
        ${prune-cmd pkgs} flake.lock pruned.lock
        if cmp -s flake.lock pruned.lock; then
          rm pruned.lock
        else
          mv pruned.lock flake.lock
        fi
        nix flake metadata > /dev/null
      '';
    };

  prune-lock-check =
    pkgs:
    pkgs.writeShellApplication {
      name = "prune-lock-check";
      runtimeInputs = [ pkgs.diffutils ];
      text = ''
        ${prune-cmd pkgs} "$1"/flake.lock pruned.lock
        diff -u "$1"/flake.lock pruned.lock
      '';
    };

  write-hooks = lib.optionals prune-lock.enable [
    {
      index = HOOK_INDEX;
      program = prune-lock-run;
    }
  ];

  check-hooks = lib.optionals prune-lock.enable [
    {
      index = HOOK_INDEX;
      program = prune-lock-check;
    }
  ];
in
{
  options.flake-file.prune-lock = prune-lock-option;
  config.flake-file = { inherit write-hooks check-hooks; };
}
