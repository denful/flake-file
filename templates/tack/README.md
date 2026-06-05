# tack

This template uses `flake-file.inputs` with
[tack](https://github.com/manic-systems/tack): flake-like TOML pins, lazily
fetched and transformed, with no `flake.lock`.

Inputs are declared as options inside `./modules`. The `write-tack` writer
renders them into `.tack/pins.toml`, then runs `tack update` to produce
`.tack/pins.lock.json`. Nix reads the lock through the tack resolver
(`.tack/default.nix`); `pins.toml` only drives `tack update`.

## Update pins

Regenerate `.tack/pins.toml` from your declared inputs and relock:

```shell
nix run .#write-lock
```

`write-lock` detects the existing `.tack/pins.lock.json` and delegates to
`write-tack`. You can also call `write-tack` directly, passing through any
`tack update` arguments (e.g. `write-tack <input>` to update one input).

## Recomposability

`[tack] recomposable = true` lets another tack flake pass `tackOverrides` into
this one. The flake entrypoint threads the real `self.outPath` so module paths
resolve against the locked flake source.
