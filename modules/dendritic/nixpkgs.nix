{ lib, ... }:
{

  flake-file.inputs = {
    nixpkgs.url = lib.mkDefault "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";
  };

}
