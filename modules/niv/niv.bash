# niv backend for ../pins/queue.bash.
pin_init() { [ -e nix/sources.json ] || niv init --no-nixpkgs; }
pin_names() { [ -f nix/sources.json ] && jq -r 'keys[]' nix/sources.json || true; }
pin_exists() { jq -e --arg n "$1" 'has($n)' nix/sources.json >/dev/null 2>&1; }
pin_remove() { niv drop "$1"; }
pin_github() { niv add "$2/$3" --name "$1" ${4:+--branch "$4"}; }
pin_gitlab() { niv add git --name "$1" --repo "https://gitlab.com/$2/$3.git" ${4:+--branch "$4"}; }
pin_git() { niv add git --name "$1" --repo "$2" ${3:+--branch "$3"}; }
pin_channel() { niv add "$1" --template "https://channels.nixos.org/$2/nixexprs.tar.xz" --type tarball; }
pin_tarball() { niv add "$1" --template "$2" --type tarball; }
