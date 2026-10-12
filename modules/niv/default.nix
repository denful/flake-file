{ config, ... }:
{
  imports = [ ../pins ];
  config.flake-file.apps.write-niv = config.flake-file.pinWriter {
    name = "write-niv";
    description = "Generate/update nix/sources.json and nix/sources.nix via niv.";
    backend = ./niv.bash;
    runtimeInputs = pkgs: [ pkgs.niv ];
  };
}
