{ lib, ... }:
{
  options.flake-file.formatter = lib.mkOption {
    description = ''
      Formatter for flake.nix file.

      It is a function from pkgs to a program (package with meta.mainProgram).

      The command takes flake.nix as first argument.
    '';
    type = lib.types.functionTo lib.types.unspecified;
    default = pkgs: pkgs.nixfmt;
    example = lib.literalExample ''
      pkgs: pkgs.nixfmt-rs
    '';
  };
}
