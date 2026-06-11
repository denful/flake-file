{ lib, config, ... }:
let
  inherit (config) flake-file;
  apps = flake-file.apps;

  candidates = [
    {
      file = "flake.lock";
      app = "write-flake";
    }
    {
      file = "npins/sources.json";
      app = "write-npins";
    }
    {
      file = "${flake-file.tack.lockDir}/${flake-file.tack.lockFile}";
      app = "write-tack";
    }
    {
      file = "unflake.nix";
      app = "write-unflake";
    }
  ];

  available = builtins.filter (d: apps ? ${d.app}) candidates;

  dispatch = lib.concatMapStringsSep "\n" (
    d: ''[ -e ${lib.escapeShellArg "${flake-file.intoPath}/${d.file}"} ] && exec ${d.app} "$@"''
  ) available;

  write-lock =
    pkgs:
    pkgs.writeShellApplication {
      name = "write-lock";
      meta.description = "Detect existing lock file and delegate to the appropriate writer.";
      runtimeInputs = map (d: apps.${d.app} pkgs) available;
      text = dispatch;
    };
in
{
  config.flake-file.apps = { inherit write-lock; };
}
