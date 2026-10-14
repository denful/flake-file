{ lib, config, ... }:
let
  inherit (config) flake-file;
in
{
  imports = [ ../pins ];
  config.flake-file.apps.write-lon = flake-file.pinWriter {
    name = "write-lon";
    description = "Generate/update lon.nix and lon.lock via lon.";
    backend = ./lon.bash;
    runtimeInputs = pkgs: [ pkgs.lon ];
    lockDir = flake-file.lon.lockDir;
  };

  options.flake-file.lon.lockDir = lib.mkOption {
    type = lib.types.str;
    default = ".";
    description = "Directory holding lon.nix and lon.lock, relative to intoPath.";
  };
}
