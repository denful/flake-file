{ lib, ... }:
{
  flake-file.inputs.import-tree.url = lib.mkDefault "github:denful/import-tree";
}
