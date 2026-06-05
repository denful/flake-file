let
  mkOutputs =
    {
      tackOverrides ? { },
      flakeSelf ? null,
    }:
    let
      rawInputs = (import ./.tack) { overrides = tackOverrides; };
      inputs = rawInputs // {
        self = self';
      };
      self' = outputs // {
        inherit inputs;
        outPath = if flakeSelf != null then flakeSelf.outPath else ./.;
      };
      outputs = rawInputs.flake-parts.lib.mkFlake { inherit inputs; } (rawInputs.import-tree ./modules);
    in
    outputs;
in
{
  __functor = _: mkOutputs;
}
