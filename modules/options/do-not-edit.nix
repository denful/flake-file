{ lib, ... }:
{
  options.flake-file.do-not-edit = lib.mkOption {
    default = ''
      # DO-NOT-EDIT. This file was auto-generated using github:denful/flake-file.
      # Use `nix run .#write-flake` to regenerate it.
    '';
    description = "header comment";
    type = lib.types.str;
    apply =
      value:
      lib.optionalString (value != "") (
        lib.pipe value [
          (s: if lib.hasPrefix "#" s then s else "# " + s)
          (s: if lib.hasSuffix "\n" s then s else s + "\n")
        ]
      );
    example = lib.literalExample ''
      "DO-NOT-EDIT"
    '';
  };
}
