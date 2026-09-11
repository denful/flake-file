{
  inputs.nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";

  outputs = _inputs: {
    hello = "mundo";
  };

  flake-file.outputs-schema =
    { lib, ... }:
    {
      options.hello = lib.mkOption {
        type = lib.types.enum [
          "mundo"
          "monde"
        ];
      };
    };
}
