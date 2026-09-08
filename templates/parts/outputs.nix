inputs:
inputs.flake-parts.lib.mkFlake { inherit inputs; } {
  flake-file.inputs = {
    flake-file.url = "github:denful/flake-file";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";
  };

  imports = [
    inputs.flake-file.flakeModules.default
    (inputs.flake-file.lib.flakeModules.flake-parts-builder ./flake-parts)
  ];
}
