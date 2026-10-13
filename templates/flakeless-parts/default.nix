let
  sources = import ./npins;
  # npins/follows.nix is written by write-npins from flake-file.inputs' follows.
  with-inputs = import sources.with-inputs sources (
    import ./npins/follows.nix
    // {
      # uncomment on CI for local checkout
      # flake-file = import ./../../modules;
    }
  );

  outputs =
    inputs@{ flake-parts, import-tree, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (import-tree ./modules);
in
with-inputs outputs
