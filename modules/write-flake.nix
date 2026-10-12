{
  lib,
  options,
  config,
  ...
}@top:
let
  inherit (import ./../dev/modules/_lib lib)
    autoFollowIgnores
    inputsExpr
    isNonEmptyString
    mergeAutoFollows
    priorityMapAttrsToList
    nixCode
    ;

  inherit (config.flake-file.style) sep sortPriority;

  flake-file = config.flake-file;
  auto-follow = flake-file.auto-follow;

  existingInputs =
    if auto-follow.enable then (import "${top.inputs.self}/flake.nix").inputs or { } else { };

  renderedInputs =
    let
      expr = flake-file.preProcess (inputsExpr flake-file.inputs);
    in
    if auto-follow.enable then mergeAutoFollows flake-file.inputs expr existingInputs else expr;

  unformatted =
    let
      filteredAttrs = lib.filterAttrs (_: v: v != null) {
        inherit description outputs nixConfig;
        inputs = flakeInputs;
      };
      exprs = priorityMapAttrsToList (_: v: v) sortPriority.flake filteredAttrs;
    in
    addHeader ''
      {
        ${lib.concatStringsSep sep.flake exprs} 
      }
    '';

  description =
    if isNonEmptyString flake-file.description then
      "description = ${nixCode { expr = flake-file.description; }};"
    else
      null;

  outputs = "outputs = ${flake-file.outputs};";

  nixConfig =
    let
      nixConfigOptions =
        options.flake-file.valueMeta.configuration.options.nixConfig.valueMeta.configuration.options;
      filteredConfig = lib.filterAttrs (
        name: _: !(nixConfigOptions ? ${name}) || nixConfigOptions.${name}.isDefined
      ) flake-file.nixConfig;
    in
    if filteredConfig != { } then
      "nixConfig = ${
        nixCode {
          expr = filteredConfig;
          styles = [
            {
              attrSortPriority = sortPriority.nixConfig;
              attrSep = sep.nixConfig;
            }
          ];
        }
      };"
    else
      null;

  flakeInputs = "inputs = ${
    nixCode {
      expr = renderedInputs;
      styles = [
        {
          attrSortPriority = sortPriority.inputs;
          attrSep = sep.inputs;
          collapseAttrs = !auto-follow.enable;
        }
        {
          attrSortPriority = sortPriority.inputSchema;
          attrSep = sep.inputSchema;
        }
        {
          attrSortPriority = sortPriority.inputs;
        }
      ];
    }
  };";

  addHeader =
    code: if isNonEmptyString flake-file.do-not-edit then flake-file.do-not-edit + code else code;

  formatted =
    pkgs:
    pkgs.stdenvNoCC.mkDerivation {
      name = "flake-formatted";
      passAsFile = [ "unformatted" ];
      inherit unformatted;
      preferLocalBuild = true;
      phases = [ "format" ];
      format = ''
        cp $unformattedPath flake.nix
        ${pkgs.lib.getExe (flake-file.formatter pkgs)} flake.nix
        cp flake.nix $out
      '';
    };

  autoFollowConfig =
    pkgs:
    pkgs.writeText "flake-edit.toml" ''
      [follow]
      ignore = ${builtins.toJSON (autoFollowIgnores flake-file.inputs)}
      transitive_min = 0
      aliases = {}
    '';

  autoFollowCommand =
    pkgs:
    let
      minimumVersion = "0.3.5";
      package =
        pkgs.flake-edit or (throw "flake-file auto-follow requires pkgs.flake-edit >= ${minimumVersion}");
      version = package.version or "unknown";
      flake-edit =
        if lib.versionAtLeast version minimumVersion then
          pkgs.lib.getExe package
        else
          throw "flake-file auto-follow requires pkgs.flake-edit >= ${minimumVersion}, but found ${version}";
      configFile = autoFollowConfig pkgs;
    in
    ''
      ${flake-edit} --no-lock --non-interactive --no-cache --config ${configFile} follow
      ${pkgs.lib.getExe (flake-file.formatter pkgs)} flake.nix
    '';

  # Nix and Lix keep an existing lock node when only an input's `flake` attribute changes (#114),
  # so a flipped `flake` needs `nix flake update <name>` before the lock reflects it.
  declaredFlake = lib.mapAttrs (_: input: !(input ? flake && input.flake == false)) (
    lib.filterAttrs (_: input: !(builtins.isString (input.follows or null))) renderedInputs
  );

  staleLockWarning = pkgs: ''
    if [ -e flake.lock ]; then
      stale=$(${pkgs.lib.getExe pkgs.jq} -r --argjson declared ${lib.escapeShellArg (builtins.toJSON declaredFlake)} '
        (.nodes // { }) as $nodes
        | ($nodes[.root // "root"].inputs // { }) as $roots
        | $declared | to_entries[]
        | $roots[.key] as $node
        | select(($node | type) == "string" and ($nodes[$node] | type) == "object")
        | select($nodes[$node] | has("locked"))
        | select(($nodes[$node] | if has("flake") then .flake else true end) != .value)
        | .key' flake.lock 2>/dev/null | tr '\n' ' ' || true)
      if [ -n "$stale" ]; then
        echo "flake-file: flake.lock records a different \`flake\` attribute for: $stale" >&2
        echo "flake-file: nix flake lock keeps the old value; refresh with: nix flake update $stale" >&2
      fi
    fi
  '';

  write-flake =
    pkgs:
    let
      hooks = lib.pipe config.flake-file.write-hooks [
        (lib.sortOn (i: i.index))
        (map (i: pkgs.lib.getExe (i.program pkgs)))
        (lib.concatStringsSep "\n")
      ];
    in
    pkgs.writeShellApplication {
      name = "write-flake";
      meta.description = "Generate a flake.nix file";
      runtimeInputs = [ pkgs.diffutils ] ++ lib.optionals auto-follow.enable [ pkgs.nix ];
      text = ''
        cd ${config.flake-file.intoPath}
        if ! cmp -s ${formatted pkgs} flake.nix; then
          cat ${formatted pkgs} > flake.nix
        fi
        ${staleLockWarning pkgs}
        ${lib.optionalString auto-follow.enable ''
          nix flake lock
          ${autoFollowCommand pkgs}
          nix flake lock --offline
        ''}
        ${hooks}
      '';
    };

  check-flake-file =
    pkgs:
    let
      # Copying all of self would change this check's hash on every commit.
      prefix = "${toString top.inputs.self}/";
      files = config.flake-file.check-files;
      root = builtins.path {
        name = "flake-root";
        path = top.inputs.self;
        filter =
          path: type:
          let
            rel = lib.removePrefix prefix path;
          in
          lib.elem rel files || (type == "directory" && lib.any (lib.hasPrefix "${rel}/") files);
      };
      hooks = lib.pipe config.flake-file.check-hooks [
        (lib.sortOn (i: i.index))
        (map (i: pkgs.lib.getExe (i.program pkgs)))
        (map (p: "${p} ${root}"))
        (lib.concatStringsSep "\n")
      ];
    in
    pkgs.runCommand "check-flake-file"
      {
        nativeBuildInputs = [ pkgs.diffutils ];
        preferLocalBuild = true;
      }
      ''
        set -e
        diff -u ${root}/flake.nix ${formatted pkgs}
        ${lib.optionalString auto-follow.enable ''
          cp ${root}/flake.nix flake.nix
          cp ${root}/flake.lock flake.lock
          chmod u+w flake.nix flake.lock
          ${autoFollowCommand pkgs}
          diff -u ${root}/flake.nix flake.nix
        ''}
        ${hooks}
        touch $out
      '';
in
{
  config.flake-file.apps = { inherit write-flake; };
  options.flake-file.check-flake-file = lib.mkOption {
    default = check-flake-file;
    readOnly = true;
    visible = false;
    internal = true;
  };
}
