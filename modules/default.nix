let
  flakeModules = {
    inherit
      flake # for non-flake-parts flakes
      default # for flake-parts flakes (keep as default for compatibility)
      allfollow
      nix-auto-follow
      dendritic
      import-tree
      npins
      flakeless-parts
      unflake
      tack
      flake-options
      ;
  };

  # A flake without flake-parts. (traditional flake)
  flake.imports = [
    base
    flake-options
    ./write-flake.nix
  ];

  flake-options = ./flake-options.nix;

  base.imports = [
    ./options
    ./write-inputs.nix
    ./write-lock.nix
  ];

  npins.imports = [
    base
    ./npins
  ];

  flakeless-parts.imports = [
    base
    ./npins
    ./flakeless-parts.nix
  ];

  unflake.imports = [
    base
    ./unflake
  ];

  tack.imports = [
    base
    ./tack
  ];

  default.imports = [
    base
    ./write-flake.nix
    ./flake-parts.nix
  ];

  allfollow.imports = [ ./prune-lock/allfollow.nix ];

  nix-auto-follow.imports = [ ./prune-lock/nix-auto-follow.nix ];

  import-tree.imports = [ ./import-tree.nix ];

  dendritic.imports = [ ./dendritic ];

  lib.flakeModules.flake-parts-builder =
    path:
    { flake-parts-lib, ... }:
    {
      imports = [
        (flake-parts-lib.importApply ./flake-parts-builder path)
      ];
    };

  templates.minimal = {
    description = "minimal template";
    path = ./../templates/minimal;
  };

  templates.default = {
    description = "default template";
    path = ./../templates/default;
  };

  templates.npins = {
    description = "npins template";
    path = ./../templates/npins;
  };

  templates.flakeless-parts = {
    description = "flakeless-parts template";
    path = ./../templates/flakeless-parts;
  };

  templates.unflake = {
    description = "unflake template";
    path = ./../templates/unflake;
  };

  templates.tack = {
    description = "tack template";
    path = ./../templates/tack;
  };

  templates.dendritic = {
    description = "dendritic template";
    path = ./../templates/dendritic;
  };

  templates.parts = {
    description = "flake-parts-builder template";
    path = ./../templates/parts;
  };
in
{
  inherit flakeModules templates lib;
}
