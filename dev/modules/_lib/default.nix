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

  nonEmptyInputs = input: {
    nonEmptyMerge = {
      inputs = inputsFollow input.inputs;
    };
  };

  inputsFollow = lib.mapAttrs (
    _: input:
    mergeNonEmptyAttrs input {
      follows = {
        testEmpty = v: !builtins.isString v;
      };
      inputs = nonEmptyInputs input;
    }
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

  nixAttr =
    name: value:
    let
      childIsAttr = builtins.isAttrs value;
      childIsOne = builtins.length (builtins.attrNames value) == 1;
      nested = lib.head (lib.mapAttrsToList nixAttr value);
    in
    if childIsAttr && childIsOne then
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
      }
    else
      lib.pipe styles [
        lib.head
        (
          {
            attrSortPriority ? [ ],
            attrSep ? " ",
          }:
          {
            inherit attrSortPriority attrSep;
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
        (priorityMapAttrsToList nixAttr style.attrSortPriority)
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
    inputsExpr
    isNonEmptyString
    priorityComparator
    priorityMapAttrsToList
    nixCode
    ;
}
