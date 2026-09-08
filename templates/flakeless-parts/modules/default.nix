{ inputs, ... }:
{
  imports = [ inputs.flake-file.flakeModules.flakeless-parts ];

  flake-file.inputs = {
    flake-file.url = "github:denful/flake-file";
    import-tree.url = "github:denful/import-tree";
    with-inputs.url = "github:denful/with-inputs";
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };
}
