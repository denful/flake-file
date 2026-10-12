{ config, ... }:
{
  imports = [ ../pins ];
  config.flake-file.apps.write-npins = config.flake-file.pinWriter {
    name = "write-npins";
    description = "Generate/update npins/ directory via npins.";
    backend = ./npins.bash;
    runtimeInputs = pkgs: [ pkgs.npins ];
  };
}
