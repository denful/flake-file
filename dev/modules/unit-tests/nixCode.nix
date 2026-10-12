{ lib, ... }:

let
  inherit (import ./../_lib lib) inputsExpr nixCode;

  render =
    inputs:
    nixCode {
      expr = inputsExpr inputs;
      styles = [
        { }
        { }
        { }
      ];
    };

  tests.nixCode."test bare identifier stays unquoted" = {
    expr = render { nixpkgs_2505.url = "x"; };
    expected = ''{ nixpkgs_2505.url = "x"; }'';
  };

  tests.nixCode."test dotted input name is quoted" = {
    expr = render { "nixpkgs-25.05".url = "x"; };
    expected = ''{ "nixpkgs-25.05".url = "x"; }'';
  };

  tests.nixCode."test dashed input name stays unquoted" = {
    expr = render { "nixpkgs-unstable".url = "x"; };
    expected = ''{ nixpkgs-unstable.url = "x"; }'';
  };

  tests.nixCode."test numeric-leading input name is quoted" = {
    expr = render { "1password".url = "x"; };
    expected = ''{ "1password".url = "x"; }'';
  };

  tests.nixCode."test keyword input name is quoted" = {
    expr = render { "if".url = "x"; };
    expected = ''{ "if".url = "x"; }'';
  };

  tests.nixCode."test collapsed path keeps dotted segment whole" = {
    expr = render { a.inputs."b.c".follows = "d"; };
    expected = ''{ a.inputs."b.c".follows = "d"; }'';
  };

  tests.nixCode."test null renders as null" = {
    expr = nixCode { expr.foo = null; };
    expected = "{ foo = null; }";
  };
in
{
  flake = { inherit tests; };
}
