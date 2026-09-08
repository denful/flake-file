{ lib, ... }:
{
  flake-file.inputs = {
    import-tree.url = lib.mkDefault "github:denful/import-tree";
    flake-file.url = lib.mkDefault "github:denful/flake-file";
    flake-parts.url = lib.mkDefault "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = lib.mkDefault "nixpkgs";
    nixpkgs.url = lib.mkDefault "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";
  };
}
