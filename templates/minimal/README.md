his flake is the result of doing this bootstrap step (taken form the guide):

```shell
mv flake.nix flake-file.nix
nix-shell https://github.com/denful/flake-file/archive/main.tar.gz -A flake-file.sh --run bootstrap
```
