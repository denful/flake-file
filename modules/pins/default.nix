# Shared writer for lock tools that pin each input under its own name (npins, lon, niv).
# A backend script defines pin_init, pin_names, pin_exists, pin_remove and one pin_<kind>
# function per source kind; ./queue.bash discovers transitive inputs and prunes the rest.
{ lib, config, ... }:
let
  inherit (config) flake-file;
  inherit (import ../lib.nix lib) inputsExpr;

  inputs = flake-file.preProcess (inputsExpr flake-file.inputs);

  # Synthesise a canonical URL from attrset-form inputs (no url field).
  gitHostScheme = {
    github = "github";
    gitlab = "gitlab";
    sourcehut = "sourcehut";
  };

  # Every other flake-reference attribute travels in the query string, where the writer
  # either pins it or rejects the input.
  urlAttrs = [
    "rev"
    "host"
    "dir"
    "narHash"
    "submodules"
    "lfs"
    "shallow"
  ];

  syntheticUrl =
    input:
    let
      scheme = gitHostScheme.${input.type or ""} or null;
      ref = if input.ref or "" != "" then "/${input.ref}" else "";
      query = lib.concatStringsSep "&" (
        lib.mapAttrsToList (k: v: "${k}=${if lib.isBool v then (if v then "1" else "0") else v}") (
          lib.filterAttrs (k: _: lib.elem k urlAttrs) input
        )
      );
    in
    if scheme != null && input.owner or "" != "" then
      "${scheme}:${input.owner}/${input.repo or ""}${ref}${lib.optionalString (query != "") "?${query}"}"
    else
      null;

  inputUrl = input: if input.url or "" != "" then input.url else syntheticUrl input;

  pinnableInputs = lib.filterAttrs (_: input: inputUrl input != null) inputs;

  # Seed the runtime queue with one tab-separated "name\turl" line per declared input.
  queueSeed = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: input: "${name}\t${inputUrl input}") pinnableInputs
  );

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

  mkPinWriter =
    {
      name,
      description,
      backend,
      runtimeInputs,
    }:
    pkgs:
    pkgs.writeShellApplication {
      inherit name;
      meta.description = description;
      runtimeInputs = runtimeInputs pkgs ++ [
        pkgs.jq
        pkgs.curl
        pkgs.nix
      ];
      runtimeEnv = {
        out = flake-file.intoPath;
        inherit queueSeed skipSet;
        trackPinUrls = if flake-file.trackPinUrls then "1" else "";
      };
      text = builtins.readFile backend + builtins.readFile ./queue.bash;
    };
in
{
  options.flake-file.trackPinUrls = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Record the URL each pin was added from in a sidecar next to the lock
      (`npins/flake-file-urls.tsv`, `lon-flake-file-urls.tsv` or `nix/flake-file-urls.tsv`),
      so a pin is re-added when its declared URL changes. With `false`, no sidecar is
      written and an existing pin is never re-added; delete it to re-pin.
    '';
  };

  options.flake-file.pinWriter = lib.mkOption {
    internal = true;
    readOnly = true;
    default = mkPinWriter;
    description = "Builds a write-<tool> app from a pin backend script.";
  };
}
