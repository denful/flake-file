{ lib, ... }:
let
  inherit (import ./../_lib lib)
    autoFollowIgnores
    inputsExpr
    mergeAutoFollows
    ;

  tests.inputsExpr."test on empty inputs" = {
    expr = inputsExpr { };
    expected = { };
  };

  tests.inputsExpr."test on input without follows" = {
    expr = inputsExpr {
      foo.url = "foo";
    };
    expected = {
      foo.url = "foo";
    };
  };

  tests.inputsExpr."test on input without flake=true" = {
    expr = inputsExpr {
      foo.url = "foo";
      foo.flake = true;
    };
    expected = {
      foo.url = "foo";
    };
  };

  tests.inputsExpr."test on input without flake=false" = {
    expr = inputsExpr {
      foo.url = "foo";
      foo.flake = false;
    };
    expected = {
      foo.url = "foo";
      foo.flake = false;
    };
  };

  tests.inputsExpr."test on input with follows" = {
    expr = inputsExpr {
      foo.url = "foo";
      foo.inputs.bar.follows = "baz";
    };
    expected = {
      foo.url = "foo";
      foo.inputs.bar.follows = "baz";
    };
  };

  tests.inputsExpr."test on input with self follows" = {
    expr = inputsExpr {
      foo.follows = "bar";
    };
    expected = {
      foo.follows = "bar";
    };
  };

  tests.inputsExpr."test on input with follows to empty" = {
    expr = inputsExpr {
      foo.url = "foo";
      foo.inputs.bar.follows = "";
    };
    expected = {
      foo.url = "foo";
      foo.inputs.bar.follows = "";
    };
  };

  tests.inputsExpr."test top-input follows empty" = {
    expr = inputsExpr {
      foo.url = "foo";
      bar.follows = "";
    };
    expected = {
      foo.url = "foo";
      bar.follows = "";
    };
  };

  tests.inputsExpr."test autoFollow metadata is not rendered" = {
    expr = inputsExpr {
      foo = {
        url = "foo";
        inputs.bar.autoFollow = false;
      };
    };
    expected.foo.url = "foo";
  };

  tests.inputsExpr."test preserves existing automatic follows" = {
    expr = mergeAutoFollows {
      foo = {
        inputs = { };
      };
    } { foo.url = "foo"; } { foo.inputs.bar.follows = "baz"; };
    expected = {
      foo = {
        url = "foo";
        inputs.bar.follows = "baz";
      };
    };
  };

  tests.inputsExpr."test preserves follows for inputs introduced by preProcess" = {
    expr = mergeAutoFollows { } { injected.url = "injected"; } {
      injected.inputs.nixpkgs.follows = "nixpkgs";
    };
    expected = {
      injected = {
        url = "injected";
        inputs.nixpkgs.follows = "nixpkgs";
      };
    };
  };

  tests.inputsExpr."test automatic follows override configured follows" = {
    expr =
      mergeAutoFollows
        {
          foo.inputs.bar = {
            autoFollow = true;
            follows = "quux";
            inputs = { };
          };
        }
        {
          foo = {
            url = "foo";
            inputs.bar.follows = "quux";
          };
        }
        { foo.inputs.bar.follows = "baz"; };
    expected = {
      foo = {
        url = "foo";
        inputs.bar.follows = "baz";
      };
    };
  };

  tests.inputsExpr."test opting out removes an automatic follow" = {
    expr = mergeAutoFollows {
      foo.inputs.bar = {
        autoFollow = false;
        follows = null;
        inputs = { };
      };
    } { foo.url = "foo"; } { foo.inputs.bar.follows = "baz"; };
    expected.foo.url = "foo";
  };

  tests.inputsExpr."test collects nested auto-follow exclusions" = {
    expr = autoFollowIgnores {
      foo.inputs = {
        bar = {
          autoFollow = false;
          inputs = { };
        };
        baz = {
          autoFollow = true;
          inputs.quux = {
            autoFollow = false;
            inputs = { };
          };
        };
      };
    };
    expected = [
      "foo.bar"
      "foo.baz.quux"
    ];
  };

  tests.inputsExpr."test rejects follows on an auto-follow exclusion" = {
    expr =
      (builtins.tryEval (
        builtins.deepSeq (autoFollowIgnores {
          foo.inputs.bar = {
            autoFollow = false;
            follows = "target";
            inputs = { };
          };
        }) null
      )).success;
    expected = false;
  };

in
{
  flake = { inherit tests; };
}
