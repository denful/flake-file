{ inputs, config, ... }:
{
  imports = [ inputs.flake-file.flakeModules.tack ];

  flake-file.inputs = {
    flake-file.url = "github:vic/flake-file";
    import-tree.url = "github:vic/import-tree";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    tack.url = "github:manic-systems/tack";
  };

  flake-file.tack.package = pkgs: inputs.tack.packages.${pkgs.stdenv.hostPlatform.system}.default;

  systems = [
    "x86_64-linux"
    "aarch64-linux"
    "aarch64-darwin"
  ];

  perSystem =
    { pkgs, ... }:
    {
      packages.write-tack = config.flake-file.apps.write-tack pkgs;
      packages.write-lock = config.flake-file.apps.write-lock pkgs;
      devShells.default = pkgs.mkShellNoCC {
        packages = [ (config.flake-file.apps.write-lock pkgs) ];
      };
    };
}
