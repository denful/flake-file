# niv backend for ../pins/queue.bash.
pin_urls_file=nix/flake-file-urls.tsv
pin_follows_file=nix/follows.nix
pin_init() { [ -e nix/sources.json ] || niv init --no-nixpkgs; }
pin_names() { [ -f nix/sources.json ] && jq -r 'keys[]' nix/sources.json || true; }
pin_exists() { jq -e --arg n "$1" 'has($n)' nix/sources.json >/dev/null 2>&1; }
pin_remove() { niv drop "$1"; }
pin_github() { niv add "$2/$3" --name "$1" ${4:+--rev "$4"} ${5:+--branch "$5"}; }
pin_gitlab() { niv add git --name "$1" --repo "https://$2/$3/$4.git" ${5:+--rev "$5"} ${6:+--branch "$6"}; }
pin_git() { niv add git --name "$1" --repo "$2" ${3:+--rev "$3"} ${4:+--branch "$4"}; }
pin_channel() { niv add "$1" --template "https://channels.nixos.org/$2/nixexprs.tar.xz" --type tarball; }
pin_tarball() { niv add "$1" --template "$2" --type tarball; }
