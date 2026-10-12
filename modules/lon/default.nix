{ config, ... }:
{
  imports = [ ../pins ];
  config.flake-file.apps.write-lon = config.flake-file.pinWriter {
    name = "write-lon";
    description = "Generate/update lon.nix and lon.lock via lon.";
    backend = ./lon.bash;
    runtimeInputs = pkgs: [ pkgs.lon ];
  };
}
