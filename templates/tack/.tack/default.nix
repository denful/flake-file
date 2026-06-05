# SPDX-License-Identifier: EUPL-1.2
# tack-managed resolver. delete this line to take ownership; tack will leave it alone afterwards.

let
  inherit (builtins)
    attrNames
    attrValues
    concatMap
    elemAt
    filter
    foldl'
    fromJSON
    head
    intersectAttrs
    isList
    isString
    listToAttrs
    mapAttrs
    match
    pathExists
    readFile
    tail
    trace
    ;

  call =
    {
      overrides ? { },
    }:
    let
      pins = fromTOML (readFile ./pins.toml);
      lock = fromJSON (readFile ./pins.lock.json);
      all_follow_raw = pins.all_follow or { };

      # flatten `target = [aliases]` rows alongside `alias = "target"` rows
      all_follow = foldl' (
        acc: key:
        let
          val = all_follow_raw.${key};
        in
        if isList val then
          acc
          // {
            ${key} = key;
          }
          // listToAttrs (
            map (a: {
              name = a;
              value = key;
            }) val
          )
        else if isString val then
          acc // { ${key} = val; }
        else
          acc
      ) { } (attrNames all_follow_raw);

      fetchPin = name: fetchTree lock.${name};

      fetchFixed =
        name: entry:
        let
          raw = derivation {
            inherit name;
            inherit (entry) url;
            builder = "builtin:fetchurl";
            system = "builtin";
            outputHash = entry.sha256;
            outputHashAlgo = "sha256";
            outputHashMode = "flat";
          };
          unpacked = derivation {
            inherit name;
            builder = "builtin:unpack-channel";
            system = "builtin";
            src = raw;
            channelName = name;
          };
        in
        if (entry.unpack or "file") == "tarball" then unpacked.outPath + "/" + name else raw.outPath;

      resolveSpec = upLock: spec: if isList spec then walkPath upLock upLock.root spec else spec;

      walkPath =
        upLock: nodeName: path:
        if path == [ ] then
          nodeName
        else
          walkPath upLock (resolveSpec upLock upLock.nodes.${nodeName}.inputs.${head path}) (tail path);

      followsFor =
        pin:
        let
          rules = removeAttrs all_follow (pin.exclude_follow or [ ]);
        in
        {
          level = (pin.follows or { }) // rules;
          deep = rules;
        };

      resolveFollows = mapAttrs (
        _: target: self.${target} or (throw "tack: follows target '${target}' is not a pin")
      );

      # a follows key is `flake:name`, `tack:name`, or a bare `name`.
      # project a follows set onto one side, rekeyed to bare names.
      followsForSide =
        side: follows:
        listToAttrs (
          concatMap (
            key:
            let
              m = match "(flake|tack):(.*)" key;
            in
            if m == null then
              [
                {
                  name = key;
                  value = follows.${key};
                }
              ]
            else if head m == side then
              [
                {
                  name = elemAt m 1;
                  value = follows.${key};
                }
              ]
            else
              [ ]
          ) (attrNames follows)
        );

      mkCallerInputs =
        upLock: nodeName: rawInputs: levelFollows: deepFollows:
        let
          resolved = resolveFollows levelFollows;
        in
        mapAttrs (
          n: _decl:
          resolved.${n} or (
            if upLock != null then
              let
                ref =
                  (upLock.nodes.${nodeName}.inputs or { }).${n}
                    or (throw "tack: input '${n}' declared but not in flake.lock node '${nodeName}'");
                childName = resolveSpec upLock ref;
                childNode = upLock.nodes.${childName};
                childSrc = fetchTree childNode.locked;
              in
              if childNode.flake or true then evalTransitive upLock childName childSrc deepFollows else childSrc
            else
              throw "tack: no flake.lock; cannot resolve input '${n}'"
          )
        ) rawInputs;

      mkFlakeResult =
        sourceInfo: flakeDir: callerInputs: outputs:
        outputs
        // sourceInfo
        // {
          outPath = flakeDir;
          inputs = callerInputs;
          inherit outputs sourceInfo;
          _type = "flake";
        };

      evalFlake =
        sourceInfo: flakeDir: upLock: nodeName: levelFollows: deepFollows:
        let
          raw = import (flakeDir + "/flake.nix");

          tackPinsPath = flakeDir + "/.tack/pins.toml";
          hasTack = pathExists tackPinsPath;
          upPins = if hasTack then fromTOML (readFile tackPinsPath) else { };

          # project follows onto each side, then keep only the names that side has.
          # note that a bare follow reaches both, a `flake:`/`tack:` follow just the one.
          tackOverrides = resolveFollows (
            intersectAttrs (upPins.inputs or { }) (followsForSide "tack" levelFollows)
          );
          flakeLevel = intersectAttrs (raw.inputs or { }) (followsForSide "flake" levelFollows);

          # deep follows pass down raw, so each descendant re-projects per side
          callerInputs = mkCallerInputs upLock nodeName (raw.inputs or { }) flakeLevel deepFollows;

          # upstream's own claim that its outputs forward tackOverrides. a closed
          # `{ self }:` upstream would throw on the extra kwarg, so forward only here.
          supportsOverrides = (upPins.tack or { }).recomposable or false;

          extraArgs = if supportsOverrides && tackOverrides != { } then { inherit tackOverrides; } else { };

          outputs = raw.outputs (callerInputs // extraArgs // { self = result; });

          result =
            let
              base = mkFlakeResult sourceInfo flakeDir callerInputs outputs;
            in
            if hasTack && tackOverrides != { } && !supportsOverrides then
              trace "tack: ${flakeDir}: not marked recomposable (set [tack] recomposable = true); overrides will not reach upstream" base
            else
              base;
        in
        result;

      evalTransitive =
        upLock: nodeName: sourceInfo: follows:
        evalFlake sourceInfo sourceInfo.outPath upLock nodeName follows follows;

      evalTopFlake =
        sourceInfo: pin:
        let
          flakeDir = sourceInfo.outPath + (if pin ? dir then "/" + pin.dir else "");
          upLockPath = flakeDir + "/flake.lock";
          upLock = if pathExists upLockPath then fromJSON (readFile upLockPath) else null;
          rootNode = if upLock != null then upLock.root else null;
          f = followsFor pin;
        in
        evalFlake sourceInfo flakeDir upLock rootNode f.level f.deep;

      evalFetch =
        sourceInfo: pin: subdir:
        let
          path = sourceInfo.outPath + subdir;
          tackPinsPath = path + "/.tack/pins.toml";
          hasTack = pathExists tackPinsPath;
          upPins = if hasTack then fromTOML (readFile tackPinsPath) else { };
          f = followsFor pin;
          # a fetch drill-in is tack-only
          tackOverrides = resolveFollows (
            intersectAttrs (upPins.inputs or { }) (followsForSide "tack" f.level)
          );
        in
        # a fetch pin is a source tree (a path). only when there are overrides to
        # push into the upstream's own .tack do we hand back its resolved inputs
        if hasTack && tackOverrides != { } then
          let
            upstream = import (path + "/.tack");
          in
          # old resolvers return a plain attrset, not a callable functor
          if upstream ? __functor then
            (upstream { overrides = tackOverrides; }) // { outPath = path; }
          else
            trace "tack: ${path}: upstream .tack predates override support; overrides will not reach it" path
        else
          path;

      loadPin =
        name: pin:
        let
          pinType = pin.type or (if pin.flake or true then "flake" else "fetch");
          subdir = if pin ? dir then "/" + pin.dir else "";
        in
        if pinType == "fixed" then
          fetchFixed name lock.${name}
        else
          let
            sourceInfo = fetchPin name;
          in
          if pinType == "flake" then evalTopFlake sourceInfo pin else evalFetch sourceInfo pin subdir;

      declared = pins.inputs or { };

      # undeclared lock entries are auto-dedup synthetics only when they are
      # referenced as [all_follow] targets. stale locks left after hand-editing
      # pins.toml are ignored, and can be cleaned with `tack rm <name>`.
      autoTargets = listToAttrs (
        map (target: {
          name = target;
          value = true;
        }) (attrValues all_follow)
      );
      autoNames = filter (n: !(declared ? ${n}) && autoTargets ? ${n}) (attrNames lock);
      autoPin =
        name:
        let
          sourceInfo = fetchPin name;
        in
        if pathExists (sourceInfo.outPath + "/flake.nix") then evalTopFlake sourceInfo { } else sourceInfo;

      self =
        (mapAttrs loadPin declared)
        // listToAttrs (
          map (name: {
            inherit name;
            value = autoPin name;
          }) autoNames
        )
        // overrides;
    in
    self // { __functor = _: call; };
in
call { }
