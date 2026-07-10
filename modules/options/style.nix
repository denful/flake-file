{ lib, ... }:
let
  mkSepOption =
    name: default:
    lib.mkOption {
      description = ''
        The separator used between the top-level attributes of ${name}.
      '';
      type = lib.types.str;
      inherit default;
    };

  mkSortPriorityOption =
    name: default:
    lib.mkOption {
      description = ''
        When alphabetically sorting the top-level attributes of ${name}, names within
        this list will receive a higher sort order according to its index.
      '';
      type = lib.types.listOf lib.types.str;
      inherit default;
    };
in
{
  options.flake-file.style = {
    sep = {
      flake = mkSepOption "the flake" "\n\n";
      inputs = mkSepOption "inputs" "\n";
      inputSchema = mkSepOption "an input schema" "\n";
      nixConfig = mkSepOption "nixConfig" "\n";
    };

    sortPriority = {
      flake = mkSortPriorityOption "the flake" [
        "description"
        "outputs"
        "nixConfig"
        "inputs"
      ];
      inputs = mkSortPriorityOption "inputs" [ ];
      inputSchema = mkSortPriorityOption "an input schema" [
        "type"
        "host"
        "url"
        "owner"
        "repo"
        "path"
        "id"
        "dir"
        "narHash"
        "rev"
        "ref"
        "shallow"
        "submodules"
        "lfs"
        "flake"
        "follows"
        "inputs"
      ];
      nixConfig = mkSortPriorityOption "nixConfig" [ ];
    };
  };
}
