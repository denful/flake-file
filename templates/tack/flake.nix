{
  outputs =
    { self, ... }@args:
    (import ./.) {
      tackOverrides = args.tackOverrides or { };
      flakeSelf = self;
    };
}
