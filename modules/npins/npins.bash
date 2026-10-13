# npins backend for ../pins/queue.bash.
pin_urls_file=npins/flake-file-urls.tsv
pin_follows_file=npins/follows.nix
pin_init() { npins init --bare 2>/dev/null || true; }
pin_names() { [ -f npins/sources.json ] && jq -r '.pins | keys[]' npins/sources.json || true; }
pin_exists() { jq -e --arg n "$1" '.pins | has($n)' npins/sources.json >/dev/null 2>&1; }
pin_remove() { npins remove "$1"; }
pin_github() { npins add github --name "$1" ${4:+--at "$4"} ${5:+-b "$5"} "$2" "$3"; }
pin_gitlab() { npins add gitlab --name "$1" --server "https://$2" ${5:+--at "$5"} ${6:+-b "$6"} "$3" "$4"; }
pin_git() { npins add git --name "$1" ${3:+--at "$3"} ${4:+-b "$4"} "$2"; }
pin_channel() { npins add channel --name "$1" "$2"; }
pin_tarball() { npins add tarball --name "$1" "$2"; }
