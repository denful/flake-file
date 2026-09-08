{ inputs, ... }:
{
  imports = [ inputs.flake-file.flakeModules.unflake ];

  flake-file.inputs = {
    flake-file.url = "github:denful/flake-file";
    import-tree.url = "github:denful/import-tree";
    with-inputs.url = "github:denful/with-inputs";
    with-inputs.flake = false;
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };
}
