lib:
let

  isNonEmptyString = s: lib.isStringLike s && lib.stringLength (lib.trim s) > 0;

  isEmpty =
    x:
    (
      (isNull x)
      || (lib.isStringLike x && lib.stringLength (lib.trim x) == 0)
      || (lib.isList x && lib.length x == 0)
      || (lib.isAttrs x && x == { })
    );

  mergeNonEmpty =
    from: name:
    {
      testEmpty ? isEmpty,
      onEmptyMerge ? { },
      nonEmptyMerge ? {
        ${name} = from.${name};
      },
    }:
    acc: acc // (if (!from ? ${name}) || testEmpty from.${name} then onEmptyMerge else nonEmptyMerge);

  mergeNonEmptyAttrs =
    from: attrs:
    let
      m = mergeNonEmpty from;
      ops = lib.mapAttrsToList (name: spec: (m name spec)) attrs;
    in
    lib.pipe { } ops;

  nonEmptyInputs =
    input:
    let
      inputs = inputsFollow input.inputs;
    in
    {
      nonEmptyMerge = lib.optionalAttrs (inputs != { }) { inherit inputs; };
    };

  inputsFollow =
    inputs:
    lib.filterAttrs (_: input: input != { }) (
      lib.mapAttrs (
        _: input:
        mergeNonEmptyAttrs input {
          follows = {
            testEmpty = v: !builtins.isString v;
          };
          inputs = nonEmptyInputs input;
        }
      ) inputs
    );

  inputsExpr = lib.mapAttrs (
    _name: input:
    mergeNonEmptyAttrs input {
      url = { };
      type = { };
      submodules = { };
      lfs = { };
      owner = { };
      repo = { };
      path = { };
      id = { };
      dir = { };
      narHash = { };
      rev = { };
      ref = { };
      host = { };
      shallow = { };
      flake = {
        testEmpty = v: v;
        nonEmptyMerge = {
          flake = false;
        };
      };
      follows = {
        testEmpty = x: !builtins.isString x;
      };
      inputs = nonEmptyInputs input;
    }
  );

  mergeAutoFollows =
    configured: expr: existing:
    lib.mapAttrs (
      name: input:
      let
        existingInput = existing.${name} or { };
        nested = mergeNestedAutoFollows (configured.${name}.inputs or { }) (input.inputs or { }) (
          existingInput.inputs or { }
        );
      in
      (removeAttrs input [ "inputs" ]) // lib.optionalAttrs (nested != { }) { inputs = nested; }
    ) expr;

  mergeNestedAutoFollows =
    configured: expr: existing:
    let
      names = lib.unique ((builtins.attrNames expr) ++ (builtins.attrNames existing));
    in
    lib.listToAttrs (
      lib.filter (entry: entry.value != { }) (
        map (
          name:
          let
            configuredInput = configured.${name} or { };
            exprInput = expr.${name} or { };
            existingInput = existing.${name} or { };
            automaticallyManaged = configuredInput.autoFollow or true;
            nested = mergeNestedAutoFollows (configuredInput.inputs or { }) (exprInput.inputs or { }) (
              existingInput.inputs or { }
            );
            preservedFollow = lib.optionalAttrs (
              automaticallyManaged && builtins.isString (existingInput.follows or null)
            ) { follows = existingInput.follows; };
          in
          {
            inherit name;
            value =
              (removeAttrs exprInput ([ "inputs" ] ++ lib.optional automaticallyManaged "follows"))
              // preservedFollow
              // lib.optionalAttrs (nested != { }) { inputs = nested; };
          }
        ) names
      )
    );

  autoFollowIgnores =
    configured:
    lib.concatLists (
      lib.mapAttrsToList (
        parent: input: collectAutoFollowIgnores [ parent ] (input.inputs or { })
      ) configured
    );

  collectAutoFollowIgnores =
    path: inputs:
    lib.concatLists (
      lib.mapAttrsToList (
        name: input:
        let
          inputPath = path ++ [ name ];
          disabled = !(input.autoFollow or true);
          configuredFollow = input.follows or null;
        in
        if disabled && builtins.isString configuredFollow then
          throw "auto-follow cannot be disabled for ${lib.concatStringsSep "." inputPath} while follows is configured"
        else
          lib.optional disabled (lib.concatStringsSep "." inputPath)
          ++ collectAutoFollowIgnores inputPath (input.inputs or { })
      ) inputs
    );

  nixAttr =
    collapse: name: value:
    let
      childIsAttr = builtins.isAttrs value;
      childIsOne = builtins.length (builtins.attrNames value) == 1;
      nested = lib.head (lib.mapAttrsToList (nixAttr collapse) value);
    in
    if collapse && childIsAttr && childIsOne then
      {
        name = "${name}.${nested.name}";
        value = nested.value;
      }
    else
      {
        inherit name;
        value = value;
      };

  priorityComparator =
    priority: a: b:
    let
      findPriority = name: lib.lists.findFirstIndex (p: p == name) (lib.length priority) priority;
      priorityA = findPriority a;
      priorityB = findPriority b;
    in
    if priorityA == priorityB then a < b else priorityA < priorityB;

  priorityMapAttrsToList =
    f: priority: attrs:
    lib.pipe attrs [
      lib.attrsToList
      (lib.sort (a: b: priorityComparator priority a.name b.name))
      (map ({ name, value }: f name value))
    ];

  styleHead =
    styles:
    if styles == [ ] then
      {
        attrSortPriority = [ ];
        attrSep = " ";
        collapseAttrs = true;
      }
    else
      lib.pipe styles [
        lib.head
        (
          {
            attrSortPriority ? [ ],
            attrSep ? " ",
            collapseAttrs ? true,
          }:
          {
            inherit attrSortPriority attrSep collapseAttrs;
          }
        )
      ];

  styleTail = styles: if styles == [ ] then [ ] else lib.tail styles;

  # expr to code
  nixCode =
    {
      expr,
      styles ? [ ],
    }:
    let
      style = styleHead styles;
    in
    if lib.isStringLike expr then
      lib.strings.escapeNixString expr
    else if lib.isAttrs expr then
      lib.pipe expr [
        (priorityMapAttrsToList (nixAttr style.collapseAttrs) style.attrSortPriority)
        (map (
          { name, value }:
          "${name} = ${
            nixCode {
              expr = value;
              styles = styleTail styles;
            }
          };"
        ))
        (values: "{ ${lib.concatStringsSep style.attrSep values} }")
      ]
    else if lib.isList expr then
      lib.pipe expr [
        (lib.map (
          expr:
          nixCode {
            inherit expr;
            styles = styleTail styles;
          }
        ))
        (values: "[ ${lib.concatStringsSep " " values} ]")
      ]
    else if expr == true then
      "true"
    else if expr == false then
      "false"
    else
      toString expr;

in
{
  inherit
    autoFollowIgnores
    inputsExpr
    isNonEmptyString
    mergeAutoFollows
    priorityComparator
    priorityMapAttrsToList
    nixCode
    ;
}
