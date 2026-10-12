# lon backend for ../pins/queue.bash.
pin_init() { [ -e lon.nix ] || lon init; }
pin_names() { [ -f lon.lock ] && jq -r '.sources | keys[]' lon.lock || true; }
pin_exists() { jq -e --arg n "$1" '.sources | has($n)' lon.lock >/dev/null 2>&1; }
pin_remove() { lon remove "$1"; }
pin_github() { lon add github --name "$1" "$2/$3" ${4:+"$4"}; }
pin_gitlab() { lon add git "$1" "https://gitlab.com/$2/$3.git" ${4:+"$4"}; }
pin_git() { lon add git "$1" "$2" ${3:+"$3"}; }
pin_channel() { lon add tarball "$1" "https://channels.nixos.org/$2/nixexprs.tar.xz"; }
pin_tarball() { lon add tarball "$1" "$2"; }
