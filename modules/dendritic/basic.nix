{ inputs, lib, ... }:
{

  imports = [
    inputs.flake-file.flakeModules.default
    inputs.flake-file.flakeModules.import-tree
  ];

  flake-file.inputs = {
    flake-file.url = lib.mkDefault "github:denful/flake-file";
  };
}
