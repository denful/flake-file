{ lib, ... }:
{
  options.flake-file.auto-follow.enable = lib.mkEnableOption "automatic flake input follows maintained with `flake-edit follow`";
}
