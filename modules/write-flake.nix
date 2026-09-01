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
      hooks = lib.pipe config.flake-file.check-hooks [
        (lib.sortOn (i: i.index))
        (map (i: pkgs.lib.getExe (i.program pkgs)))
        (map (p: "${p} ${top.inputs.self}"))
        (lib.concatStringsSep "\n")
      ];
    in
    pkgs.runCommandLocal "check-flake-file"
      {
        nativeBuildInputs = [ pkgs.diffutils ];
      }
      ''
        set -e
        diff -u ${top.inputs.self}/flake.nix ${formatted pkgs}
        ${lib.optionalString auto-follow.enable ''
          cp ${top.inputs.self}/flake.nix flake.nix
          cp ${top.inputs.self}/flake.lock flake.lock
          chmod u+w flake.nix flake.lock
          ${autoFollowCommand pkgs}
          diff -u ${top.inputs.self}/flake.nix flake.nix
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
