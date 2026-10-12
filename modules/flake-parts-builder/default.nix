flake-parts-path:
{ lib, ... }:
let
  imports = lib.flatten (parts ++ meta);

  parts = bootstrap.loadParts flake-parts-path;
  bootstrap = import ./_bootstrap.nix { inherit lib; };

  meta = lib.pipe "${flake-parts-path}/_meta" [
    bootstrap.loadParts
    (lib.map importMeta)
  ];

  importMeta = f: metaToConfig (import f);

  metaToConfig = meta: {
    flake-file = {
      inputs = if meta ? inputs then meta.inputs else { };
      nixConfig =
        lib.optionalAttrs (meta.extraSubstituters or [ ] != [ ]) {
          extra-substituters = meta.extraSubstituters;
        }
        // lib.optionalAttrs (meta.extraTrustedPublicKeys or [ ] != [ ]) {
          extra-trusted-public-keys = meta.extraTrustedPublicKeys;
        };
    };
  };

in
{
  inherit imports;
}
