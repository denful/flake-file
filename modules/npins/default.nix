{ lib, config, ... }:
let
  inherit (config) flake-file;
  inherit (import ../lib.nix lib) inputsExpr;

  inputs = flake-file.preProcess (inputsExpr flake-file.inputs);

  # Synthesise a canonical URL from attrset-form inputs (no url field).
  gitHostScheme = { github = "github"; gitlab = "gitlab"; sourcehut = "sourcehut"; };

  syntheticUrl = input:
    let
      scheme = gitHostScheme.${input.type or ""} or null;
      ref = if input.ref or "" != "" then "/${input.ref}" else "";
    in
    if scheme != null && input.owner or "" != "" then
      "${scheme}:${input.owner}/${input.repo or ""}${ref}"
    else
      null;

  inputUrl = input:
    if input.url or "" != "" then input.url
    else syntheticUrl input;

  pinnableInputs = lib.filterAttrs (_: input: inputUrl input != null) inputs;

  # Seed the runtime queue with one tab-separated "name\turl" line per declared input.
  queueSeed =
    lib.concatStringsSep "\n"
      (lib.mapAttrsToList (name: input: "${name}\t${inputUrl input}") pinnableInputs);

  # Collect names of inputs that set `follows` (to another input, or "" to drop it) at any
  # nesting level: such an input is never fetched under its own name, so it needs no pin.
  collectFollowing =
    inputMap:
    lib.concatLists (
      lib.mapAttrsToList (
        name: input:
        let
          here = lib.optional (input ? follows) name;
          nested = if input ? inputs then collectFollowing input.inputs else [ ];
        in
        here ++ nested
      ) inputMap
    );

  # Pins share one flat namespace, so a declared top-level input keeps its pin even when a
  # nested input of the same name follows something.
  skipSet = lib.concatStringsSep "\n" (
    lib.subtractLists (lib.attrNames pinnableInputs) (collectFollowing inputs)
  );

  write-npins =
    pkgs:
    pkgs.writeShellApplication {
      name = "write-npins";
      meta.description = "Generate/update npins/ directory via npins.";
      runtimeInputs = [
        pkgs.npins
        pkgs.jq
        pkgs.curl
        pkgs.nix
      ];
      runtimeEnv = {
        out = flake-file.intoPath;
        inherit queueSeed skipSet;
      };
      text = builtins.readFile ./npins.bash;
    };
in
{
  config.flake-file.apps = { inherit write-npins; };
}
