{
  pkgs ? import <nixpkgs> { },
  outdir ? ".",
  ...
}@args:
let

  bootstrap =
    modules:
    import ./.. (
      args
      // {
        inherit modules;
      }
    );

  empty = bootstrap {
    inputs.empty.url = "github:denful/empty-flake";
    outputs = _: { };
  };

  tack-test = bootstrap {
    inputs.empty.url = "github:denful/empty-flake";
    outputs = _: { };
  };

  all-inputs-schemes = bootstrap {
    inputs.simple.url = "github:denful/empty-flake";
    inputs.withBranch.url = "github:denful/empty-flake/main";
    inputs.noflake = {
      url = "github:denful/empty-flake/main";
      flake = false;
    };
    inputs.gitHttps.url = "git+https://github.com/denful/empty-flake";
    inputs.tarball.url = "https://github.com/denful/empty-flake/archive/main.tar.gz";
    inputs.tarballPlus.url = "tarball+https://github.com/denful/empty-flake/archive/main.tar.gz";
    inputs.fileHttps.url = "file+https://github.com/denful/empty-flake/archive/main.tar.gz";
    inputs.attrGh = {
      type = "github";
      owner = "denful";
      repo = "empty-flake";
    };
    inputs.attrGhRef = {
      type = "github";
      owner = "denful";
      repo = "empty-flake";
      ref = "main";
    };
    inputs.followsSimple.follows = "simple";
  };

  flake-parts = bootstrap {
    inputs.flake-parts.url = "github:hercules-ci/flake-parts";
  };

  bootstrap-all = import ./.. (
    args
    // {
      bootstrap = true;
      modules = {
        outputs = _: { };
      };
    }
  );

  bootstrap-selected = import ./.. (
    args
    // {
      bootstrap = [
        "flake-file"
        "nixpkgs"
      ];
      modules = {
        outputs = _: { };
      };
    }
  );

  bootstrap-override = import ./.. (
    args
    // {
      bootstrap = true;
      modules = {
        inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
        outputs = _: { };
      };
    }
  );

  flake-parts-follows = bootstrap {
    inputs.nixpkgs-lib.url = "github:denful/empty-flake";
    inputs.flake-parts.url = "github:hercules-ci/flake-parts";
    inputs.flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs-lib";
  };

  flake-parts-follows-other = bootstrap {
    inputs.nixpkgs.url = "github:denful/empty-flake";
    inputs.flake-parts.url = "github:hercules-ci/flake-parts";
    inputs.flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  };

  flake-parts-skip = bootstrap {
    inputs.flake-parts.url = "github:hercules-ci/flake-parts";
    inputs.flake-parts.inputs.nixpkgs-lib.follows = "";
  };

  test-inputs = pkgs.writeShellApplication {
    name = "test-inputs";
    runtimeInputs = [
      (empty.flake-file.apps.write-inputs pkgs)
    ];
    text = ''
      write-inputs
      cat ${outdir}/inputs.nix
      grep github:denful/empty-flake ${outdir}/inputs.nix
    '';
  };

  test-flake = pkgs.writeShellApplication {
    name = "test-flake";
    runtimeInputs = [
      pkgs.nix
      (empty.flake-file.apps.write-flake pkgs)
    ];
    text = ''
      write-flake
      cat ${outdir}/flake.nix
      grep github:denful/empty-flake ${outdir}/flake.nix
    '';
  };

  test-bootstrap-all-inputs = pkgs.writeShellApplication {
    name = "test-bootstrap-all-inputs";
    runtimeInputs = [
      (bootstrap-all.flake-file.apps.write-inputs pkgs)
    ];
    text = ''
      write-inputs
      grep github:denful/import-tree ${outdir}/inputs.nix
      grep github:denful/flake-file ${outdir}/inputs.nix
      grep github:hercules-ci/flake-parts ${outdir}/inputs.nix
      grep channels.nixos.org/nixpkgs-unstable ${outdir}/inputs.nix
    '';
  };

  test-bootstrap-selected-inputs = pkgs.writeShellApplication {
    name = "test-bootstrap-selected-inputs";
    runtimeInputs = [
      (bootstrap-selected.flake-file.apps.write-inputs pkgs)
    ];
    text = ''
      write-inputs
      grep github:denful/flake-file ${outdir}/inputs.nix
      grep channels.nixos.org/nixpkgs-unstable ${outdir}/inputs.nix
      if grep github:denful/import-tree ${outdir}/inputs.nix; then
        exit 1
      fi
      if grep github:hercules-ci/flake-parts ${outdir}/inputs.nix; then
        exit 1
      fi
    '';
  };

  test-bootstrap-input-override = pkgs.writeShellApplication {
    name = "test-bootstrap-input-override";
    runtimeInputs = [
      (bootstrap-override.flake-file.apps.write-inputs pkgs)
    ];
    text = ''
      write-inputs
      grep github:nixos/nixpkgs/nixos-unstable ${outdir}/inputs.nix
    '';
  };

  test-flake-public = pkgs.writeShellApplication {
    name = "test-flake-public";
    runtimeInputs = [
      pkgs.nix
    ];
    text = ''
      nix-shell -E '
        let
          pkgs = import <nixpkgs> { };
          ff = import ${./..} {
            inherit pkgs;
            outdir = "${outdir}";
            modules = {
              inputs.empty.url = "github:denful/empty-flake";
              outputs = _: { };
            };
          };
        in
        ff.write-flake
      ' --run write-flake
      cat ${outdir}/flake.nix
      grep github:denful/empty-flake ${outdir}/flake.nix
    '';
  };

  test-flake-public-ignores-broken-app = pkgs.writeShellApplication {
    name = "test-flake-public-ignores-broken-app";
    runtimeInputs = [
      pkgs.nix
    ];
    text = ''
      nix-shell -E '
        let
          pkgs = import <nixpkgs> { };
          ff = import ${./..} {
            inherit pkgs;
            outdir = "${outdir}";
            modules = {
              inputs.empty.url = "github:denful/empty-flake";
              outputs = _: { };
              flake-file.apps.write-broken =
                pkgs:
                pkgs.runCommand "write-broken" { } "exit 1";
            };
          };
        in
        ff.write-flake
      ' --run write-flake
      cat ${outdir}/flake.nix
      grep github:denful/empty-flake ${outdir}/flake.nix
    '';
  };

  test-npins = pkgs.writeShellApplication {
    name = "test-npins";
    runtimeInputs = [
      (empty.flake-file.apps.write-npins pkgs)
      pkgs.jq
    ];
    text = ''
      write-npins
      cat ${outdir}/npins/sources.json
      jq -e '.pins | has("empty")' ${outdir}/npins/sources.json
    '';
  };

  test-npins-transitive = pkgs.writeShellApplication {
    name = "test-npins-transitive";
    runtimeInputs = [
      (flake-parts.flake-file.apps.write-npins pkgs)
      pkgs.jq
    ];
    text = ''
      write-npins
      cat ${outdir}/npins/sources.json
      jq -e '.pins."flake-parts".url | contains("hercules-ci/flake-parts")' ${outdir}/npins/sources.json
      jq -e '.pins."nixpkgs-lib".url | contains("nix-community/nixpkgs.lib")' ${outdir}/npins/sources.json
    '';
  };

  test-npins-follows = pkgs.writeShellApplication {
    name = "test-npins-follows";
    runtimeInputs = [
      (flake-parts-follows.flake-file.apps.write-npins pkgs)
      pkgs.jq
    ];
    text = ''
      write-npins
      cat ${outdir}/npins/sources.json
      jq -e '.pins."flake-parts".url | contains("hercules-ci/flake-parts")' ${outdir}/npins/sources.json
      jq -e '.pins."nixpkgs-lib".url | contains("denful/empty")' ${outdir}/npins/sources.json
    '';
  };

  test-npins-follows-other = pkgs.writeShellApplication {
    name = "test-npins-follows-other";
    runtimeInputs = [
      (flake-parts-follows-other.flake-file.apps.write-npins pkgs)
      pkgs.jq
    ];
    text = ''
      write-npins
      cat ${outdir}/npins/sources.json
      jq -e '.pins."flake-parts".url | contains("hercules-ci/flake-parts")' ${outdir}/npins/sources.json
      jq -e '.pins."nixpkgs".url | contains("denful/empty")' ${outdir}/npins/sources.json
      jq -e '.pins | has("nixpkgs-lib") | not' ${outdir}/npins/sources.json
    '';
  };

  test-npins-skip = pkgs.writeShellApplication {
    name = "test-npins-skip";
    runtimeInputs = [
      (flake-parts-skip.flake-file.apps.write-npins pkgs)
      pkgs.jq
    ];
    text = ''
      write-npins
      cat ${outdir}/npins/sources.json
      jq -e '.pins."flake-parts".url | contains("hercules-ci/flake-parts")' ${outdir}/npins/sources.json
      jq -e '.pins | has("nixpkgs-lib") | not' ${outdir}/npins/sources.json
    '';
  };

  test-npins-schemes = pkgs.writeShellApplication {
    name = "test-npins-schemes";
    runtimeInputs = [
      (all-inputs-schemes.flake-file.apps.write-npins pkgs)
      pkgs.jq
    ];
    text = ''
      write-npins
      cat ${outdir}/npins/sources.json
      jq -e '.pins | has("simple")'      ${outdir}/npins/sources.json
      jq -e '.pins | has("withBranch")'  ${outdir}/npins/sources.json
      jq -e '.pins | has("noflake")'     ${outdir}/npins/sources.json
      jq -e '.pins | has("gitHttps")'    ${outdir}/npins/sources.json
      jq -e '.pins | has("tarball")'     ${outdir}/npins/sources.json
      jq -e '.pins | has("tarballPlus")' ${outdir}/npins/sources.json
      jq -e '.pins | has("fileHttps")'   ${outdir}/npins/sources.json
      jq -e '.pins | has("attrGh")'      ${outdir}/npins/sources.json
      jq -e '.pins | has("attrGhRef")'   ${outdir}/npins/sources.json
      jq -e '.pins | has("followsSimple") | not' ${outdir}/npins/sources.json
    '';
  };

  test-unflake = pkgs.writeShellApplication {
    name = "test-unflake";
    runtimeInputs = [
      (empty.flake-file.apps.write-unflake pkgs)
    ];
    text = ''
      write-unflake --backend nix
      grep unflake_github_denful_empty-flake ${outdir}/unflake.nix
    '';
  };

  test-write-lock-flake = pkgs.writeShellApplication {
    name = "test-write-lock-flake";
    runtimeInputs = [
      (empty.flake-file.apps.write-lock pkgs)
    ];
    text = ''
      echo "{ }" > ${outdir}/flake.lock
      write-lock
      [ -e ${outdir}/flake.nix ]
      grep github:denful/empty-flake ${outdir}/flake.nix
    '';
  };

  test-write-lock-npins = pkgs.writeShellApplication {
    name = "test-write-lock-npins";
    runtimeInputs = [
      (empty.flake-file.apps.write-lock pkgs)
      pkgs.jq
      pkgs.npins
    ];
    text = ''
      mkdir -p ${outdir}
      (cd ${outdir} && npins init --bare)
      write-lock
      jq -e '.pins | has("empty")' ${outdir}/npins/sources.json
    '';
  };

  test-tack = pkgs.writeShellApplication {
    name = "test-tack";
    runtimeInputs = [
      (tack-test.flake-file.apps.write-tack pkgs)
      pkgs.jq
    ];
    text = ''
      write-tack
      cat ${outdir}/.tack/pins.toml
      grep github:denful/empty-flake ${outdir}/.tack/pins.toml
      jq -e 'has("empty")' ${outdir}/.tack/pins.lock.json
      [ -e ${outdir}/.tack/default.nix ]
    '';
  };

  test-write-lock-tack = pkgs.writeShellApplication {
    name = "test-write-lock-tack";
    runtimeInputs = [
      (tack-test.flake-file.apps.write-lock pkgs)
      pkgs.jq
    ];
    text = ''
      mkdir -p ${outdir}/.tack
      echo '{ }' > ${outdir}/.tack/pins.lock.json
      write-lock
      jq -e 'has("empty")' ${outdir}/.tack/pins.lock.json
    '';
  };

  test-write-lock-unflake = pkgs.writeShellApplication {
    name = "test-write-lock-unflake";
    runtimeInputs = [
      (empty.flake-file.apps.write-lock pkgs)
    ];
    text = ''
      echo '{ }' > ${outdir}/unflake.nix
      write-lock --backend nix
      grep unflake_github_denful_empty-flake ${outdir}/unflake.nix
    '';
  };

in
pkgs.mkShell {
  buildInputs = [
    test-inputs
    test-flake
    test-bootstrap-all-inputs
    test-bootstrap-selected-inputs
    test-bootstrap-input-override
    test-flake-public
    test-flake-public-ignores-broken-app
    test-unflake
    test-npins
    test-npins-schemes
    test-npins-skip
    test-npins-follows
    test-npins-follows-other
    test-npins-transitive
    test-tack
    test-write-lock-flake
    test-write-lock-npins
    test-write-lock-tack
    test-write-lock-unflake
  ];
}
